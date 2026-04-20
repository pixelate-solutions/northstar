import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/home_preference_repository.dart';
import 'trip_providers.dart';

final homePreferenceRepositoryProvider = Provider<HomePreferenceRepository>(
  (_) => HomePreferenceRepository(),
);

final homeTabProvider = AsyncNotifierProvider<HomeTabNotifier, int>(
  HomeTabNotifier.new,
);

class HomeTabNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final repo = ref.read(homePreferenceRepositoryProvider);
    return repo.getHomeTab();
  }

  Future<void> setTab(int tab) async {
    final repo = ref.read(homePreferenceRepositoryProvider);
    await repo.setHomeTab(tab);
    state = AsyncValue.data(tab);
  }
}

final offlineModeProvider = AsyncNotifierProvider<OfflineModeNotifier, bool>(
  OfflineModeNotifier.new,
);

class OfflineModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repo = ref.read(homePreferenceRepositoryProvider);
    return repo.getOfflineMode();
  }

  /// Persists the offline mode preference. When turning ON, caches the trips
  /// currently in memory and tries a guarded remote refresh if auth/network
  /// allows it. Failures keep the existing cache instead of erroring the UI.
  Future<void> setEnabled(bool enabled) async {
    final repo = ref.read(homePreferenceRepositoryProvider);
    await repo.setOfflineMode(enabled);
    state = AsyncValue.data(enabled);

    if (enabled) {
      await ref.read(tripListProvider.notifier).cacheForOffline();
    }
  }
}
