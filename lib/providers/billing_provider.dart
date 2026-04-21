import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/billing_repository.dart';
import '../models/subscription_status.dart';
import 'auth_provider.dart';

const monthlySubscriptionProductId = String.fromEnvironment(
  'MONTHLY_SUBSCRIPTION_PRODUCT_ID',
  defaultValue: 'northstar_monthly',
);
const annualSubscriptionProductId = String.fromEnvironment(
  'ANNUAL_SUBSCRIPTION_PRODUCT_ID',
  defaultValue: 'northstar_annual',
);

final billingRepositoryProvider = Provider<BillingRepository>(
  (_) => BillingRepository(),
);

final billingControllerProvider =
    ChangeNotifierProvider.autoDispose<BillingController>((ref) {
      final controller = BillingController(
        repository: ref.read(billingRepositoryProvider),
      );
      ref.listen(currentUserProvider, (previous, next) {
        final previousId = previous?.id;
        final nextId = next?.id;
        if (previousId == nextId) return;
        if (nextId == null) {
          controller.clearSession();
          return;
        }
        unawaited(controller.reinitialize());
      });
      return controller;
    });

final subscriptionStatusProvider = Provider<SubscriptionStatus?>((ref) {
  return ref.watch(
    billingControllerProvider.select((controller) => controller.membership),
  );
});

final hasActiveSubscriptionProvider = Provider<bool>((ref) {
  return ref.watch(
        billingControllerProvider.select(
          (controller) => controller.membership?.isEntitled,
        ),
      ) ??
      false;
});

class BillingController extends ChangeNotifier {
  BillingController({
    required BillingRepository repository,
    InAppPurchase? inAppPurchase,
  }) : _repository = repository,
       _inAppPurchase = inAppPurchase ?? InAppPurchase.instance {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        _purchasePending = false;
        _lastError = error.toString();
        notifyListeners();
      },
    );
    unawaited(_bootstrap());
  }

  final BillingRepository _repository;
  final InAppPurchase _inAppPurchase;
  final Set<String> _processedPurchases = <String>{};

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  SubscriptionStatus? membership;
  Map<BillingPeriod, ProductDetails> _products = const {};
  bool _loadingMembership = true;
  bool _loadingProducts = true;
  bool _storeAvailable = false;
  bool _purchasePending = false;
  bool _restoringPurchases = false;
  bool _redeemingPromo = false;
  String? _lastError;
  String? _lastMessage;

  Map<BillingPeriod, ProductDetails> get products => _products;
  bool get isLoadingMembership => _loadingMembership;
  bool get isLoadingProducts => _loadingProducts;
  bool get isReady => !_loadingMembership;
  bool get storeAvailable => _storeAvailable;
  bool get purchasePending => _purchasePending;
  bool get restoringPurchases => _restoringPurchases;
  bool get redeemingPromo => _redeemingPromo;
  String? get lastError => _lastError;
  String? get lastMessage => _lastMessage;

  ProductDetails? productFor(BillingPeriod plan) => _products[plan];

  Future<void> _bootstrap() async {
    await refreshMembership();
    await refreshProducts();
  }

  Future<void> reinitialize() async {
    _processedPurchases.clear();
    _lastError = null;
    _lastMessage = null;
    await refreshMembership();
    await refreshProducts();
  }

  void clearSession() {
    membership = null;
    _purchasePending = false;
    _restoringPurchases = false;
    _redeemingPromo = false;
    _lastError = null;
    _lastMessage = null;
    notifyListeners();
  }

  Future<void> refreshMembership() async {
    _loadingMembership = true;
    notifyListeners();
    try {
      membership = await _repository.fetchSubscription();
      _lastError = null;
    } catch (error) {
      membership ??= SubscriptionStatus.inactive();
      _lastError = error.toString();
    } finally {
      _loadingMembership = false;
      notifyListeners();
    }
  }

  Future<void> refreshProducts() async {
    _loadingProducts = true;
    notifyListeners();
    try {
      _storeAvailable = await _inAppPurchase.isAvailable();
      if (!_storeAvailable) {
        _products = const {};
        _lastError ??= 'In-app purchases are not available on this device.';
        return;
      }

      final response = await _inAppPurchase.queryProductDetails(_productIds);
      final mapped = <BillingPeriod, ProductDetails>{};
      for (final product in response.productDetails) {
        final plan = _planForProduct(product.id);
        if (plan != null) mapped[plan] = product;
      }
      _products = mapped;
      if (response.error != null) {
        _lastError = _describeStoreError(response.error!.message);
      } else if (response.notFoundIDs.isNotEmpty && mapped.isEmpty) {
        _lastError =
            'No subscription products were found for ${response.notFoundIDs.join(', ')}. '
            'Configure these products in App Store Connect / Play Console or attach a local StoreKit configuration for testing.';
      }
    } catch (error) {
      _lastError = _describeStoreError(error.toString());
      _products = const {};
    } finally {
      _loadingProducts = false;
      notifyListeners();
    }
  }

  String _describeStoreError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('storekit') &&
        lower.contains('failed to get response from platform')) {
      return 'StoreKit could not load subscription products. '
          'This usually means the app is missing App Store Connect products for '
          '`$monthlySubscriptionProductId` / `$annualSubscriptionProductId`, or no local StoreKit configuration is attached for simulator testing.';
    }
    return message;
  }

  Future<void> purchase(BillingPeriod plan) async {
    final product = _products[plan];
    if (product == null) {
      _lastError = 'This plan is not available yet.';
      notifyListeners();
      return;
    }

    _purchasePending = true;
    _lastError = null;
    _lastMessage = null;
    notifyListeners();

    final started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      _purchasePending = false;
      _lastError = 'Purchase could not be started.';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    _restoringPurchases = true;
    _lastError = null;
    _lastMessage = null;
    notifyListeners();
    try {
      await _inAppPurchase.restorePurchases();
      _lastMessage = 'Checking for previous purchases...';
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _restoringPurchases = false;
      notifyListeners();
    }
  }

  Future<void> redeemPromoCode(String code) async {
    _redeemingPromo = true;
    _lastError = null;
    _lastMessage = null;
    notifyListeners();
    try {
      membership = await _repository.redeemPromoCode(code.trim());
      _lastMessage = 'Promo code applied. Lifetime access unlocked.';
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _redeemingPromo = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _purchasePending = true;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _purchasePending = false;
        _lastError = purchase.error?.message ?? 'Purchase failed.';
        notifyListeners();
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final purchaseKey =
            '${purchase.productID}:${purchase.purchaseID ?? purchase.transactionDate ?? ''}';
        if (_processedPurchases.add(purchaseKey)) {
          await _syncPurchase(purchase);
        }
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _syncPurchase(PurchaseDetails purchase) async {
    final plan = _planForProduct(purchase.productID);
    if (plan == null || plan == BillingPeriod.lifetime) return;

    try {
      membership = await _repository.activateSubscription(
        billingPeriod: plan,
        productId: purchase.productID,
        purchaseId: purchase.purchaseID,
        purchaseToken: purchase.verificationData.localVerificationData,
        rawVerificationData: purchase.verificationData.serverVerificationData,
        store: purchase.verificationData.source,
      );
      _lastMessage = 'Subscription active.';
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _purchasePending = false;
      notifyListeners();
    }
  }

  BillingPeriod? _planForProduct(String productId) {
    if (productId == monthlySubscriptionProductId) {
      return BillingPeriod.monthly;
    }
    if (productId == annualSubscriptionProductId) {
      return BillingPeriod.annual;
    }
    return null;
  }

  Set<String> get _productIds => <String>{
    monthlySubscriptionProductId,
    annualSubscriptionProductId,
  };

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
