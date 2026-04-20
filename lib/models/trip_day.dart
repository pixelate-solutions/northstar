import 'trip_stop.dart';

class TripDay {
  const TripDay({
    required this.label,
    required this.title,
    required this.guidance,
    required this.stops,
  });

  final String label;
  final String title;
  final String guidance;
  final List<TripStop> stops;

  TripDay copyWith({
    String? label,
    String? title,
    String? guidance,
    List<TripStop>? stops,
  }) {
    return TripDay(
      label: label ?? this.label,
      title: title ?? this.title,
      guidance: guidance ?? this.guidance,
      stops: stops ?? this.stops,
    );
  }

  factory TripDay.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List<dynamic>? ?? [];
    return TripDay(
      label: json['label'] as String? ?? '',
      title: json['title'] as String? ?? '',
      guidance: json['guidance'] as String? ?? '',
      stops: rawStops
          .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'title': title,
        'guidance': guidance,
        'stops': stops.map((s) => s.toJson()).toList(),
      };
}
