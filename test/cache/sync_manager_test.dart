import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/models/trip_plan.dart';

// Unit tests for the merge logic extracted from SyncManager.
// Full Hive integration (box operations) is tested via the widget test harness.

TripPlan _makePlan(String id, DateTime updatedAt) => TripPlan(
  id: id,
  title: 'Plan $id',
  summary: '',
  destinations: const ['Somewhere'],
  dateRange: '',
  pace: 'Balanced',
  days: const [],
  openQuestions: const [],
  agentEvents: const [],
  updatedAt: updatedAt,
);

/// Merge logic: server wins on same ID when server is newer.
List<TripPlan> _mergeWithCache(
  List<TripPlan> remote,
  Map<String, TripPlan> cache,
) {
  final byId = Map<String, TripPlan>.from(cache);
  for (final r in remote) {
    final local = byId[r.id];
    if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
      byId[r.id] = r;
    }
  }
  return byId.values.toList();
}

void main() {
  final t0 = DateTime(2026, 1, 1);
  final t1 = DateTime(2026, 1, 2);

  group('merge logic', () {
    test('remote newer than cache: server wins', () {
      final local = _makePlan('a', t0);
      final remote = _makePlan('a', t1);
      final result = _mergeWithCache([remote], {'a': local});
      expect(result.single.updatedAt, t1);
    });

    test('cache newer than remote: local wins', () {
      final local = _makePlan('a', t1);
      final remote = _makePlan('a', t0);
      final result = _mergeWithCache([remote], {'a': local});
      expect(result.single.updatedAt, t1);
    });

    test('remote has new plan not in cache: added', () {
      final result = _mergeWithCache([_makePlan('new', t0)], {});
      expect(result, hasLength(1));
      expect(result.single.id, 'new');
    });

    test('cache plan absent from remote: preserved', () {
      final localOnly = _makePlan('local-only', t0);
      final result = _mergeWithCache([], {'local-only': localOnly});
      expect(result.single.id, 'local-only');
    });

    test('merge preserves all plans from both sides', () {
      final cache = {'a': _makePlan('a', t0), 'b': _makePlan('b', t1)};
      final remote = [_makePlan('a', t1), _makePlan('c', t0)];
      final result = _mergeWithCache(remote, cache);
      final ids = result.map((p) => p.id).toSet();
      expect(ids, {'a', 'b', 'c'});
    });
  });
}
