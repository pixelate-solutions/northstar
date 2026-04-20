import 'supabase_client.dart';

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.role,
    this.content,
    this.toolCalls,
    this.toolName,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String userId;
  final String role;
  final String? content;
  final Map<String, dynamic>? toolCalls;
  final String? toolName;
  final DateTime createdAt;

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'] as String? ?? '',
      tripId: json['trip_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String?,
      toolCalls: json['tool_calls'] as Map<String, dynamic>?,
      toolName: json['tool_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'trip_id': tripId,
    'user_id': userId,
    'role': role,
    'content': content,
    'tool_calls': toolCalls,
    'tool_name': toolName,
    'created_at': createdAt.toIso8601String(),
  };
}

class ConversationRepository {
  static const _table = 'conversations';

  Future<List<ConversationMessage>> fetchForTrip(String tripId) async {
    final rows = await supabase
        .from(_table)
        .select()
        .eq('trip_id', tripId)
        .order('created_at');

    return rows.map(ConversationMessage.fromJson).toList();
  }

  Future<ConversationMessage> add({
    required String tripId,
    required String role,
    String? content,
    Map<String, dynamic>? toolCalls,
    String? toolName,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'Cannot save a conversation without an authenticated user.',
      );
    }

    final rows = await supabase.from(_table).insert({
      'trip_id': tripId,
      'user_id': userId,
      'role': role,
      'content': content,
      'tool_calls': toolCalls,
      'tool_name': toolName,
    }).select();

    return ConversationMessage.fromJson(rows.first);
  }
}
