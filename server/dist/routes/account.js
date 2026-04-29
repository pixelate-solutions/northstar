"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.accountRoutes = accountRoutes;
const supabase_1 = require("../db/supabase");
const tokenLimitOverridePassword = process.env.AI_TOKEN_LIMIT_OVERRIDE_PASSWORD ?? '123OFF';
async function requireUserId(req, reply) {
    const authHeader = req.headers.authorization;
    if (typeof authHeader !== 'string' || !authHeader.startsWith('Bearer ')) {
        reply.status(401).send({ error: 'Missing authorization header' });
        return null;
    }
    try {
        return await (0, supabase_1.verifyJwt)(authHeader.slice(7));
    }
    catch {
        reply.status(401).send({ error: 'Invalid token' });
        return null;
    }
}
async function accountRoutes(app) {
    app.get('/v1/usage', async (req, reply) => {
        const userId = await requireUserId(req, reply);
        if (!userId)
            return;
        try {
            const usage = await (0, supabase_1.getDailyUsage)(userId);
            return reply.send(usage);
        }
        catch (err) {
            return reply.status(500).send({ error: err.message });
        }
    });
    app.patch('/v1/usage-limit', async (req, reply) => {
        const userId = await requireUserId(req, reply);
        if (!userId)
            return;
        const body = (req.body ?? {});
        const disabled = body.disabled === true;
        const password = typeof body.password === 'string' ? body.password : '';
        if (disabled && password !== tokenLimitOverridePassword) {
            return reply.status(403).send({ error: 'Incorrect password.' });
        }
        try {
            const usage = await (0, supabase_1.setAiTokenLimitDisabled)(userId, disabled);
            return reply.send(usage);
        }
        catch (err) {
            return reply.status(500).send({ error: err.message });
        }
    });
    app.delete('/v1/account', async (req, reply) => {
        const userId = await requireUserId(req, reply);
        if (!userId)
            return;
        const { error } = await supabase_1.supabase.auth.admin.deleteUser(userId);
        if (error)
            return reply.status(500).send({ error: error.message });
        return reply.send({ ok: true });
    });
}
