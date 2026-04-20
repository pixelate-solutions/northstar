const clerkPublishableKey = String.fromEnvironment('CLERK_PUBLISHABLE_KEY');

const legacySupabaseAuthEnabled = bool.fromEnvironment('LEGACY_SUPABASE_AUTH');

const useClerkAuth = !legacySupabaseAuthEnabled;

const isClerkConfigured = clerkPublishableKey != '';
