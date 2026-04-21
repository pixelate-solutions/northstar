import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_loading_screen.dart';
import '../../providers/billing_provider.dart';
import 'paywall_screen.dart';

class SubscriptionGate extends ConsumerWidget {
  const SubscriptionGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingControllerProvider);

    if (billing.isLoadingMembership && billing.membership == null) {
      return const AppLoadingScreen(showProgress: true);
    }

    if (billing.membership?.isEntitled == true) return child;
    return const PaywallScreen();
  }
}
