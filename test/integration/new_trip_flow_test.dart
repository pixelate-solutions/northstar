import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/agent/agent_client.dart';
import 'package:northstar/features/new_trip/new_trip_sheet.dart';
import 'package:northstar/features/plan/plan_detail_screen.dart';
import 'package:northstar/features/plan/plan_view.dart';
import 'package:northstar/models/agent_event.dart';
import 'package:northstar/models/trip_brief.dart';
import 'package:northstar/models/trip_day.dart';
import 'package:northstar/models/trip_plan.dart';
import 'package:northstar/models/trip_stop.dart';

void main() {
  testWidgets('new trip form returns a plan and plan tabs render', (
    tester,
  ) async {
    TripPlan? created;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  created = await showModalBottomSheet<TripPlan>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => NewTripSheet(agent: _FakeAgentClient()),
                  );
                },
                child: const Text('Open planner'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open planner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-plan-button')));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.title, 'Mock Barcelona');

    await tester.pumpWidget(MaterialApp(home: _PlanHarness(plan: created!)));
    await tester.pumpAndSettle();

    expect(find.text('Mock Barcelona'), findsOneWidget);
    expect(find.text('Plan'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('map-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Alfama'), findsNothing);
    expect(find.text('Eixample'), findsWidgets);

    expect(find.byKey(const ValueKey('agent-tab')), findsNothing);
  });
}

class _FakeAgentClient extends AgentClient {
  @override
  Future<AgentRunResult> createPlan(
    TripBrief brief, {
    AgentEventSink? onEvent,
  }) async {
    const event = AgentEvent(
      kind: AgentEventKind.model,
      title: 'Mock planning',
      detail: 'The mock agent built a plan.',
    );
    onEvent?.call(event);
    return AgentRunResult.plan(_mockPlan(), const [event]);
  }
}

class _PlanHarness extends StatefulWidget {
  const _PlanHarness({required this.plan});

  final TripPlan plan;

  @override
  State<_PlanHarness> createState() => _PlanHarnessState();
}

class _PlanHarnessState extends State<_PlanHarness> {
  PlanView view = PlanView.overview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PlanDetailScreen(
        plan: widget.plan,
        view: view,
        onViewChanged: (next) => setState(() => view = next),
        onEdit: (_, onEvent) async {
          onEvent(
            const AgentEvent(
              kind: AgentEventKind.complete,
              title: 'Updated',
              detail: '',
            ),
          );
        },
      ),
    );
  }
}

TripPlan _mockPlan() => TripPlan(
  id: 'mock-barcelona',
  title: 'Mock Barcelona',
  destinations: const ['Barcelona'],
  dateRange: 'June 8 - June 15',
  summary: 'A food and architecture plan.',
  pace: 'Balanced',
  days: const [
    TripDay(
      label: 'Day 1',
      title: 'Arrival',
      guidance: 'Stay close to the hotel.',
      stops: [
        TripStop(
          time: '14:00',
          title: 'Check in',
          place: 'Eixample',
          note: 'Drop bags and reset.',
          latitude: 41.3916,
          longitude: 2.1649,
          tag: 'Arrival',
        ),
      ],
    ),
  ],
  openQuestions: const [],
  agentEvents: const [],
  updatedAt: DateTime(2026, 6, 1),
);
