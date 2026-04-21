import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/models/subscription_status.dart';

void main() {
  test('parses an inactive subscription response', () {
    final status = SubscriptionStatus.fromJson(const {
      'status': 'inactive',
      'isEntitled': false,
      'isLifetime': false,
      'hasRedeemedPromo': false,
    });

    expect(status.status, 'inactive');
    expect(status.isEntitled, isFalse);
    expect(status.billingPeriod, isNull);
  });

  test('parses a lifetime promo subscription response', () {
    final status = SubscriptionStatus.fromJson(const {
      'status': 'lifetime',
      'billingPeriod': 'lifetime',
      'isEntitled': true,
      'isLifetime': true,
      'hasRedeemedPromo': true,
      'trialEndsAt': '2026-04-27T00:00:00.000Z',
    });

    expect(status.status, 'lifetime');
    expect(status.billingPeriod, BillingPeriod.lifetime);
    expect(status.isEntitled, isTrue);
    expect(status.isLifetime, isTrue);
    expect(status.hasRedeemedPromo, isTrue);
    expect(status.trialEndsAt, DateTime.parse('2026-04-27T00:00:00.000Z'));
  });
}
