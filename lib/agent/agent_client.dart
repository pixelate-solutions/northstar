import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase_client.dart';
import '../models/agent_event.dart';
import '../models/trip_brief.dart';
import '../models/trip_plan.dart';
import 'agent_event_decoder.dart';

// Server URL — set via --dart-define at build time.
// Points to the Fly.io agent server that holds the OpenAI key.
const _defaultServerUrl = String.fromEnvironment(
  'AGENT_SERVER_URL',
  defaultValue: 'https://northstar-agent.fly.dev',
);

class AgentRunResult {
  const AgentRunResult._({
    this.plan,
    this.followUpQuestion,
    this.runId,
    required this.events,
  });

  final TripPlan? plan;
  final String? followUpQuestion;
  final String? runId;
  final List<AgentEvent> events;

  bool get needsMoreInfo => followUpQuestion != null;
  bool get success => plan != null;

  factory AgentRunResult.plan(
    TripPlan plan,
    List<AgentEvent> events, {
    String? runId,
  }) => AgentRunResult._(plan: plan, runId: runId, events: events);

  factory AgentRunResult.question(
    String question,
    List<AgentEvent> events, {
    String? runId,
  }) => AgentRunResult._(
    followUpQuestion: question,
    runId: runId,
    events: events,
  );
}

class AgentRunCancelledException implements Exception {
  const AgentRunCancelledException();

  @override
  String toString() => 'Agent run cancelled.';
}

class AgentRunController {
  bool _cancelled = false;
  String? _runId;
  Future<void> Function()? _cancelActiveRun;

  bool get isCancelled => _cancelled;
  String? get runId => _runId;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _cancelActiveRun?.call();
  }
}

class AgentClient {
  AgentClient({
    String serverUrl = _defaultServerUrl,
    FutureOr<String?> Function()? accessTokenProvider,
    http.Client? httpClient,
  }) : _serverUrl = serverUrl,
       _accessTokenProvider = accessTokenProvider,
       _httpClient = httpClient ?? http.Client();

  final String _serverUrl;
  final FutureOr<String?> Function()? _accessTokenProvider;
  final http.Client _httpClient;

  // Creates a new trip plan via the Fly.io agent server.
  // Fires [onEvent] for each SSE event received during the run.
  Future<AgentRunResult> createPlan(
    TripBrief brief, {
    AgentEventSink? onEvent,
    AgentRunController? controller,
  }) async {
    return _runAgent(
      path: '/v1/runs',
      body: {'mode': 'create', 'brief': brief.toJson()},
      onEvent: onEvent,
      controller: controller,
    );
  }

  // Edits an existing trip plan.
  Future<AgentRunResult> editPlan(
    TripPlan plan,
    String instruction, {
    AgentEventSink? onEvent,
    AgentRunController? controller,
  }) async {
    return _runAgent(
      path: '/v1/runs',
      body: {'plan': plan.toJson(), 'instruction': instruction, 'mode': 'edit'},
      onEvent: onEvent,
      controller: controller,
    );
  }

  Future<AgentRunResult> continueRun(
    String runId,
    String answer, {
    AgentEventSink? onEvent,
    AgentRunController? controller,
  }) async {
    return _runAgent(
      path: '/v1/runs/$runId/answer',
      body: {'answer': answer},
      onEvent: onEvent,
      controller: controller,
    );
  }

  Future<AgentRunResult> _runAgent({
    required String path,
    required Map<String, dynamic> body,
    AgentEventSink? onEvent,
    AgentRunController? controller,
  }) async {
    final events = <AgentEvent>[];
    final jwt = await _accessToken();
    final useMemory = await _useMemoryPreference();
    if (controller?.isCancelled == true) {
      throw const AgentRunCancelledException();
    }

    // Step 1: POST to start the run, get a runId back
    final startResp = await _httpClient.post(
      Uri.parse('$_serverUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (jwt != null) 'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({...body, 'useMemory': useMemory}),
    );

    if (startResp.statusCode != 200 && startResp.statusCode != 201) {
      throw Exception(
        'Agent server error ${startResp.statusCode}: ${startResp.body}',
      );
    }

    final startJson = jsonDecode(startResp.body) as Map<String, dynamic>;
    final runId = startJson['runId'] as String;
    controller?._runId = runId;
    if (controller?.isCancelled == true) {
      await _cancelRun(runId, jwt);
      throw const AgentRunCancelledException();
    }

    final completer = Completer<AgentRunResult>();
    final streamClient = http.Client();
    StreamSubscription<String>? subscription;
    var cancelPosted = false;

    Future<void> cancelActiveRun() async {
      if (cancelPosted) return;
      cancelPosted = true;
      if (subscription != null && !completer.isCompleted) {
        completer.completeError(const AgentRunCancelledException());
      }
      streamClient.close();
      await _cancelRun(runId, jwt);
      await subscription?.cancel().timeout(
        const Duration(seconds: 1),
        onTimeout: () {},
      );
    }

    controller?._cancelActiveRun = cancelActiveRun;

    // Step 2: Stream SSE events from GET /v1/runs/:id/stream
    final streamUri = Uri.parse('$_serverUrl/v1/runs/$runId/stream');
    final request = http.Request('GET', streamUri);
    if (jwt != null) request.headers['Authorization'] = 'Bearer $jwt';
    request.headers['Accept'] = 'text/event-stream';

    final http.StreamedResponse streamedResp;
    try {
      streamedResp = await streamClient
          .send(request)
          .timeout(const Duration(minutes: 8));
    } catch (_) {
      streamClient.close();
      if (controller?.isCancelled == true) {
        throw const AgentRunCancelledException();
      }
      rethrow;
    }

    if (streamedResp.statusCode != 200) {
      streamClient.close();
      throw Exception('Stream error ${streamedResp.statusCode}');
    }

    if (controller?.isCancelled == true) {
      await cancelActiveRun();
      throw const AgentRunCancelledException();
    }

    subscription = streamedResp.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (controller?.isCancelled == true) return;
            final payload = decodeSseLine(line);
            if (payload == null) return;

            switch (payload) {
              case SseEventPayload(:final event):
                events.add(event);
                onEvent?.call(event);

              case SsePlanPayload(:final plan):
                final doneEvent = const AgentEvent(
                  kind: AgentEventKind.complete,
                  title: 'Plan complete',
                  detail: 'Your itinerary is ready.',
                );
                events.add(doneEvent);
                onEvent?.call(doneEvent);
                if (!completer.isCompleted) {
                  completer.complete(
                    AgentRunResult.plan(
                      plan,
                      List.unmodifiable(events),
                      runId: runId,
                    ),
                  );
                }

              case SseQuestionPayload(:final question):
                final qEvent = AgentEvent(
                  kind: AgentEventKind.question,
                  title: 'Follow-up needed',
                  detail: question,
                );
                events.add(qEvent);
                onEvent?.call(qEvent);
                if (!completer.isCompleted) {
                  completer.complete(
                    AgentRunResult.question(
                      question,
                      List.unmodifiable(events),
                      runId: runId,
                    ),
                  );
                }

              case SseErrorPayload(:final message):
                if (!completer.isCompleted) {
                  completer.completeError(Exception(message));
                }
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              // Stream closed without a complete event — treat as error
              completer.completeError(
                Exception('Agent run ended without a result'),
              );
            }
          },
          onError: (Object err) {
            if (!completer.isCompleted) completer.completeError(err);
          },
          cancelOnError: true,
        );

    try {
      return await completer.future;
    } finally {
      streamClient.close();
      await subscription.cancel().timeout(
        const Duration(seconds: 1),
        onTimeout: () {},
      );
      if (controller?._runId == runId) {
        controller?._cancelActiveRun = null;
      }
    }
  }

  Future<void> _cancelRun(String runId, String? jwt) async {
    try {
      await _httpClient
          .post(
            Uri.parse('$_serverUrl/v1/runs/$runId/cancel'),
            headers: {if (jwt != null) 'Authorization': 'Bearer $jwt'},
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Best-effort: local cancellation should not block the UI.
    }
  }

  Future<String?> _accessToken() async {
    final provider = _accessTokenProvider;
    if (provider != null) return provider();
    final externalToken = await externalAccessToken();
    if (externalToken != null) return externalToken;
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _useMemoryPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localValue = prefs.getBool('northstar_use_ai_memory');
      if (localValue != null) return localValue;
    } catch (_) {
      // Unit tests and early app startup can run before platform bindings exist.
    }

    try {
      final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
      final preferences = (metadata?['preferences'] as Map?) ?? {};
      return preferences['use_ai_memory'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }
}
