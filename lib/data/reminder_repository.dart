import '../models/reminder.dart';
import 'supabase_client.dart';

class ReminderRepository {
  static const _table = 'reminders';

  Future<List<Reminder>> fetchForTrip(String tripId) async {
    final rows = await supabase
        .from(_table)
        .select()
        .eq('trip_id', tripId)
        .order('remind_at');

    return rows.map(Reminder.fromJson).toList();
  }

  Future<Reminder> upsert(Reminder reminder) async {
    final payload = reminder.toJson();
    payload['user_id'] ??= supabase.auth.currentUser?.id;
    if (payload['user_id'] == null) {
      throw StateError('Cannot save a reminder without an authenticated user.');
    }
    if ((payload['id'] as String).isEmpty) payload.remove('id');

    final rows = await supabase
        .from(_table)
        .upsert(payload, onConflict: 'id')
        .select();

    return Reminder.fromJson(rows.first);
  }

  Future<void> delete(String reminderId) async {
    await supabase.from(_table).delete().eq('id', reminderId);
  }
}
