import { FastifyInstance } from 'fastify';
import { getDailyUsage, supabase, verifyJwt } from '../db/supabase';

export async function accountRoutes(app: FastifyInstance): Promise<void> {
  app.get('/v1/usage', async (req, reply) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return reply.status(401).send({ error: 'Missing authorization header' });
    }

    let userId: string;
    try {
      userId = await verifyJwt(authHeader.slice(7));
    } catch {
      return reply.status(401).send({ error: 'Invalid token' });
    }

    try {
      const usage = await getDailyUsage(userId);
      return reply.send(usage);
    } catch (err) {
      return reply.status(500).send({ error: (err as Error).message });
    }
  });

  app.delete('/v1/account', async (req, reply) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return reply.status(401).send({ error: 'Missing authorization header' });
    }

    let userId: string;
    try {
      userId = await verifyJwt(authHeader.slice(7));
    } catch {
      return reply.status(401).send({ error: 'Invalid token' });
    }

    const { error } = await supabase.auth.admin.deleteUser(userId);
    if (error) return reply.status(500).send({ error: error.message });

    return reply.send({ ok: true });
  });
}
