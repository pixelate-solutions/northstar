import { FastifyInstance } from 'fastify';
import { v4 as uuidv4 } from 'uuid';
import { verifyJwt } from '../db/supabase';
import { runAgentLoop } from '../agent/loop';
import { AgentRunContext, SSEEvent, TripBrief, TripPlan } from '../agent/state';

// In-memory store: runId → finished plan (used by the SSE polling route)
const completedRuns = new Map<string, { plan: TripPlan | null; error?: string }>();
// Active run contexts, so we can stream events as they arrive
const activeStreams = new Map<string, SSEEvent[]>();
const runningRuns = new Map<string, AgentRunContext>();
// Paused contexts waiting for a user's follow-up answer.
const pausedRuns = new Map<string, AgentRunContext>();
const pausedRunTimers = new Map<string, NodeJS.Timeout>();
const pausedRunTtlMs = 30 * 60 * 1000;

function pauseRun(runId: string, ctx: AgentRunContext): void {
  const existing = pausedRunTimers.get(runId);
  if (existing) clearTimeout(existing);
  pausedRuns.set(runId, ctx);
  pausedRunTimers.set(
    runId,
    setTimeout(() => {
      pausedRuns.delete(runId);
      pausedRunTimers.delete(runId);
      activeStreams.delete(runId);
      completedRuns.delete(runId);
    }, pausedRunTtlMs),
  );
}

function unpauseRun(runId: string): void {
  pausedRuns.delete(runId);
  const timer = pausedRunTimers.get(runId);
  if (timer) clearTimeout(timer);
  pausedRunTimers.delete(runId);
}

function cancelRun(runId: string): boolean {
  const ctx = runningRuns.get(runId) ?? pausedRuns.get(runId);
  if (!ctx) return false;
  ctx.cancelled = true;
  ctx.abortController?.abort();
  unpauseRun(runId);
  const events = activeStreams.get(runId);
  if (events) events.push({ kind: 'error', message: 'Agent run cancelled.' });
  completedRuns.set(runId, { plan: null, error: 'Agent run cancelled.' });
  return true;
}

export async function runRoutes(app: FastifyInstance): Promise<void> {
  // POST /v1/runs — start a new agent run (create or edit)
  app.post<{
    Body: {
      mode: 'create' | 'edit';
      brief?: TripBrief;
      plan?: TripPlan;
      instruction?: string;
      useMemory?: boolean;
    };
  }>('/v1/runs', async (req, reply) => {
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

    const { brief, plan, instruction, useMemory } = req.body;
    const mode = req.body.mode ?? (plan || instruction ? 'edit' : 'create');
    if (mode === 'create' && !brief) {
      return reply.status(400).send({ error: 'brief required for create mode' });
    }
    if (mode === 'edit' && (!plan || !instruction)) {
      return reply.status(400).send({ error: 'plan and instruction required for edit mode' });
    }

    const runId = uuidv4();
    activeStreams.set(runId, []);

    const ctx: AgentRunContext = {
      runId,
      userId,
      mode,
      brief,
      plan,
      instruction,
      messages: [],
      accumulatedDays: [],
      stepCount: 0,
      tokenUsage: { prompt: 0, completion: 0 },
      startedAt: new Date(),
      useMemory: useMemory !== false,
      memories: [],
      abortController: new AbortController(),
    };
    runningRuns.set(runId, ctx);

    // Run the loop asynchronously; events are buffered for the SSE stream
    (async () => {
      try {
        const resultPlan = await runAgentLoop(ctx, (event: SSEEvent) => {
          const events = activeStreams.get(runId);
          if (events) events.push(event);
        });
        if (ctx.awaitingUser) {
          pauseRun(runId, ctx);
        }
        completedRuns.set(runId, { plan: resultPlan });
      } catch (err) {
        const events = activeStreams.get(runId);
        if (events) {
          events.push({ kind: 'error', message: (err as Error).message });
        }
        completedRuns.set(runId, { plan: null, error: (err as Error).message });
      } finally {
        runningRuns.delete(runId);
      }
    })();

    reply.send({ runId });
  });

  app.post<{ Params: { id: string } }>('/v1/runs/:id/cancel', async (req, reply) => {
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

    const { id: runId } = req.params;
    const ctx = runningRuns.get(runId) ?? pausedRuns.get(runId);
    if (!ctx) return reply.status(404).send({ error: 'Run not found' });
    if (ctx.userId !== userId) return reply.status(403).send({ error: 'Run belongs to another user' });

    cancelRun(runId);
    return reply.send({ cancelled: true });
  });

  app.post<{
    Params: { id: string };
    Body: { answer: string };
  }>('/v1/runs/:id/answer', async (req, reply) => {
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

    const { id: runId } = req.params;
    const ctx = pausedRuns.get(runId);
    if (!ctx || ctx.userId !== userId) {
      return reply.status(404).send({ error: 'Paused run not found' });
    }

    const answer = req.body.answer?.trim();
    if (!answer) {
      return reply.status(400).send({ error: 'answer required' });
    }

    unpauseRun(runId);
    completedRuns.delete(runId);
    activeStreams.set(runId, []);
    ctx.awaitingUser = false;
    ctx.cancelled = false;
    ctx.abortController = new AbortController();
    ctx.messages.push({
      role: 'user',
      content: `User answered the follow-up question. Continue from the existing research and tool observations; do not restart completed lookups. Answer: ${answer}`,
    });

    (async () => {
      runningRuns.set(runId, ctx);
      try {
        const resultPlan = await runAgentLoop(ctx, (event: SSEEvent) => {
          const events = activeStreams.get(runId);
          if (events) events.push(event);
        });
        if (ctx.awaitingUser) {
          pauseRun(runId, ctx);
        }
        completedRuns.set(runId, { plan: resultPlan });
      } catch (err) {
        const events = activeStreams.get(runId);
        if (events) {
          events.push({ kind: 'error', message: (err as Error).message });
        }
        completedRuns.set(runId, { plan: null, error: (err as Error).message });
      } finally {
        runningRuns.delete(runId);
      }
    })();

    reply.send({ runId });
  });

  // GET /v1/runs/:id/stream — SSE stream of agent events
  app.get<{ Params: { id: string } }>(
    '/v1/runs/:id/stream',
    async (req, reply) => {
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith('Bearer ')) {
        return reply.status(401).send({ error: 'Missing authorization header' });
      }

      try {
        await verifyJwt(authHeader.slice(7));
      } catch {
        return reply.status(401).send({ error: 'Invalid token' });
      }

      const { id: runId } = req.params;

      reply.raw.setHeader('Content-Type', 'text/event-stream');
      reply.raw.setHeader('Cache-Control', 'no-cache');
      reply.raw.setHeader('Connection', 'keep-alive');
      reply.raw.setHeader('X-Accel-Buffering', 'no');
      reply.raw.flushHeaders();

      const send = (event: SSEEvent) => {
        reply.raw.write(`data: ${JSON.stringify(event)}\n\n`);
      };

      let offset = 0;

      const poll = setInterval(() => {
        const events = activeStreams.get(runId);
        if (!events) {
          // Unknown run
          send({ kind: 'error', message: `Run ${runId} not found` });
          clearInterval(poll);
          reply.raw.end();
          return;
        }

        // Drain any new events since last poll
        while (offset < events.length) {
          send(events[offset]);
          offset++;
        }

        // Check if done
        const done = completedRuns.get(runId);
        if (done !== undefined && offset >= events.length) {
          clearInterval(poll);
          // Flush the sentinel
          reply.raw.write('data: [DONE]\n\n');
          reply.raw.end();
          if (pausedRuns.has(runId)) {
            completedRuns.delete(runId);
          } else {
            // Clean up memory after 60s
            setTimeout(() => {
              activeStreams.delete(runId);
              completedRuns.delete(runId);
            }, 60_000);
          }
        }
      }, 150);

      req.raw.on('close', () => clearInterval(poll));
    },
  );
}
