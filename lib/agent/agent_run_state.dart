import '../models/trip_plan.dart';
import '../models/agent_event.dart';

enum AgentRunStatus { idle, running, awaitingAnswer, done, error }

class AgentRunState {
  const AgentRunState({
    this.status = AgentRunStatus.idle,
    this.events = const [],
    this.pendingQuestion,
    this.errorMessage,
    this.plan,
  });

  final AgentRunStatus status;
  final List<AgentEvent> events;
  final String? pendingQuestion;
  final String? errorMessage;
  final TripPlan? plan;

  bool get isRunning => status == AgentRunStatus.running;
  bool get isDone => status == AgentRunStatus.done;
  bool get hasError => status == AgentRunStatus.error;
  bool get awaitingAnswer => status == AgentRunStatus.awaitingAnswer;

  AgentRunState copyWith({
    AgentRunStatus? status,
    List<AgentEvent>? events,
    String? pendingQuestion,
    String? errorMessage,
    TripPlan? plan,
  }) {
    return AgentRunState(
      status: status ?? this.status,
      events: events ?? this.events,
      pendingQuestion: pendingQuestion ?? this.pendingQuestion,
      errorMessage: errorMessage ?? this.errorMessage,
      plan: plan ?? this.plan,
    );
  }
}
