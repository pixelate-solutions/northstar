import { FastifyInstance } from 'fastify';

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get('/health', async (_req, reply) => {
    reply.send({ status: 'ok', ts: new Date().toISOString() });
  });
}
