import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/agent/agent_client.dart';
import 'package:northstar/models/agent_event.dart';
import 'package:northstar/models/trip_brief.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('AgentClient createPlan posts create mode and consumes SSE plan', () async {
    final serverDone = Completer<void>();

    server.listen((request) async {
      if (request.method == 'POST' && request.uri.path == '/v1/runs') {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        expect(body['mode'], 'create');
        expect(body['brief'], isA<Map<String, dynamic>>());
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'runId': 'run-1'}));
        await request.response.close();
        return;
      }

      if (request.method == 'GET' &&
          request.uri.path == '/v1/runs/run-1/stream') {
        request.response.headers
          ..contentType = ContentType('text', 'event-stream')
          ..set(HttpHeaders.cacheControlHeader, 'no-cache');
        request.response.write(
          'data: ${jsonEncode({'kind': 'model', 'title': 'Thinking', 'detail': 'Step 1'})}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({'kind': 'complete', 'plan': _planJson()})}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
        serverDone.complete();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    final client = AgentClient(
      serverUrl: 'http://localhost:${server.port}',
      accessTokenProvider: () => 'test-token',
    );
    final events = <AgentEvent>[];
    final result = await client.createPlan(
      const TripBrief(destinations: 'Lisbon', dates: 'May 1 - May 4'),
      onEvent: events.add,
    );

    expect(result.success, isTrue);
    expect(result.plan!.title, 'Mock Lisbon');
    expect(events.map((event) => event.kind), contains(AgentEventKind.model));
    expect(
      events.map((event) => event.kind),
      contains(AgentEventKind.complete),
    );
    await serverDone.future;
  });

  test('AgentClient returns follow-up questions from SSE', () async {
    server.listen((request) async {
      if (request.method == 'POST') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'runId': 'run-2'}));
        await request.response.close();
        return;
      }

      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({'kind': 'question', 'question': 'When do you want to travel?'})}\n\n',
      );
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });

    final client = AgentClient(
      serverUrl: 'http://localhost:${server.port}',
      accessTokenProvider: () => 'test-token',
    );
    final result = await client.createPlan(
      const TripBrief(destinations: 'Lisbon'),
    );

    expect(result.needsMoreInfo, isTrue);
    expect(result.followUpQuestion, 'When do you want to travel?');
  });
}

Map<String, dynamic> _planJson() => {
  'id': 'mock-plan',
  'title': 'Mock Lisbon',
  'destinations': ['Lisbon'],
  'date_range': 'May 1 - May 4',
  'summary': 'A compact Lisbon plan.',
  'pace': 'Balanced',
  'days': [
    {
      'label': 'Day 1',
      'title': 'Arrival',
      'guidance': 'Keep it light.',
      'stops': [
        {
          'time': '10:00',
          'title': 'Alfama walk',
          'place': 'Alfama',
          'note': 'Start with views and cafes.',
          'latitude': 38.7113,
          'longitude': -9.1293,
          'tag': 'Walk',
        },
      ],
    },
  ],
  'open_questions': <String>[],
  'agent_events': <Map<String, dynamic>>[],
  'updated_at': DateTime(2026, 5).toIso8601String(),
};
