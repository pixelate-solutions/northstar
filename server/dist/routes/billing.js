"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.billingRoutes = billingRoutes;
const supabase_1 = require("../db/supabase");
const lifetimePromoCode = process.env.NORTHSTAR_LIFETIME_PROMO_CODE ?? 'z7Wp2N5Q';
async function requireUserId(authHeader) {
    if (!authHeader?.startsWith('Bearer '))
        return null;
    try {
        return await (0, supabase_1.verifyJwt)(authHeader.slice(7));
    }
    catch {
        return null;
    }
}
async function billingRoutes(app) {
    app.get('/v1/billing/subscription', async (req, reply) => {
        const userId = await requireUserId(req.headers.authorization);
        if (userId == null) {
            return reply.status(401).send({ error: 'Invalid token' });
        }
        try {
            return reply.send(await (0, supabase_1.getSubscriptionState)(userId));
        }
        catch (err) {
            return reply.status(500).send({ error: err.message });
        }
    });
    app.post('/v1/billing/redeem-promo', async (req, reply) => {
        const userId = await requireUserId(req.headers.authorization);
        if (userId == null) {
            return reply.status(401).send({ error: 'Invalid token' });
        }
        const body = req.body ?? {};
        if ((body.code ?? '').trim() != lifetimePromoCode) {
            return reply.status(400).send({ error: 'Invalid promo code.' });
        }
        try {
            return reply.send(await (0, supabase_1.redeemLifetimePromoCode)(userId));
        }
        catch (err) {
            return reply.status(500).send({ error: err.message });
        }
    });
    app.post('/v1/billing/activate', async (req, reply) => {
        const userId = await requireUserId(req.headers.authorization);
        if (userId == null) {
            return reply.status(401).send({ error: 'Invalid token' });
        }
        const body = req.body ?? {};
        const billingPeriod = body.billingPeriod;
        const productId = body.productId?.trim();
        if ((billingPeriod != 'monthly' && billingPeriod != 'annual') ||
            productId == null ||
            productId.length === 0) {
            return reply.status(400).send({ error: 'billingPeriod and productId are required.' });
        }
        try {
            return reply.send(await (0, supabase_1.syncSubscriptionPurchase)({
                userId,
                billingPeriod,
                productId,
                purchaseId: body.purchaseId?.trim(),
                purchaseToken: body.purchaseToken?.trim(),
                rawVerificationData: body.rawVerificationData,
                store: body.store?.trim(),
            }));
        }
        catch (err) {
            return reply.status(500).send({ error: err.message });
        }
    });
}
