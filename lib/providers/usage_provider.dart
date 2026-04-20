import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/usage_repository.dart';

final usageRepositoryProvider = Provider<UsageRepository>(
  (_) => UsageRepository(),
);

final usageLimitProvider = FutureProvider.autoDispose<UsageLimit>((ref) {
  return ref.read(usageRepositoryProvider).fetchUsage();
});
