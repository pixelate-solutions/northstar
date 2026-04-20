import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> Function()? _externalAccessTokenProvider;

// Supabase credentials — set via --dart-define at build time.
// Publishable key is safe to expose; all access is guarded by RLS policies.
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://fukhtizbaoovlmxikmou.supabase.co',
);
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_5K7zdiK0eW8I2wGynyurag_JLZx1eSR',
  ),
);

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabasePublishableKey,
    accessToken: () async => _externalAccessTokenProvider == null
        ? null
        : await _externalAccessTokenProvider!(),
  );
}

void setSupabaseAccessTokenProvider(Future<String?> Function()? provider) {
  _externalAccessTokenProvider = provider;
}

Future<String?> externalAccessToken() async {
  final provider = _externalAccessTokenProvider;
  return provider == null ? null : provider();
}

SupabaseClient get supabase => Supabase.instance.client;
