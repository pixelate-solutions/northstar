import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip_plan.dart';

// typeId 1: TripPlan stored as JSON string — version-safe and avoids
// manual field adapters that break on model changes.
class TripPlanAdapter extends TypeAdapter<TripPlan> {
  @override
  final int typeId = 1;

  @override
  TripPlan read(BinaryReader reader) {
    final jsonStr = reader.readString();
    return TripPlan.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
  }

  @override
  void write(BinaryWriter writer, TripPlan obj) {
    writer.writeString(json.encode(obj.toJson()));
  }
}

Future<void> registerHiveAdapters() async {
  Hive.registerAdapter(TripPlanAdapter());
}
