import 'dart:ui';
import 'package:flutter/material.dart';
import '../../agent/agent_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/agent_timeline.dart';
import '../../models/agent_event.dart';
import '../../models/trip_brief.dart';

class NewTripSheet extends StatefulWidget {
  const NewTripSheet({super.key, required this.agent});
  final AgentClient agent;

  @override
  State<NewTripSheet> createState() => _NewTripSheetState();
}

class _NewTripSheetState extends State<NewTripSheet> {
  final _destinations = TextEditingController(text: 'Barcelona, Paris');
  final _dates = TextEditingController(text: 'June 8 - June 15');
  final _travelers = TextEditingController(text: '2 adults');
  final _interests = TextEditingController(
    text: 'food, architecture, easy walks',
  );
  final _origin = TextEditingController(text: 'San Francisco');
  final _budget = TextEditingController();
  final _notes = TextEditingController(text: 'Prefer low-stress mornings.');
  final _followUp = TextEditingController();

  final List<AgentEvent> _events = [];
  String _pace = 'Balanced';
  String? _question;
  bool _running = false;
  AgentRunController? _runController;

  @override
  void dispose() {
    _runController?.cancel();
    _destinations.dispose();
    _dates.dispose();
    _travelers.dispose();
    _interests.dispose();
    _origin.dispose();
    _budget.dispose();
    _notes.dispose();
    _followUp.dispose();
    super.dispose();
  }

  TripBrief get _brief => TripBrief(
    origin: _origin.text.trim(),
    destinations: _destinations.text.trim(),
    dates: _dates.text.trim(),
    travelers: _travelers.text.trim(),
    interests: _interests.text.trim(),
    pace: _pace,
    budget: _budget.text.trim(),
    notes: _notes.text.trim(),
  );

  Future<void> _createPlan() async {
    if (_running) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _running = true;
      _runController = AgentRunController();
      _events.clear();
      _question = null;
    });

    try {
      final controller = _runController;
      final result = await widget.agent.createPlan(
        _brief,
        controller: controller,
        onEvent: (e) {
          if (!mounted) return;
          setState(() => _events.add(e));
        },
      );

      if (!mounted) return;

      if (result.needsMoreInfo) {
        setState(() {
          _question = result.followUpQuestion;
          _running = false;
          _runController = null;
        });
        return;
      }

      if (result.plan != null) {
        Navigator.of(context).pop(result.plan);
      }
    } catch (e) {
      if (!mounted) return;
      if (e is AgentRunCancelledException) {
        setState(() {
          _running = false;
          _runController = null;
        });
        return;
      }
      setState(() {
        _running = false;
        _runController = null;
        _events.add(
          AgentEvent(
            kind: AgentEventKind.complete,
            title: 'Error',
            detail: e.toString(),
          ),
        );
      });
    }
  }

  Future<void> _cancelPlan() async {
    final controller = _runController;
    setState(() {
      _running = false;
      _runController = null;
    });
    await controller?.cancel();
  }

  void _answerFollowUp() {
    final answer = _followUp.text.trim();
    if (answer.isEmpty || _question == null) return;
    final question = _question!.toLowerCase();
    setState(() {
      if (question.contains('where')) {
        _destinations.text = answer;
      } else if (question.contains('date') || question.contains('when')) {
        _dates.text = answer;
      } else if (question.contains('who') || question.contains('traveler')) {
        _travelers.text = answer;
      } else {
        _interests.text = _interests.text.trim().isEmpty
            ? answer
            : '${_interests.text}, $answer';
      }
      _followUp.clear();
      _question = null;
    });
    _createPlan();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: .92,
        minChildSize: .58,
        maxChildSize: .96,
        builder: (context, controller) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: .94),
                  border: Border.all(color: Colors.white.withValues(alpha: .2)),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Plan a trip',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Northstar will ask follow-ups only when the model decides the plan is missing something important.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: .55),
                        height: 1.32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Field(
                      controller: _destinations,
                      label: 'Destination or route',
                      icon: Icons.place_outlined,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _dates,
                      label: 'Dates or rough timing',
                      icon: Icons.date_range_outlined,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _travelers,
                      label: 'Travelers',
                      icon: Icons.group_outlined,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _interests,
                      label: 'What should it optimize for?',
                      icon: Icons.tune_rounded,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final pace in const ['Easy', 'Balanced', 'Packed'])
                          ChoiceChip(
                            label: Text(pace),
                            selected: pace == _pace,
                            onSelected: (_) => setState(() => _pace = pace),
                          ),
                      ],
                    ),
                    if (_question != null) ...[
                      const SizedBox(height: 16),
                      _FollowUpBox(
                        question: _question!,
                        controller: _followUp,
                        onAnswer: _answerFollowUp,
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (_running)
                      OutlinedButton.icon(
                        onPressed: _cancelPlan,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop planning'),
                      )
                    else
                      FilledButton.icon(
                        key: const ValueKey('create-plan-button'),
                        onPressed: _createPlan,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Create plan'),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Optional context',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: .55),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _origin,
                      label: 'Starting city',
                      icon: Icons.flight_takeoff_rounded,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _budget,
                      label: 'Budget (optional)',
                      icon: Icons.payments_outlined,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Anything else',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    if (_events.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      AgentTimeline(events: _events),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FollowUpBox extends StatelessWidget {
  const _FollowUpBox({
    required this.question,
    required this.controller,
    required this.onAnswer,
  });
  final String question;
  final TextEditingController controller;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurface : kMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kForest.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Answer',
              prefixIcon: Icon(Icons.reply_outlined),
            ),
            onSubmitted: (_) => onAnswer(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onAnswer,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Answer and continue'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
