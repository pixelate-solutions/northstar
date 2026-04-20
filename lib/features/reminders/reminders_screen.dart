import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/reminder.dart';
import '../../providers/reminder_providers.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

final _fmt = DateFormat('MMM d, y · h:mm a');

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reminders',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alarm_rounded),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reminders) => reminders.isEmpty
            ? _EmptyState(onAdd: () => _showAddDialog(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reminders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ReminderCard(
                  reminder: reminders[i],
                  onDelete: () => ref
                      .read(remindersProvider(tripId).notifier)
                      .deleteReminder(reminders[i].id),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Add reminder'),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _AddReminderDialog(
        tripId: tripId,
        userId: userId,
        onSave: (reminder) =>
            ref.read(remindersProvider(tripId).notifier).addReminder(reminder),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, required this.onDelete});
  final Reminder reminder;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPast = reminder.remindAt.isBefore(DateTime.now());
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isPast ? kMuted : kForest).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              reminder.sent
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined,
              color: isPast ? kMuted : kForest,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _fmt.format(reminder.remindAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isPast ? kMuted : kForest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reminder.body != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    reminder.body!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: kCoral,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.alarm_off_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .3),
            ),
            const SizedBox(height: 16),
            Text(
              'No reminders yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Add reminders so you never miss a stop.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('Add reminder'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddReminderDialog extends StatefulWidget {
  const _AddReminderDialog({
    required this.tripId,
    required this.userId,
    required this.onSave,
  });
  final String tripId;
  final String userId;
  final void Function(Reminder) onSave;

  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  DateTime _remindAt = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add reminder',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded, color: kForest),
            title: Text(
              _fmt.format(_remindAt.toLocal()),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _remindAt,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (picked == null || !context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_remindAt),
              );
              if (!mounted) return;
              setState(() {
                _remindAt = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  time?.hour ?? _remindAt.hour,
                  time?.minute ?? _remindAt.minute,
                );
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_titleCtrl.text.trim().isEmpty) return;
            widget.onSave(
              Reminder(
                id: const Uuid().v4(),
                userId: widget.userId,
                tripId: widget.tripId,
                title: _titleCtrl.text.trim(),
                body: _bodyCtrl.text.trim().isEmpty
                    ? null
                    : _bodyCtrl.text.trim(),
                remindAt: _remindAt,
              ),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
