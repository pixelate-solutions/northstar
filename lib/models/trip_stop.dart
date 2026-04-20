import 'package:flutter/material.dart';
import '../core/theme/tag_colors.dart';

class TripStop {
  const TripStop({
    required this.time,
    required this.title,
    required this.place,
    required this.note,
    required this.latitude,
    required this.longitude,
    required this.tag,
    this.estimatedCost,
    this.costCategory,
  });

  final String time;
  final String title;
  final String place;
  final String note;
  final double latitude;
  final double longitude;
  final String tag;
  final double? estimatedCost;
  final String? costCategory;

  // Derived from tag — not stored in JSON
  IconData get icon => tagIcon(tag);

  TripStop copyWith({
    String? time,
    String? title,
    String? place,
    String? note,
    double? latitude,
    double? longitude,
    String? tag,
    double? estimatedCost,
    String? costCategory,
  }) {
    return TripStop(
      time: time ?? this.time,
      title: title ?? this.title,
      place: place ?? this.place,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tag: tag ?? this.tag,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      costCategory: costCategory ?? this.costCategory,
    );
  }

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      time: json['time'] as String? ?? '',
      title: json['title'] as String? ?? '',
      place: json['place'] as String? ?? '',
      note: json['note'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      tag: json['tag'] as String? ?? 'Flex',
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      costCategory: json['cost_category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'title': title,
        'place': place,
        'note': note,
        'latitude': latitude,
        'longitude': longitude,
        'tag': tag,
        if (estimatedCost != null) 'estimated_cost': estimatedCost,
        if (costCategory != null) 'cost_category': costCategory,
      };
}
