import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/agent/agent_event_decoder.dart';
import 'package:northstar/models/agent_event.dart';

void main() {
  test('SSE decoder accepts agent event payloads used by tool loop', () {
    for (final kind in ['model', 'tool', 'observation']) {
      final payload = decodeSseLine(
        'data: ${jsonEncode({'kind': kind, 'title': 'event title', 'detail': 'event detail'})}',
      );

      expect(payload, isA<SseEventPayload>());
      final event = (payload as SseEventPayload).event;
      expect(event.title, 'event title');
      expect(event.detail, 'event detail');
      expect(event.kind.name, kind);
    }
  });

  test('SSE decoder maps terminal errors to error payloads', () {
    final payload = decodeSseLine(
      'data: ${jsonEncode({'kind': 'constraint_exceeded', 'message': 'Reached step limit'})}',
    );

    expect(payload, isA<SseErrorPayload>());
    expect((payload as SseErrorPayload).message, 'Reached step limit');
  });

  test('AgentEvent JSON rejects unknown kinds safely', () {
    final event = AgentEvent.fromJson({
      'kind': 'unknown',
      'title': 'Fallback',
      'detail': '',
    });

    expect(event.kind, AgentEventKind.model);
  });
}
