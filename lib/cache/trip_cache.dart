import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip_plan.dart';

const _boxName = 'trips';
const _maxCached = 50;

class TripCache {
  static Box<TripPlan>? _box;

  static Future<void> open() async {
    _box = await Hive.openBox<TripPlan>(_boxName);
  }

  static Box<TripPlan> get _b {
    assert(_box != null && _box!.isOpen, 'TripCache.open() must be called first');
    return _box!;
  }

  static List<TripPlan> getAll() {
    return _b.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static TripPlan? get(String id) => _b.get(id);

  static Future<void> put(TripPlan plan) async {
    await _b.put(plan.id, plan);
    await _evict();
  }

  static Future<void> putAll(List<TripPlan> plans) async {
    await _b.putAll({for (final p in plans) p.id: p});
    await _evict();
  }

  static Future<void> delete(String id) async {
    await _b.delete(id);
  }

  // Keep only the 50 most recently updated plans (LRU by updatedAt).
  static Future<void> _evict() async {
    if (_b.length <= _maxCached) return;
    final sorted = _b.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final toRemove = sorted.take(_b.length - _maxCached).map((p) => p.id);
    await _b.deleteAll(toRemove);
  }
}
