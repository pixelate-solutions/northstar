"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.healthRoutes = healthRoutes;
async function healthRoutes(app) {
    app.get('/health', async (_req, reply) => {
        reply.send({ status: 'ok', ts: new Date().toISOString() });
    });
}
