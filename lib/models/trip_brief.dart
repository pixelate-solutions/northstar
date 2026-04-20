class TripBrief {
  const TripBrief({
    this.origin = '',
    this.destinations = '',
    this.dates = '',
    this.travelers = '',
    this.interests = '',
    this.pace = 'Balanced',
    this.budget = '',
    this.notes = '',
  });

  final String origin;
  final String destinations;
  final String dates;
  final String travelers;
  final String interests;
  final String pace;
  final String budget;
  final String notes;

  TripBrief copyWith({
    String? origin,
    String? destinations,
    String? dates,
    String? travelers,
    String? interests,
    String? pace,
    String? budget,
    String? notes,
  }) {
    return TripBrief(
      origin: origin ?? this.origin,
      destinations: destinations ?? this.destinations,
      dates: dates ?? this.dates,
      travelers: travelers ?? this.travelers,
      interests: interests ?? this.interests,
      pace: pace ?? this.pace,
      budget: budget ?? this.budget,
      notes: notes ?? this.notes,
    );
  }

  factory TripBrief.fromJson(Map<String, dynamic> json) {
    return TripBrief(
      origin: json['origin'] as String? ?? '',
      destinations: json['destinations'] as String? ?? '',
      dates: json['dates'] as String? ?? '',
      travelers: json['travelers'] as String? ?? '',
      interests: json['interests'] as String? ?? '',
      pace: json['pace'] as String? ?? 'Balanced',
      budget: json['budget'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'origin': origin,
        'destinations': destinations,
        'dates': dates,
        'travelers': travelers,
        'interests': interests,
        'pace': pace,
        'budget': budget,
        'notes': notes,
      };
}
