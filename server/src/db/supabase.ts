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
  resetAt: string;
  usageDate: string;
}

export async function getDailyUsage(userId: string): Promise<DailyUsage> {
  const now = new Date();
  const usageDate = usageDateUtc(now);
  const { data, error } = await supabase
    .from('user_daily_usage')
    .select('tokens_used')
    .eq('user_id', userId)
    .eq('usage_date', usageDate)
    .maybeSingle();

  if (error) throw new Error(error.message);

  return {
    tokensUsed: Number(data?.tokens_used ?? 0),
    tokenLimit: dailyTokenLimit,
    resetAt: resetAtUtc(now),
    usageDate,
  };
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
