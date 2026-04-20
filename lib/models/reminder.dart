class Reminder {
  const Reminder({
    required this.id,
    required this.tripId,
    required this.title,
    required this.remindAt,
    this.userId,
    this.stopId,
    this.body,
    this.sent = false,
  });

  final String id;
  final String? userId;
  final String tripId;
  final String title;
  final DateTime remindAt;
  final String? stopId;
  final String? body;
  final bool sent;

  Reminder copyWith({
    String? userId,
    String? title,
    DateTime? remindAt,
    String? stopId,
    String? body,
    bool? sent,
  }) {
    return Reminder(
      id: id,
      userId: userId ?? this.userId,
      tripId: tripId,
      title: title ?? this.title,
      remindAt: remindAt ?? this.remindAt,
      stopId: stopId ?? this.stopId,
      body: body ?? this.body,
      sent: sent ?? this.sent,
    );
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      tripId: json['trip_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      remindAt: json['remind_at'] != null
          ? DateTime.parse(json['remind_at'] as String)
          : DateTime.now(),
      stopId: json['stop_id'] as String?,
      body: json['body'] as String?,
      sent: json['sent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'user_id': userId,
    'trip_id': tripId,
    'title': title,
    'remind_at': remindAt.toIso8601String(),
    'stop_id': stopId,
    'body': body,
    'sent': sent,
  };
}
