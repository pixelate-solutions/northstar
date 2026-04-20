enum AgentEventKind { model, tool, observation, question, complete }

class AgentEvent {
  const AgentEvent({
    required this.kind,
    required this.title,
    this.detail = '',
  });

  final AgentEventKind kind;
  final String title;
  final String detail;

  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    return AgentEvent(
      kind: AgentEventKind.values.firstWhere(
        (e) => e.name == (json['kind'] as String? ?? 'model'),
        orElse: () => AgentEventKind.model,
      ),
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'title': title,
        'detail': detail,
      };
}

typedef AgentEventSink = void Function(AgentEvent event);
