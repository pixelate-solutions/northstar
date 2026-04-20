import 'package:flutter/material.dart';
import '../../models/agent_event.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class AgentTimeline extends StatelessWidget {
  const AgentTimeline({super.key, required this.events});

  final List<AgentEvent> events;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Agent loop',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < events.length; i++)
            _AgentEventRow(event: events[i], isLast: i == events.length - 1),
        ],
      ),
    );
  }
}

class _AgentEventRow extends StatelessWidget {
  const _AgentEventRow({required this.event, required this.isLast});

  final AgentEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.kind) {
      AgentEventKind.model => kForest,
      AgentEventKind.tool => kCoral,
      AgentEventKind.observation => kSky,
      AgentEventKind.question => kGold,
      AgentEventKind.complete => kInk,
    };
    final icon = switch (event.kind) {
      AgentEventKind.model => Icons.psychology_alt_outlined,
      AgentEventKind.tool => Icons.api_outlined,
      AgentEventKind.observation => Icons.visibility_outlined,
      AgentEventKind.question => Icons.help_outline_rounded,
      AgentEventKind.complete => Icons.check_rounded,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: Theme.of(context).colorScheme.brightness == Brightness.light
                        ? kLine
                        : kDarkLine,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  if (event.detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6),
                            height: 1.25,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
