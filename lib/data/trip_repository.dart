import 'dart:convert';

import '../models/trip_plan.dart';
import 'supabase_client.dart';

class TripRepository {
  static const _table = 'trips';
  static const _sharesTable = 'trip_shares';

  Future<List<TripPlan>> fetchAll() async {
    final rows = await supabase
        .from(_table)
        .select()
        .order('updated_at', ascending: false);

    final tripIds = rows.map((row) => row['id'] as String).toList();
    final sharesByTripId = await _fetchSharesByTripId(tripIds);

    return rows.map((row) {
      final planJson = row['plan_json'] as Map<String, dynamic>? ?? {};
      // Merge top-level row metadata into plan_json so fromJson works
      final merged = {
        ...planJson,
        'id': row['id'],
        'user_id': row['user_id'],
        'updated_at': row['updated_at'],
        'shared_with_emails': sharesByTripId[row['id']] ?? const <String>[],
      };
      return TripPlan.fromJson(merged);
    }).toList();
  }

  Future<TripPlan> upsert(TripPlan plan) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw StateError('Cannot save a trip without an authenticated user.');
    }

    final payload = {
      'id': plan.id.startsWith('seed-') ? null : plan.id,
      'user_id': userId,
      'title': plan.title,
      'destinations': plan.destinations,
      'date_range': plan.dateRange,
      'summary': plan.summary,
      'pace': plan.pace,
      'plan_json': plan.toJson(),
      'status': 'ready',
      'updated_at': DateTime.now().toIso8601String(),
    };

    final rows = await supabase
        .from(_table)
        .upsert(payload, onConflict: 'id')
        .select();

    final row = rows.first;
    final planJson = row['plan_json'] as Map<String, dynamic>? ?? {};
    return TripPlan.fromJson({
      ...planJson,
      'id': row['id'],
      'user_id': row['user_id'],
      'updated_at': row['updated_at'],
    });
  }

  Future<void> delete(String tripId) async {
    await supabase.from(_table).delete().eq('id', tripId);
  }

  Future<List<String>> shareWithEmails(
    String tripId,
    Iterable<String> emails, {
    String role = 'viewer',
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw StateError('Cannot share a trip without an authenticated user.');
    }

    final normalized = normalizeEmails(emails);
    if (normalized.isEmpty) return fetchSharedEmails(tripId);

    await supabase.from(_sharesTable).upsert([
      for (final email in normalized)
        {
          'trip_id': tripId,
          'owner_user_id': userId,
          'recipient_email': email,
          'role': role,
        },
    ], onConflict: 'trip_id,recipient_email');

    return fetchSharedEmails(tripId);
  }

  Future<List<String>> fetchSharedEmails(String tripId) async {
    final rows = await supabase
        .from(_sharesTable)
        .select('recipient_email')
        .eq('trip_id', tripId)
        .order('recipient_email');
    return rows.map((row) => row['recipient_email'] as String).toList();
  }

  Future<Map<String, List<String>>> _fetchSharesByTripId(
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) return const {};
    final rows = await supabase
        .from(_sharesTable)
        .select('trip_id, recipient_email')
        .inFilter('trip_id', tripIds);
    final byTripId = <String, List<String>>{};
    for (final row in rows) {
      final tripId = row['trip_id'] as String;
      final email = row['recipient_email'] as String;
      byTripId.putIfAbsent(tripId, () => []).add(email);
    }
    for (final emails in byTripId.values) {
      emails.sort();
    }
    return byTripId;
  }

  Future<String?> _currentUserId() async {
    final supabaseUserId = supabase.auth.currentUser?.id;
    if (supabaseUserId != null) return supabaseUserId;

    final token = await externalAccessToken();
    if (token == null) return null;
    return _jwtClaim(token, 'sub');
  }

  String? _jwtClaim(String token, String key) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final payload =
          json.decode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      return payload[key]?.toString();
    } catch (_) {
      return null;
    }
  }

  static List<String> normalizeEmails(Iterable<String> emails) {
    return {
      for (final email in emails)
        if (email.trim().isNotEmpty) email.trim().toLowerCase(),
    }.toList();
  }
}
