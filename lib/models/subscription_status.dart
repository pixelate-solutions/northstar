enum BillingPeriod { monthly, annual, lifetime }

BillingPeriod? billingPeriodFromWire(String? value) {
  switch (value) {
    case 'monthly':
      return BillingPeriod.monthly;
    case 'annual':
      return BillingPeriod.annual;
    case 'lifetime':
      return BillingPeriod.lifetime;
    default:
      return null;
  }
}

String billingPeriodToWire(BillingPeriod value) {
  switch (value) {
    case BillingPeriod.monthly:
      return 'monthly';
    case BillingPeriod.annual:
      return 'annual';
    case BillingPeriod.lifetime:
      return 'lifetime';
  }
}

extension BillingPeriodCopy on BillingPeriod {
  String get title {
    switch (this) {
      case BillingPeriod.monthly:
        return 'Monthly';
      case BillingPeriod.annual:
        return 'Annual';
      case BillingPeriod.lifetime:
        return 'Lifetime';
    }
  }

  String get blurb {
    switch (this) {
      case BillingPeriod.monthly:
        return '7 days free, then billed monthly.';
      case BillingPeriod.annual:
        return '7 days free, then billed annually.';
      case BillingPeriod.lifetime:
        return 'Unlimited access for life.';
    }
  }
}

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.status,
    required this.isEntitled,
    required this.isLifetime,
    required this.hasRedeemedPromo,
    this.billingPeriod,
    this.source,
    this.store,
    this.productId,
    this.purchaseId,
    this.trialStartedAt,
    this.trialEndsAt,
    this.updatedAt,
  });

  final String status;
  final BillingPeriod? billingPeriod;
  final String? source;
  final String? store;
  final String? productId;
  final String? purchaseId;
  final bool isEntitled;
  final bool isLifetime;
  final bool hasRedeemedPromo;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final DateTime? updatedAt;

  factory SubscriptionStatus.inactive() {
    return const SubscriptionStatus(
      status: 'inactive',
      isEntitled: false,
      isLifetime: false,
      hasRedeemedPromo: false,
    );
  }

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      status: (json['status'] as String? ?? 'inactive').trim(),
      billingPeriod: billingPeriodFromWire(json['billingPeriod'] as String?),
      source: json['source'] as String?,
      store: json['store'] as String?,
      productId: json['productId'] as String?,
      purchaseId: json['purchaseId'] as String?,
      isEntitled: json['isEntitled'] as bool? ?? false,
      isLifetime: json['isLifetime'] as bool? ?? false,
      hasRedeemedPromo: json['hasRedeemedPromo'] as bool? ?? false,
      trialStartedAt: DateTime.tryParse(
        json['trialStartedAt'] as String? ?? '',
      ),
      trialEndsAt: DateTime.tryParse(json['trialEndsAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
