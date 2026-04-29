import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../agent/agent_client.dart';
import '../agent/agent_run_state.dart';
import '../core/utils/friendly_error.dart';
import '../models/agent_event.dart';
import '../models/trip_brief.dart';
import '../models/trip_plan.dart';
import 'trip_providers.dart';

final agentClientProvider = Provider<AgentClient>((ref) => AgentClient());

class AgentRunSnapshot {
  const AgentRunSnapshot({
    this.status = AgentRunStatus.idle,
    this.events = const [],
    this.followUpQuestion,
    this.errorMessage,
  });

  final AgentRunStatus status;
  final List<AgentEvent> events;
  final String? followUpQuestion;
  final String? errorMessage;

  AgentRunSnapshot copyWith({
    AgentRunStatus? status,
    List<AgentEvent>? events,
    String? followUpQuestion,
    String? errorMessage,
    bool clearQuestion = false,
    bool clearError = false,
  }) {
    return AgentRunSnapshot(
      status: status ?? this.status,
      events: events ?? this.events,
      followUpQuestion: clearQuestion
          ? null
          : followUpQuestion ?? this.followUpQuestion,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final agentRunProvider =
    NotifierProviderFamily<AgentRunNotifier, AgentRunSnapshot, String>(
      AgentRunNotifier.new,
    );

class AgentRunNotifier extends FamilyNotifier<AgentRunSnapshot, String> {
  @override
  AgentRunSnapshot build(String arg) => const AgentRunSnapshot();

  Future<AgentRunResult> createPlan(TripBrief brief) async {
    return _run(
      () => ref
          .read(agentClientProvider)
          .createPlan(brief, onEvent: _appendEvent),
    );
  }

  Future<AgentRunResult> editPlan(TripPlan plan, String instruction) async {
    return _run(
      () => ref
          .read(agentClientProvider)
          .editPlan(plan, instruction, onEvent: _appendEvent),
      saveResult: true,
    );
  }

  Future<AgentRunResult> _run(
    Future<AgentRunResult> Function() operation, {
    bool saveResult = false,
  }) async {
    state = const AgentRunSnapshot(status: AgentRunStatus.running);
    try {
      final result = await operation();
      if (result.plan != null) {
        state = state.copyWith(status: AgentRunStatus.done, clearError: true);
        if (saveResult) {
          await ref.read(tripListProvider.notifier).savePlan(result.plan!);
        }
      } else {
        state = state.copyWith(
          status: AgentRunStatus.awaitingAnswer,
          followUpQuestion: result.followUpQuestion,
          clearError: true,
        );
      }
      return result;
    } catch (err) {
      state = state.copyWith(
        status: AgentRunStatus.error,
        errorMessage: friendlyAgentError(err),
      );
      rethrow;
    }
  }

  void _appendEvent(AgentEvent event) {
    state = state.copyWith(events: [...state.events, event]);
  }
}
