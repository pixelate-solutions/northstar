import 'dart:ui';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/offline_auth_repository.dart';
import '../../models/subscription_status.dart';
import '../../providers/auth_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import 'billing_links.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.onUnlocked});

  final VoidCallback? onUnlocked;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  static const _fallbackMonthlyPrice = '\$11.99';
  static const _fallbackAnnualPrice = '\$69.99';

  final _promoCtrl = TextEditingController();
  late final ProviderSubscription<SubscriptionStatus?> _subscription;
  BillingPeriod _selectedPlan = BillingPeriod.annual;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(subscriptionStatusProvider, (
      previous,
      next,
    ) {
      if (next?.isEntitled != true) return;
      widget.onUnlocked?.call();
      if (!mounted) return;
      final location = GoRouterState.of(context).matchedLocation;
      if (location == '/paywall') context.go('/');
    });
  }

  @override
  void dispose() {
    _subscription.close();
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (ref.read(useClerkAuthProvider)) {
      await ClerkAuth.of(context).signOut();
      await OfflineAuthRepository.clearClerkSessionMarker();
    } else {
      await AuthRepository().signOut();
    }
    if (mounted) context.go('/welcome');
  }

  Future<void> _openBillingManager() async {
    final uri = billingManagementUri();
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _purchaseSelectedPlan(BillingController billing) async {
    await billing.purchase(_selectedPlan);
  }

  Future<void> _showRedeemCodeDialog(BillingController billing) async {
    _promoCtrl.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Redeem code'),
              content: TextField(
                controller: _promoCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Promo code',
                  hintText: 'Enter code',
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: billing.redeemingPromo
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      billing.redeemingPromo || _promoCtrl.text.trim().isEmpty
                      ? null
                      : () async {
                          await billing.redeemPromoCode(_promoCtrl.text);
                          if (!mounted) return;
                          if (billing.lastError == null) {
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                          } else {
                            setDialogState(() {});
                          }
                        },
                  child: Text(
                    billing.redeemingPromo ? 'Checking...' : 'Redeem',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingControllerProvider);
    final user = ref.watch(currentUserProvider);
    final clerkUser = ref.watch(useClerkAuthProvider)
        ? ClerkAuth.of(context).user
        : null;
    final cs = Theme.of(context).colorScheme;
    final membership = billing.membership;
    final email =
        user?.email ??
        clerkUser?.emailAddresses?.firstOrNull?.emailAddress ??
        '';
    final selectedProduct = billing.productFor(_selectedPlan);
    final trialLabel = membership?.trialEndsAt == null
        ? 'Start with a 7-day free trial.'
        : 'Trial recorded through ${_dateLabel(membership!.trialEndsAt!)}.';

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD4EDE6), kMint, Color(0xFFF8FCF9)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: -60,
              top: 80,
              child: _GlowOrb(size: 180, color: Color(0x3314745F)),
            ),
            Positioned(
              right: -80,
              top: 180,
              child: _GlowOrb(size: 210, color: kSky.withValues(alpha: .18)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .72),
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: kInk.withValues(alpha: .12),
                                blurRadius: 32,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _PaywallHero(),
                              const SizedBox(height: 14),
                              Text(
                                'Northstar Pass',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      color: kInk,
                                      fontWeight: FontWeight.w900,
                                      height: .94,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                email.isEmpty
                                    ? 'Choose a plan to keep using the app.'
                                    : 'Continue as $email with a subscription.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: kInk.withValues(alpha: .82),
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                trialLabel,
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(color: kMuted),
                              ),
                              const SizedBox(height: 20),
                              _PlanCard(
                                title: 'Monthly',
                                priceLabel: _priceText(
                                  BillingPeriod.monthly,
                                  billing.productFor(BillingPeriod.monthly),
                                ),
                                body:
                                    '7 days free, then continue month to month.',
                                detail:
                                    'Flexible billing for regular travelers.',
                                selected:
                                    _selectedPlan == BillingPeriod.monthly,
                                enabled:
                                    billing.productFor(BillingPeriod.monthly) !=
                                    null,
                                onPressed: () => setState(
                                  () => _selectedPlan = BillingPeriod.monthly,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _PlanCard(
                                title: 'Annual',
                                badge: 'Best value',
                                priceLabel: _priceText(
                                  BillingPeriod.annual,
                                  billing.productFor(BillingPeriod.annual),
                                ),
                                body:
                                    '7 days free, then stay covered for the year.',
                                detail:
                                    'Lower effective monthly cost for committed use.',
                                selected: _selectedPlan == BillingPeriod.annual,
                                enabled:
                                    billing.productFor(BillingPeriod.annual) !=
                                    null,
                                onPressed: () => setState(
                                  () => _selectedPlan = BillingPeriod.annual,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed:
                                    billing.purchasePending ||
                                        selectedProduct == null
                                    ? null
                                    : () => _purchaseSelectedPlan(billing),
                                style: FilledButton.styleFrom(
                                  backgroundColor: kForest,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      billing.purchasePending
                                          ? 'Opening checkout...'
                                          : 'Try It Free',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _ctaSubtitle(
                                        _selectedPlan,
                                        selectedProduct,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: .84,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: billing.redeemingPromo
                                    ? null
                                    : () => _showRedeemCodeDialog(billing),
                                style: TextButton.styleFrom(
                                  foregroundColor: kForest,
                                ),
                                child: Text(
                                  billing.redeemingPromo
                                      ? 'Checking code...'
                                      : 'Redeem Code',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SecondaryActionPill(
                                    icon: Icons.restore_rounded,
                                    label: billing.restoringPurchases
                                        ? 'Restoring...'
                                        : 'Restore',
                                    onPressed: billing.restoringPurchases
                                        ? null
                                        : billing.restorePurchases,
                                  ),
                                  _SecondaryActionPill(
                                    icon: Icons.open_in_new_rounded,
                                    label: 'Manage billing',
                                    onPressed: _openBillingManager,
                                  ),
                                  _SecondaryActionPill(
                                    icon: Icons.logout_rounded,
                                    label: 'Sign out',
                                    onPressed: _signOut,
                                  ),
                                ],
                              ),
                              if (billing.lastError != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  billing.lastError!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: cs.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (billing.lastMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  billing.lastMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: kForest,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (!billing.storeAvailable &&
                                  !billing.isLoadingProducts) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Store billing is unavailable on this device right now. The promo path still works.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: kMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceText(BillingPeriod plan, ProductDetails? product) {
    final price = product?.price ?? _fallbackPrice(plan);
    return '7 days free, then $price';
  }

  String _ctaSubtitle(BillingPeriod plan, ProductDetails? product) {
    final price = product?.price ?? _fallbackPrice(plan);
    switch (plan) {
      case BillingPeriod.monthly:
        return '7 days free, then $price/month';
      case BillingPeriod.annual:
        return '7 days free, then $price/year';
      case BillingPeriod.lifetime:
        return price;
    }
  }

  String _fallbackPrice(BillingPeriod plan) {
    switch (plan) {
      case BillingPeriod.monthly:
        return _fallbackMonthlyPrice;
      case BillingPeriod.annual:
        return _fallbackAnnualPrice;
      case BillingPeriod.lifetime:
        return _fallbackAnnualPrice;
    }
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final month = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][local.month];
    return '$month ${local.day}';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.body,
    required this.detail,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    this.badge,
  });

  final String title;
  final String priceLabel;
  final String body;
  final String detail;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .78,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: .96)
              : Colors.white.withValues(alpha: .76),
          border: Border.all(
            color: selected ? kForest : kLine,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: kInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE082),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: kInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? kForest : kMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  priceLabel,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: kInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: kMuted, height: 1.35),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: kLine.withValues(alpha: .9)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: kForest,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detail,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: kMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Store product not available yet on this device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaywallHero extends StatelessWidget {
  const _PaywallHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -8,
            right: -8,
            bottom: 14,
            child: _CloudLayer(
              height: 74,
              color: Colors.white.withValues(alpha: .40),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 6,
            child: _CloudLayer(
              height: 68,
              color: Colors.white.withValues(alpha: .56),
            ),
          ),
          Positioned(
            left: 84,
            right: 84,
            top: 0,
            child: _CloudLayer(
              height: 56,
              color: Colors.white.withValues(alpha: .72),
            ),
          ),
          const Center(
            child: Icon(Icons.flight_rounded, size: 42, color: kGold),
          ),
        ],
      ),
    );
  }
}

class _CloudLayer extends StatelessWidget {
  const _CloudLayer({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}

class _SecondaryActionPill extends StatelessWidget {
  const _SecondaryActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: kForest,
        side: BorderSide(color: kLine),
        backgroundColor: Colors.white.withValues(alpha: .7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
