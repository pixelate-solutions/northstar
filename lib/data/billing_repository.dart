import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_status.dart';
import 'supabase_client.dart';

const billingServerUrl = String.fromEnvironment(
  'AGENT_SERVER_URL',
  defaultValue: 'https://northstar-agent.fly.dev',
);
const _localLifetimePromoCode = 'z7Wp2N5Q';
const _localLifetimePromoPrefix = 'northstar_local_lifetime_promo_v1';

class BillingRepository {
  BillingRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<SubscriptionStatus> fetchSubscription() async {
    final localLifetime = await _localLifetimeSubscription();
    try {
      final response = await _authorizedGet('/v1/billing/subscription');
      final remote = SubscriptionStatus.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (localLifetime != null && !remote.isEntitled) return localLifetime;
      return remote;
    } catch (_) {
      if (localLifetime != null) return localLifetime;
      rethrow;
    }
  }

  Future<SubscriptionStatus> redeemPromoCode(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw StateError('Enter a promo code.');
    }

    try {
      final response = await _authorizedPost(
        '/v1/billing/redeem-promo',
        body: {'code': normalized},
      );
      return SubscriptionStatus.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (error) {
      if (normalized == _localLifetimePromoCode) {
        return _persistLocalLifetimeSubscription();
      }
      rethrow;
    }
  }

  Future<SubscriptionStatus> activateSubscription({
    required BillingPeriod billingPeriod,
    required String productId,
    String? purchaseId,
    String? purchaseToken,
    String? rawVerificationData,
    String? store,
  }) async {
    final response = await _authorizedPost(
      '/v1/billing/activate',
      body: {
        'billingPeriod': billingPeriodToWire(billingPeriod),
        'productId': productId,
        'purchaseId': purchaseId,
        'purchaseToken': purchaseToken,
        'rawVerificationData': rawVerificationData,
        'store': store,
      },
    );
    return SubscriptionStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<http.Response> _authorizedGet(String path) async {
    final jwt = await _accessToken();
    if (jwt == null) throw StateError('You must be signed in.');

    final response = await _httpClient.get(
      Uri.parse('$billingServerUrl$path'),
      headers: {'Authorization': 'Bearer $jwt'},
    );
    _throwIfError(response, fallbackMessage: 'Billing request failed.');
    return response;
  }

  Future<http.Response> _authorizedPost(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final jwt = await _accessToken();
    if (jwt == null) throw StateError('You must be signed in.');

    final response = await _httpClient.post(
      Uri.parse('$billingServerUrl$path'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    _throwIfError(response, fallbackMessage: 'Billing request failed.');
    return response;
  }

  void _throwIfError(
    http.Response response, {
    required String fallbackMessage,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    if (response.statusCode == 404) {
      throw StateError(
        'Billing backend is not deployed at $billingServerUrl. '
        'Deploy the server with the /v1/billing routes or point AGENT_SERVER_URL to the updated backend.',
      );
    }

    String message = fallbackMessage;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['error'] as String? ?? message;
    } catch (_) {
      if (response.body.isNotEmpty) message = response.body;
    }
    throw StateError(message);
  }

  Future<String?> _accessToken() async {
    final externalToken = await externalAccessToken();
    if (externalToken != null) return externalToken;
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<SubscriptionStatus?> _localLifetimeSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _localLifetimePromoKey();
    if (key == null || prefs.getBool(key) != true) return null;
    return SubscriptionStatus.fromJson({
      'status': 'lifetime',
      'billingPeriod': 'lifetime',
      'source': 'promo-local',
      'store': 'device',
      'productId': 'northstar_lifetime_promo_local',
      'purchaseId': key,
      'isEntitled': true,
      'isLifetime': true,
      'hasRedeemedPromo': true,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<SubscriptionStatus> _persistLocalLifetimeSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _localLifetimePromoKey();
    if (key == null) {
      throw StateError('You must be signed in to redeem this code.');
    }
    await prefs.setBool(key, true);
    return (await _localLifetimeSubscription())!;
  }

  Future<String?> _localLifetimePromoKey() async {
    final userId = await _currentUserId();
    if (userId == null || userId.isEmpty) return null;
    return '$_localLifetimePromoPrefix:$userId';
  }

  Future<String?> _currentUserId() async {
    final token = await externalAccessToken();
    if (token != null) return _jwtClaim(token, 'sub');

    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String? _jwtClaim(String token, String key) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      return payload[key]?.toString();
    } catch (_) {
      return null;
    }
  }
}
