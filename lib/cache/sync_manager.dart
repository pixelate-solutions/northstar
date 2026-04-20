import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/trip_repository.dart';
import '../models/trip_plan.dart';
import 'trip_cache.dart';

const _queueBox = 'pending_edits';

class _PendingEdit {
  _PendingEdit({required this.id, required this.tripId, required this.instruction});
  final String id;
  final String tripId;
  final String instruction;

  Map<String, dynamic> toJson() => {'id': id, 'tripId': tripId, 'instruction': instruction};
  factory _PendingEdit.fromJson(Map<String, dynamic> j) => _PendingEdit(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        instruction: j['instruction'] as String,
      );
}

// Called by the provider layer to actually run the agent edit.
typedef EditReplayer = Future<TripPlan> Function(TripPlan plan, String instruction);

class SyncManager {
  SyncManager(this._tripRepo, {EditReplayer? onFlushEdit}) : _onFlushEdit = onFlushEdit;

  final TripRepository _tripRepo;
  final EditReplayer? _onFlushEdit;
  Box<String>? _queue;

  Future<void> init() async {
    _queue = await Hive.openBox<String>(_queueBox);
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  // Load trips: Hive first (instant render), then merge from Supabase when online.
  Future<List<TripPlan>> loadTrips() async {
    final cached = TripCache.getAll();

    _refreshFromRemote(); // fire-and-forget
    return cached.isNotEmpty ? cached : [];
  }

  Future<void> _refreshFromRemote() async {
    try {
      final remote = await _tripRepo.fetchAll();
      // Server wins on conflict — merge by updatedAt.
      final merged = _mergeWithCache(remote);
      await TripCache.putAll(merged);
    } catch (_) {
      // Offline or auth error — cache is still fresh enough.
    }
  }

  List<TripPlan> _mergeWithCache(List<TripPlan> remote) {
    final byId = {for (final p in TripCache.getAll()) p.id: p};
    for (final r in remote) {
      final local = byId[r.id];
      if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
        byId[r.id] = r;
      }
    }
    return byId.values.toList();
  }

  // Queue an edit instruction for replay when back online.
  Future<void> enqueueEdit(String tripId, String instruction) async {
    final edit = _PendingEdit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tripId: tripId,
      instruction: instruction,
    );
    await _queue!.put(edit.id, json.encode(edit.toJson()));
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) await _flushQueue();
  }

  Future<void> _flushQueue() async {
    if (_queue == null || _queue!.isEmpty) return;

    final edits = _queue!.keys
        .map((k) => _PendingEdit.fromJson(
              json.decode(_queue!.get(k as String)!) as Map<String, dynamic>,
            ))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (_onFlushEdit == null) return; // no replayer wired — skip

    for (final edit in edits) {
      try {
        final plan = TripCache.get(edit.tripId);
        if (plan == null) {
          await _queue!.delete(edit.id);
          continue;
        }
        final updated = await _onFlushEdit(plan, edit.instruction);
        await TripCache.put(updated);
        await _queue!.delete(edit.id);
      } catch (_) {
        // Leave in queue and retry next reconnect.
        break;
      }
    }
  }
}
