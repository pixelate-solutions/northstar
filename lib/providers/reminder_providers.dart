import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reminder_repository.dart';
import '../models/reminder.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository();
});

// Keyed by tripId
final remindersProvider =
    AsyncNotifierProviderFamily<RemindersNotifier, List<Reminder>, String>(
  RemindersNotifier.new,
);

class RemindersNotifier extends FamilyAsyncNotifier<List<Reminder>, String> {
  @override
  Future<List<Reminder>> build(String arg) async {
    try {
      return await ref.read(reminderRepositoryProvider).fetchForTrip(arg);
    } catch (_) {
      return [];
    }
  }

  Future<void> addReminder(Reminder reminder) async {
    final saved = await ref.read(reminderRepositoryProvider).upsert(reminder);
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, saved]..sort((a, b) => a.remindAt.compareTo(b.remindAt)));
  }

  Future<void> deleteReminder(String reminderId) async {
    await ref.read(reminderRepositoryProvider).delete(reminderId);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((r) => r.id != reminderId).toList());
  }
}
