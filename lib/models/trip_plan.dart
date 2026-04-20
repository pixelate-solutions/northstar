import 'agent_event.dart';
import 'trip_day.dart';
import 'trip_stop.dart';

class TripPlan {
  const TripPlan({
    required this.id,
    required this.title,
    required this.destinations,
    required this.dateRange,
    required this.summary,
    required this.pace,
    required this.days,
    required this.openQuestions,
    required this.agentEvents,
    required this.updatedAt,
    this.ownerUserId,
    this.sharedWithEmails = const [],
    this.budgetTotal,
    this.budgetCurrency = 'USD',
    this.budgetCategories = const {},
  });

  final String id;
  final String title;
  final List<String> destinations;
  final String dateRange;
  final String summary;
  final String pace;
  final List<TripDay> days;
  final List<String> openQuestions;
  final List<AgentEvent> agentEvents;
  final DateTime updatedAt;
  final String? ownerUserId;
  final List<String> sharedWithEmails;
  final double? budgetTotal;
  final String budgetCurrency;
  final Map<String, double> budgetCategories;

  List<TripStop> get stops => [
    for (final day in days)
      for (final stop in day.stops) stop,
  ];

  bool isOwnedBy(String? userId) {
    return ownerUserId == null || userId == null || ownerUserId == userId;
  }

  bool isSharedWith(String? userId) => !isOwnedBy(userId);

  TripPlan copyWith({
    String? title,
    List<String>? destinations,
    String? dateRange,
    String? summary,
    String? pace,
    List<TripDay>? days,
    List<String>? openQuestions,
    List<AgentEvent>? agentEvents,
    DateTime? updatedAt,
    String? ownerUserId,
    List<String>? sharedWithEmails,
    double? budgetTotal,
    String? budgetCurrency,
    Map<String, double>? budgetCategories,
  }) {
    return TripPlan(
      id: id,
      title: title ?? this.title,
      destinations: destinations ?? this.destinations,
      dateRange: dateRange ?? this.dateRange,
      summary: summary ?? this.summary,
      pace: pace ?? this.pace,
      days: days ?? this.days,
      openQuestions: openQuestions ?? this.openQuestions,
      agentEvents: agentEvents ?? this.agentEvents,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      sharedWithEmails: sharedWithEmails ?? this.sharedWithEmails,
      budgetTotal: budgetTotal ?? this.budgetTotal,
      budgetCurrency: budgetCurrency ?? this.budgetCurrency,
      budgetCategories: budgetCategories ?? this.budgetCategories,
    );
  }

  factory TripPlan.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? [];
    final rawEvents = json['agent_events'] as List<dynamic>? ?? [];
    final rawDests = json['destinations'] as List<dynamic>? ?? [];
    final rawQuestions = json['open_questions'] as List<dynamic>? ?? [];
    final rawShared = json['shared_with_emails'] as List<dynamic>? ?? [];
    final rawBudget =
        (json['budget_categories'] as Map?)?.cast<String, dynamic>() ?? {};

    return TripPlan(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      destinations: rawDests.map((d) => d as String).toList(),
      dateRange: json['date_range'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      pace: json['pace'] as String? ?? 'Balanced',
      days: rawDays
          .map((d) => TripDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      openQuestions: rawQuestions.map((q) => q as String).toList(),
      agentEvents: rawEvents
          .map((e) => AgentEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      ownerUserId: (json['owner_user_id'] ?? json['user_id'])?.toString(),
      sharedWithEmails: rawShared.map((email) => email.toString()).toList(),
      budgetTotal: (json['budget_total'] as num?)?.toDouble(),
      budgetCurrency: json['budget_currency'] as String? ?? 'USD',
      budgetCategories: rawBudget.map(
        (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'destinations': destinations,
    'date_range': dateRange,
    'summary': summary,
    'pace': pace,
    'days': days.map((d) => d.toJson()).toList(),
    'open_questions': openQuestions,
    'agent_events': agentEvents.map((e) => e.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
    if (ownerUserId != null) 'owner_user_id': ownerUserId,
    'shared_with_emails': sharedWithEmails,
    if (budgetTotal != null) 'budget_total': budgetTotal,
    'budget_currency': budgetCurrency,
    'budget_categories': budgetCategories,
  };

  static List<TripPlan> seedPlans() {
    final baseEvents = [
      const AgentEvent(
        kind: AgentEventKind.model,
        title: 'Model selected plan tools',
        detail:
            'It normalized the brief, expanded stops, mapped places, and checked timing.',
      ),
      const AgentEvent(
        kind: AgentEventKind.tool,
        title: 'map_stops',
        detail: 'Returned 8 place coordinates and a walkable city route.',
      ),
    ];

    return [
      TripPlan(
        id: 'seed-barcelona',
        title: 'Barcelona design week',
        destinations: const ['Barcelona'],
        dateRange: 'June 8 - June 15',
        summary:
            'A simple Barcelona plan with architecture, food, and low-stress mornings. Each day keeps one anchor and one flexible block.',
        pace: 'Easy',
        updatedAt: DateTime(2026, 4, 16, 10),
        openQuestions: const [
          'Confirm hotel neighborhood for transfer and leave-time reminders.',
          'Pick the dinner budget before reservations are drafted.',
        ],
        agentEvents: baseEvents,
        days: const [
          TripDay(
            label: 'Day 1',
            title: 'Arrive and settle in',
            guidance:
                'Keep the first day close to the hotel and avoid hard reservations.',
            stops: [
              TripStop(
                time: '14:00',
                title: 'Eixample check-in',
                place: 'Eixample',
                note: 'Drop bags, reset, and keep the first hour unplanned.',
                latitude: 41.3916,
                longitude: 2.1649,
                tag: 'Arrival',
              ),
              TripStop(
                time: '17:00',
                title: 'Passeig de Gracia walk',
                place: 'Passeig de Gracia',
                note: 'Architecture and cafes without committing to a tour.',
                latitude: 41.3934,
                longitude: 2.1633,
                tag: 'Walk',
              ),
              TripStop(
                time: '19:30',
                title: 'Early tapas anchor',
                place: 'Sant Antoni',
                note:
                    'Choose a relaxed first dinner after check-in is confirmed.',
                latitude: 41.3789,
                longitude: 2.1620,
                tag: 'Food',
              ),
            ],
          ),
          TripDay(
            label: 'Day 2',
            title: 'Gaudi without rushing',
            guidance:
                'One ticketed stop, one neighborhood, and a clean dinner zone.',
            stops: [
              TripStop(
                time: '10:30',
                title: 'Sagrada Familia',
                place: 'La Sagrada Familia',
                note: 'Timed entry with a buffer before and after.',
                latitude: 41.4036,
                longitude: 2.1744,
                tag: 'Ticket',
              ),
              TripStop(
                time: '14:00',
                title: 'Gracia lunch loop',
                place: 'Vila de Gracia',
                note: 'Shops and lunch in one walkable area.',
                latitude: 41.4031,
                longitude: 2.1578,
                tag: 'Food',
              ),
              TripStop(
                time: '18:00',
                title: 'Casa Mila exterior',
                place: 'La Pedrera',
                note: 'Optional entry if energy is high.',
                latitude: 41.3954,
                longitude: 2.1619,
                tag: 'Flex',
              ),
            ],
          ),
          TripDay(
            label: 'Day 3',
            title: 'Old city and food',
            guidance:
                'Cluster the Gothic Quarter and El Born to avoid backtracking.',
            stops: [
              TripStop(
                time: '10:00',
                title: 'Gothic Quarter route',
                place: 'Barri Gotic',
                note: 'A compact walk with museum swaps nearby.',
                latitude: 41.3839,
                longitude: 2.1763,
                tag: 'Walk',
              ),
              TripStop(
                time: '13:30',
                title: 'Santa Caterina lunch',
                place: 'Santa Caterina Market',
                note: 'Food stop without a long tasting menu commitment.',
                latitude: 41.3866,
                longitude: 2.1789,
                tag: 'Food',
              ),
            ],
          ),
        ],
      ),
      TripPlan(
        id: 'seed-japan',
        title: 'Tokyo and Kyoto first pass',
        destinations: const ['Tokyo', 'Kyoto'],
        dateRange: 'September 2 - September 11',
        summary:
            'A two-city plan that keeps Tokyo dense and Kyoto slower. Transfers are treated as plan anchors, not afterthoughts.',
        pace: 'Balanced',
        updatedAt: DateTime(2026, 4, 15, 15),
        openQuestions: const [
          'Confirm rail pass preference before locking the intercity transfer.',
          'Choose whether Kyoto should prioritize temples, food, or craft shops.',
        ],
        agentEvents: baseEvents,
        days: const [
          TripDay(
            label: 'Day 1',
            title: 'Tokyo arrival',
            guidance: 'One neighborhood and an easy dinner near the hotel.',
            stops: [
              TripStop(
                time: '16:00',
                title: 'Hotel arrival',
                place: 'Shinjuku',
                note: 'Keep the first block open for transit and recovery.',
                latitude: 35.6938,
                longitude: 139.7034,
                tag: 'Arrival',
              ),
              TripStop(
                time: '19:00',
                title: 'Dinner nearby',
                place: 'Omoide Yokocho',
                note: 'Short walk, no cross-city transit.',
                latitude: 35.6939,
                longitude: 139.7005,
                tag: 'Food',
              ),
            ],
          ),
          TripDay(
            label: 'Day 2',
            title: 'Tokyo contrast',
            guidance: 'Start calm, then move into a busier evening zone.',
            stops: [
              TripStop(
                time: '10:00',
                title: 'Meiji Shrine',
                place: 'Harajuku',
                note: 'Calm first anchor before shops open.',
                latitude: 35.6764,
                longitude: 139.6993,
                tag: 'Culture',
              ),
              TripStop(
                time: '15:00',
                title: 'Daikanyama shops',
                place: 'Daikanyama',
                note: 'Design shops and cafes with flexible timing.',
                latitude: 35.6480,
                longitude: 139.7036,
                tag: 'Shops',
              ),
            ],
          ),
        ],
      ),
    ];
  }
}
