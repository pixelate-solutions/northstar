import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cache/sync_manager.dart';
import '../cache/trip_cache.dart';
import '../core/services/notification_service.dart';
import '../data/trip_repository.dart';
import '../models/trip_plan.dart';

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(),
);

final syncManagerProvider = Provider<SyncManager>((ref) {
  final repo = ref.read(tripRepositoryProvider);
  return SyncManager(repo);
});

class TripListNotifier extends AsyncNotifier<List<TripPlan>> {
  @override
  Future<List<TripPlan>> build() async {
    final sync = ref.read(syncManagerProvider);
    await sync.init();

    // Hive first (instant); remote merge fires in background inside loadTrips().
    final cached = await sync.loadTrips();
    if (cached.isNotEmpty) return cached;

    // First launch: no cache yet — fall back to seed data until remote loads.
    return TripPlan.seedPlans();
  }

  Future<void> reload() async {
    final previous = state.valueOrNull ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final plans = await ref.read(tripRepositoryProvider).fetchAll();
        await TripCache.putAll(plans);
        return plans;
      } catch (_) {
        final cached = TripCache.getAll();
        if (cached.isNotEmpty) return cached;
        if (previous.isNotEmpty) return previous;
        return TripPlan.seedPlans();
      }
    });
  }

  Future<void> cacheForOffline() async {
    final current = state.valueOrNull ?? [];
    if (current.isNotEmpty) {
      await TripCache.putAll(current);
    }

    try {
      final plans = await ref.read(tripRepositoryProvider).fetchAll();
      await TripCache.putAll(plans);
      if (plans.isNotEmpty) {
        state = AsyncData(plans);
      }
    } catch (_) {
      final cached = TripCache.getAll();
      if (cached.isNotEmpty) {
        state = AsyncData(cached);
      } else if (current.isNotEmpty) {
        state = AsyncData(current);
      }
    }
  }

  Future<TripPlan> savePlan(TripPlan plan) async {
    final repo = ref.read(tripRepositoryProvider);
    try {
      final saved = await repo.upsert(plan);
      if (plan.id != saved.id) await TripCache.delete(plan.id);
      await TripCache.put(saved);
      _upsertInState(saved, replaceId: plan.id == saved.id ? null : plan.id);
      await scheduleRemindersForPlan(saved);
      return saved;
    } catch (_) {
      // Offline: persist to Hive and optimistically update UI.
      await TripCache.put(plan);
      _upsertInState(plan);
      await scheduleRemindersForPlan(plan);
      return plan;
    }
  }

  Future<TripPlan> sharePlan(
    TripPlan plan,
    Iterable<String> emails, {
    String role = 'viewer',
  }) async {
    final repo = ref.read(tripRepositoryProvider);
    final saved = plan.id.startsWith('seed-') ? await savePlan(plan) : plan;
    final sharedWithEmails = await repo.shareWithEmails(
      saved.id,
      emails,
      role: role,
    );
    final updated = saved.copyWith(sharedWithEmails: sharedWithEmails);
    if (plan.id != updated.id) await TripCache.delete(plan.id);
    await TripCache.put(updated);
    _upsertInState(updated, replaceId: plan.id == updated.id ? null : plan.id);
    return updated;
  }

  Future<void> deletePlan(String tripId) async {
    try {
      await ref.read(tripRepositoryProvider).delete(tripId);
    } catch (_) {
      // Offline — will be re-tried; remove from local state anyway.
    }
    await TripCache.delete(tripId);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((p) => p.id != tripId).toList());
  }

  void _upsertInState(TripPlan plan, {String? replaceId}) {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == plan.id || p.id == replaceId);
    if (idx >= 0) {
      final updated = [...current];
      updated[idx] = plan;
      state = AsyncData(updated);
    } else {
      state = AsyncData([plan, ...current]);
    }
  }
}

final tripListProvider =
    AsyncNotifierProvider<TripListNotifier, List<TripPlan>>(
      TripListNotifier.new,
    );

final selectedTripIndexProvider = StateProvider<int>((ref) => 0);

final selectedTripProvider = Provider<TripPlan?>((ref) {
  final trips = ref.watch(tripListProvider).valueOrNull ?? [];
  final index = ref.watch(selectedTripIndexProvider);
  if (trips.isEmpty || index >= trips.length) return null;
  return trips[index];
});
