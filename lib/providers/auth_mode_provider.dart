import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clerk_config.dart';

final useClerkAuthProvider = Provider<bool>((ref) {
  return useClerkAuth;
});
