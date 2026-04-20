import 'package:flutter/material.dart';
import '../../agent/agent_client.dart';
import '../../models/trip_plan.dart';
import '../../models/agent_event.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/agent_timeline.dart';

class AgentPanel extends StatefulWidget {
  const AgentPanel({super.key, required this.plan, required this.onEdit});

  final TripPlan plan;
  final Future<void> Function(
    String instruction,
    AgentEventSink onEvent, {
    AgentRunController? controller,
  })
  onEdit;

  @override
  State<AgentPanel> createState() => _AgentPanelState();
}

class _AgentPanelState extends State<AgentPanel> {
  final _controller = TextEditingController(
    text: 'Make mornings slower and add stronger food anchors.',
  );
  final List<AgentEvent> _events = [];
  bool _running = false;
  AgentRunController? _controllerRun;

  @override
  void dispose() {
    _controllerRun?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runEdit() async {
    final instruction = _controller.text.trim();
    if (instruction.isEmpty || _running) return;
    setState(() {
      _running = true;
      _controllerRun = AgentRunController();
      _events.clear();
    });
    try {
      await widget.onEdit(instruction, (event) {
        if (!mounted) return;
        setState(() => _events.add(event));
      }, controller: _controllerRun);
    } catch (_) {
      // The parent surfaces run errors as events.
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _controllerRun = null;
    });
  }

  Future<void> _cancelEdit() async {
    final controller = _controllerRun;
    setState(() {
      _running = false;
      _controllerRun = null;
    });
    await controller?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final visibleEvents = _events.isEmpty
        ? widget.plan.agentEvents.reversed.take(7).toList().reversed.toList()
        : _events;

    return Column(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_fix_high_rounded, color: kForest),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit with the agent',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ask for changes in plain language. The model decides which tool to call, observes results, and keeps going until the plan is valid.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .55),
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('agent-edit-field'),
                controller: _controller,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Change request',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('agent-edit-button'),
                onPressed: _running ? null : _runEdit,
                icon: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_running ? 'Editing plan…' : 'Update plan'),
              ),
              if (_running) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _cancelEdit,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop editing'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (visibleEvents.isNotEmpty) AgentTimeline(events: visibleEvents),
      ],
    );
  }
}
