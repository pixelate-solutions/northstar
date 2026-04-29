import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/usage_repository.dart';

final usageRepositoryProvider = Provider<UsageRepository>(
  (_) => UsageRepository(),
);

final usageLimitProvider = FutureProvider.autoDispose<UsageLimit>((ref) {
  return ref.read(usageRepositoryProvider).fetchUsage();
});

final tokenLimitControllerProvider =
    AsyncNotifierProvider<TokenLimitController, void>(TokenLimitController.new);

class TokenLimitController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setDisabled({required bool disabled, String? password}) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(usageRepositoryProvider)
          .setTokenLimitDisabled(disabled: disabled, password: password);
      ref.invalidate(usageLimitProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
