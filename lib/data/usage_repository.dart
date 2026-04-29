import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

const _usageServerUrl = String.fromEnvironment(
  'AGENT_SERVER_URL',
  defaultValue: 'https://northstar-agent.fly.dev',
);

class UsageLimit {
  const UsageLimit({
    required this.tokensUsed,
    required this.tokenLimit,
    required this.tokenLimitDisabled,
    required this.resetAt,
    required this.usageDate,
  });

  final int tokensUsed;
  final int tokenLimit;
  final bool tokenLimitDisabled;
  final DateTime resetAt;
  final String usageDate;

  bool get isUnlimited => tokenLimitDisabled;

  int get tokensRemaining => (tokenLimit - tokensUsed).clamp(0, tokenLimit);

  double get usedFraction {
    if (tokenLimitDisabled) return 0;
    if (tokenLimit <= 0) return 0;
    return (tokensUsed / tokenLimit).clamp(0, 1);
  }

  factory UsageLimit.fromJson(Map<String, dynamic> json) {
    return UsageLimit(
      tokensUsed: (json['tokensUsed'] as num?)?.round() ?? 0,
      tokenLimit: (json['tokenLimit'] as num?)?.round() ?? 0,
      tokenLimitDisabled: json['tokenLimitDisabled'] == true,
      resetAt:
          DateTime.tryParse(json['resetAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      usageDate: json['usageDate'] as String? ?? '',
    );
  }
}

class UsageRepository {
  UsageRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<UsageLimit> fetchUsage() async {
    final jwt = await _accessToken();
    if (jwt == null) throw StateError('You must be signed in.');

    final response = await _httpClient.get(
      Uri.parse('$_usageServerUrl/v1/usage'),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Could not load usage limit.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['error'] as String? ?? message;
      } catch (_) {
        if (response.body.isNotEmpty) message = response.body;
      }
      throw StateError(message);
    }

    return UsageLimit.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<UsageLimit> setTokenLimitDisabled({
    required bool disabled,
    String? password,
  }) async {
    final jwt = await _accessToken();
    if (jwt == null) throw StateError('You must be signed in.');

    final body = <String, dynamic>{'disabled': disabled};
    if (password != null) body['password'] = password;

    final response = await _httpClient.patch(
      Uri.parse('$_usageServerUrl/v1/usage-limit'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = disabled
          ? 'Could not turn off token limits.'
          : 'Could not turn token limits back on.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['error'] as String? ?? message;
      } catch (_) {
        if (response.body.isNotEmpty) message = response.body;
      }
      throw StateError(message);
    }

    return UsageLimit.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
}
