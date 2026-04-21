import { FastifyInstance } from 'fastify';
import {
  getSubscriptionState,
  redeemLifetimePromoCode,
  syncSubscriptionPurchase,
  verifyJwt,
} from '../db/supabase';

const lifetimePromoCode =
  process.env.NORTHSTAR_LIFETIME_PROMO_CODE ?? 'z7Wp2N5Q';

interface BillingBody {
  code?: string;
  billingPeriod?: 'monthly' | 'annual';
  productId?: string;
  purchaseId?: string;
  purchaseToken?: string;
  rawVerificationData?: string;
  store?: string;
}

async function requireUserId(
  authHeader: string | undefined,
): Promise<string | null> {
  if (!authHeader?.startsWith('Bearer ')) return null;
  try {
    return await verifyJwt(authHeader.slice(7));
  } catch {
    return null;
  }
}

export async function billingRoutes(app: FastifyInstance): Promise<void> {
  app.get('/v1/billing/subscription', async (req, reply) => {
    const userId = await requireUserId(req.headers.authorization);
    if (userId == null) {
      return reply.status(401).send({ error: 'Invalid token' });
    }

    try {
      return reply.send(await getSubscriptionState(userId));
    } catch (err) {
      return reply.status(500).send({ error: (err as Error).message });
    }
  });

  app.post<{ Body: BillingBody }>('/v1/billing/redeem-promo', async (req, reply) => {
    const userId = await requireUserId(req.headers.authorization);
    if (userId == null) {
      return reply.status(401).send({ error: 'Invalid token' });
    }

    const body = req.body ?? {};
    if ((body.code ?? '').trim() != lifetimePromoCode) {
      return reply.status(400).send({ error: 'Invalid promo code.' });
    }

    try {
      return reply.send(await redeemLifetimePromoCode(userId));
    } catch (err) {
      return reply.status(500).send({ error: (err as Error).message });
    }
  });

  app.post<{ Body: BillingBody }>('/v1/billing/activate', async (req, reply) => {
    const userId = await requireUserId(req.headers.authorization);
    if (userId == null) {
      return reply.status(401).send({ error: 'Invalid token' });
    }

    const body = req.body ?? {};
    const billingPeriod = body.billingPeriod;
    const productId = body.productId?.trim();
    if (
      (billingPeriod != 'monthly' && billingPeriod != 'annual') ||
      productId == null ||
      productId.length === 0
    ) {
      return reply.status(400).send({ error: 'billingPeriod and productId are required.' });
    }

    try {
      return reply.send(
        await syncSubscriptionPurchase({
          userId,
          billingPeriod,
          productId,
          purchaseId: body.purchaseId?.trim(),
          purchaseToken: body.purchaseToken?.trim(),
          rawVerificationData: body.rawVerificationData,
          store: body.store?.trim(),
        }),
      );
    } catch (err) {
      return reply.status(500).send({ error: (err as Error).message });
    }
  });
}
