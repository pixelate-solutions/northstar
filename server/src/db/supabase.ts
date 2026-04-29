import { createClient } from '@supabase/supabase-js';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { TripPlan } from '../agent/state';

const supabaseUrl = process.env.SUPABASE_URL!;
const secretKey = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !secretKey) {
  throw new Error('SUPABASE_URL and SUPABASE_SECRET_KEY must be set');
}

export const supabase = createClient(supabaseUrl, secretKey, {
  auth: { persistSession: false },
});

function envInt(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export const dailyTokenLimit = envInt('AGENT_DAILY_TOKEN_LIMIT', 300_000);

function usageDateUtc(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

function resetAtUtc(now = new Date()): string {
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1),
  ).toISOString();
}

export interface DailyUsage {
  tokensUsed: number;
  tokenLimit: number;
  tokenLimitDisabled: boolean;
  resetAt: string;
  usageDate: string;
}

export type BillingPeriod = 'monthly' | 'annual' | 'lifetime';
type SubscriptionStatus = 'inactive' | 'active' | 'lifetime' | 'canceled';

interface SubscriptionRow {
  user_id: string;
  status: SubscriptionStatus;
  billing_period: BillingPeriod | null;
  source: string | null;
  store: string | null;
  product_id: string | null;
  purchase_id: string | null;
  trial_started_at: string | null;
  trial_ends_at: string | null;
  promo_code_redeemed_at: string | null;
  updated_at: string | null;
}

export interface SubscriptionState {
  status: SubscriptionStatus;
  billingPeriod: BillingPeriod | null;
  source: string | null;
  store: string | null;
  productId: string | null;
  purchaseId: string | null;
  isEntitled: boolean;
  isLifetime: boolean;
  hasRedeemedPromo: boolean;
  trialStartedAt: string | null;
  trialEndsAt: string | null;
  updatedAt: string | null;
}

export async function getDailyUsage(userId: string): Promise<DailyUsage> {
  const now = new Date();
  const usageDate = usageDateUtc(now);
  const [{ data, error }, settings] = await Promise.all([
    supabase
      .from('user_daily_usage')
      .select('tokens_used')
      .eq('user_id', userId)
      .eq('usage_date', usageDate)
      .maybeSingle(),
    getUsageSettings(userId),
  ]);

  if (error) throw new Error(error.message);

  return {
    tokensUsed: Number(data?.tokens_used ?? 0),
    tokenLimit: dailyTokenLimit,
    tokenLimitDisabled: settings.aiTokenLimitDisabled,
    resetAt: resetAtUtc(now),
    usageDate,
  };
}

export interface UsageSettings {
  aiTokenLimitDisabled: boolean;
}

export async function getUsageSettings(userId: string): Promise<UsageSettings> {
  const { data, error } = await supabase
    .from('user_usage_settings')
    .select('ai_token_limit_disabled')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) throw new Error(error.message);

  return {
    aiTokenLimitDisabled: data?.ai_token_limit_disabled === true,
  };
}

export async function setAiTokenLimitDisabled(
  userId: string,
  disabled: boolean,
): Promise<DailyUsage> {
  const { error } = await supabase.from('user_usage_settings').upsert({
    user_id: userId,
    ai_token_limit_disabled: disabled,
    updated_at: new Date().toISOString(),
  });

  if (error) throw new Error(error.message);
  return getDailyUsage(userId);
}

function normalizeSubscription(row: SubscriptionRow | null): SubscriptionState {
  if (!row) {
    return {
      status: 'inactive',
      billingPeriod: null,
      source: null,
      store: null,
      productId: null,
      purchaseId: null,
      isEntitled: false,
      isLifetime: false,
      hasRedeemedPromo: false,
      trialStartedAt: null,
      trialEndsAt: null,
      updatedAt: null,
    };
  }

  return {
    status: row.status,
    billingPeriod: row.billing_period,
    source: row.source,
    store: row.store,
    productId: row.product_id,
    purchaseId: row.purchase_id,
    isEntitled: row.status === 'active' || row.status === 'lifetime',
    isLifetime: row.status === 'lifetime' || row.billing_period == 'lifetime',
    hasRedeemedPromo: row.promo_code_redeemed_at != null,
    trialStartedAt: row.trial_started_at,
    trialEndsAt: row.trial_ends_at,
    updatedAt: row.updated_at,
  };
}

export async function getSubscriptionState(
  userId: string,
): Promise<SubscriptionState> {
  const { data, error } = await supabase
    .from('user_subscriptions')
    .select(
      'user_id, status, billing_period, source, store, product_id, purchase_id, trial_started_at, trial_ends_at, promo_code_redeemed_at, updated_at',
    )
    .eq('user_id', userId)
    .maybeSingle();

  if (error) throw new Error(error.message);
  return normalizeSubscription((data ?? null) as SubscriptionRow | null);
}

interface PurchaseSyncInput {
  userId: string;
  billingPeriod: Exclude<BillingPeriod, 'lifetime'>;
  productId: string;
  purchaseId?: string | null;
  purchaseToken?: string | null;
  rawVerificationData?: string | null;
  store?: string | null;
}

export async function syncSubscriptionPurchase({
  userId,
  billingPeriod,
  productId,
  purchaseId,
  purchaseToken,
  rawVerificationData,
  store,
}: PurchaseSyncInput): Promise<SubscriptionState> {
  const now = new Date();
  const trialEndsAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  const { data: current, error: fetchError } = await supabase
    .from('user_subscriptions')
    .select('status, billing_period, trial_started_at, trial_ends_at, promo_code_redeemed_at')
    .eq('user_id', userId)
    .maybeSingle();

  if (fetchError) throw new Error(fetchError.message);
  if (current?.status === 'lifetime' || current?.billing_period === 'lifetime') {
    return getSubscriptionState(userId);
  }

  const { error } = await supabase.from('user_subscriptions').upsert({
    user_id: userId,
    status: 'active',
    billing_period: billingPeriod,
    source: 'in_app_purchase',
    store,
    product_id: productId,
    purchase_id: purchaseId,
    purchase_token: purchaseToken,
    raw_verification_data: rawVerificationData,
    trial_started_at: current?.trial_started_at ?? now.toISOString(),
    trial_ends_at: current?.trial_ends_at ?? trialEndsAt.toISOString(),
    promo_code_redeemed_at: current?.promo_code_redeemed_at ?? null,
    updated_at: now.toISOString(),
  });

  if (error) throw new Error(error.message);
  return getSubscriptionState(userId);
}

export async function redeemLifetimePromoCode(
  userId: string,
): Promise<SubscriptionState> {
  const now = new Date().toISOString();
  const { error } = await supabase.from('user_subscriptions').upsert({
    user_id: userId,
    status: 'lifetime',
    billing_period: 'lifetime',
    source: 'promo',
    store: 'northstar',
    product_id: 'northstar_lifetime_promo',
    trial_started_at: null,
    trial_ends_at: null,
    promo_code_redeemed_at: now,
    updated_at: now,
  });

  if (error) throw new Error(error.message);
  return getSubscriptionState(userId);
}

export async function incrementDailyUsage(
  userId: string,
  tokenDelta: number,
): Promise<DailyUsage> {
  if (tokenDelta <= 0) return getDailyUsage(userId);

  const now = new Date();
  const usageDate = usageDateUtc(now);
  const { data, error } = await supabase.rpc('increment_user_daily_usage', {
    p_user_id: userId,
    p_usage_date: usageDate,
    p_token_delta: Math.max(0, Math.round(tokenDelta)),
  });

  if (error) throw new Error(error.message);

  return {
    tokensUsed: Number(data ?? 0),
    tokenLimit: dailyTokenLimit,
    tokenLimitDisabled: (await getUsageSettings(userId)).aiTokenLimitDisabled,
    resetAt: resetAtUtc(now),
    usageDate,
  };
}

export async function savePlan(userId: string, plan: TripPlan): Promise<void> {
  const { error } = await supabase.from('trips').upsert({
    id: plan.id,
    user_id: userId,
    title: plan.title,
    summary: plan.summary,
    destinations: plan.destinations,
    date_range: plan.date_range,
    pace: plan.pace,
    plan_json: plan,
    status: 'ready',
    updated_at: plan.updated_at,
    budget_currency: plan.budget_currency,
    budget_categories: plan.budget_categories,
  });

  if (error) throw new Error(error.message);
}

export async function loadTravelMemories(userId: string, limit = 16): Promise<string[]> {
  const { data, error } = await supabase
    .from('travel_memories')
    .select('memory_text')
    .eq('user_id', userId)
    .order('updated_at', { ascending: false })
    .limit(limit);

  if (error) throw new Error(error.message);
  return (data ?? [])
    .map((row) => row.memory_text)
    .filter((memory): memory is string => typeof memory === 'string' && memory.trim().length > 0);
}

export async function saveTravelMemories(
  userId: string,
  planId: string,
  memories: string[],
): Promise<void> {
  const rows = [...new Set(memories.map((memory) => memory.trim()).filter(Boolean))]
    .slice(0, 12)
    .map((memory_text) => ({
      user_id: userId,
      source_plan_id: planId,
      memory_text,
      updated_at: new Date().toISOString(),
    }));

  if (rows.length === 0) return;

  const { error } = await supabase
    .from('travel_memories')
    .upsert(rows, { onConflict: 'user_id,memory_text' });

  if (error) throw new Error(error.message);
}

const clerkJwksUri = process.env.CLERK_JWKS_URL;

export async function verifyJwt(token: string): Promise<string> {
  // Try Supabase JWT first (legacy auth) — wrapped so a throw doesn't block Clerk fallback
  try {
    const { data } = await supabase.auth.getUser(token);
    if (data.user) return data.user.id;
  } catch {
    // Not a Supabase token; fall through to Clerk
  }

  // Fall back to Clerk JWT verification
  if (!clerkJwksUri) throw new Error('Invalid or expired token');
  const jwks = createRemoteJWKSet(new URL(clerkJwksUri));
  try {
    const { payload } = await jwtVerify(token, jwks);
    const sub = payload.sub;
    if (!sub) throw new Error('Invalid token: missing sub');
    return sub;
  } catch (err) {
    console.error('[verifyJwt] Clerk jwtVerify failed:', err);
    console.error('[verifyJwt] CLERK_JWKS_URL:', clerkJwksUri);
    // Log first 50 chars of token header to help debug (safe — not the signature)
    try {
      const header = JSON.parse(Buffer.from(token.split('.')[0], 'base64url').toString());
      console.error('[verifyJwt] Token header:', JSON.stringify(header));
      const claims = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString());
      console.error('[verifyJwt] Token iss:', claims.iss, '| exp:', new Date((claims.exp ?? 0) * 1000).toISOString());
    } catch {}
    throw err;
  }
}
