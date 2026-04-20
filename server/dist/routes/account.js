"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.accountRoutes = accountRoutes;
const supabase_1 = require("../db/supabase");
async function accountRoutes(app) {
    app.get('/v1/usage', async (req, reply) => {
        const authHeader = req.headers.authorization;
        if (!authHeader?.startsWith('Bearer ')) {
            return reply.status(401).send({ error: 'Missing authorization header' });
        }
        let userId;
        try {
            userId = await (0, supabase_1.verifyJwt)(authHeader.slice(7));
        }
        catch {
            return reply.status(401).send({ error: 'Invalid token' });
        }
        try {
            const usage = await (0, supabase_1.getDailyUsage)(userId);
            return reply.send(usage);
        }
        catch (err) {
            return reply.status(500).send({ error: err.message });
        }
    });
    app.delete('/v1/account', async (req, reply) => {
        const authHeader = req.headers.authorization;
        if (!authHeader?.startsWith('Bearer ')) {
            return reply.status(401).send({ error: 'Missing authorization header' });
        }
        let userId;
        try {
            userId = await (0, supabase_1.verifyJwt)(authHeader.slice(7));
        }
        catch {
            return reply.status(401).send({ error: 'Invalid token' });
        }
        const { error } = await supabase_1.supabase.auth.admin.deleteUser(userId);
        if (error)
            return reply.status(500).send({ error: error.message });
        return reply.send({ ok: true });
    });
}
