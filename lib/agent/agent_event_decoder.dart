import '../models/agent_event.dart';
import '../models/trip_plan.dart';
import 'dart:convert';

// Parses one SSE "data: {...}" line into an AgentEvent or TripPlan.
// Returns null for comment lines and empty lines.
sealed class SsePayload {}

class SseEventPayload extends SsePayload {
  SseEventPayload(this.event);
  final AgentEvent event;
}

class SsePlanPayload extends SsePayload {
  SsePlanPayload(this.plan);
  final TripPlan plan;
}

class SseQuestionPayload extends SsePayload {
  SseQuestionPayload(this.question);
  final String question;
}

class SseErrorPayload extends SsePayload {
  SseErrorPayload(this.message);
  final String message;
}

SsePayload? decodeSseLine(String line) {
  if (!line.startsWith('data:')) return null;
  final raw = line.substring(5).trim();
  if (raw.isEmpty || raw == '[DONE]') return null;

  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final kind = json['kind'] as String? ?? '';

    if (kind == 'complete') {
      final planJson = json['plan'] as Map<String, dynamic>?;
      if (planJson != null) return SsePlanPayload(TripPlan.fromJson(planJson));
    }

    if (kind == 'question') {
      final q = json['question'] as String? ?? '';
      return SseQuestionPayload(q);
    }

    if (kind == 'error' || kind == 'constraint_exceeded') {
      final msg = json['message'] as String? ?? kind;
      return SseErrorPayload(msg);
    }

    // model, tool, observation events
    return SseEventPayload(AgentEvent.fromJson(json));
  } catch (_) {
    return null;
  }
}
