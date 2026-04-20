"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runRoutes = runRoutes;
const uuid_1 = require("uuid");
const supabase_1 = require("../db/supabase");
const loop_1 = require("../agent/loop");
// In-memory store: runId → finished plan (used by the SSE polling route)
const completedRuns = new Map();
// Active run contexts, so we can stream events as they arrive
const activeStreams = new Map();
// Paused contexts waiting for a user's follow-up answer.
const pausedRuns = new Map();
const pausedRunTimers = new Map();
const pausedRunTtlMs = 30 * 60 * 1000;
function pauseRun(runId, ctx) {
    const existing = pausedRunTimers.get(runId);
    if (existing)
        clearTimeout(existing);
    pausedRuns.set(runId, ctx);
    pausedRunTimers.set(runId, setTimeout(() => {
        pausedRuns.delete(runId);
        pausedRunTimers.delete(runId);
        activeStreams.delete(runId);
        completedRuns.delete(runId);
    }, pausedRunTtlMs));
}
function unpauseRun(runId) {
    pausedRuns.delete(runId);
    const timer = pausedRunTimers.get(runId);
    if (timer)
        clearTimeout(timer);
    pausedRunTimers.delete(runId);
}
async function runRoutes(app) {
    // POST /v1/runs — start a new agent run (create or edit)
    app.post('/v1/runs', async (req, reply) => {
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
        const { brief, plan, instruction, useMemory } = req.body;
        const mode = req.body.mode ?? (plan || instruction ? 'edit' : 'create');
        if (mode === 'create' && !brief) {
            return reply.status(400).send({ error: 'brief required for create mode' });
        }
        if (mode === 'edit' && (!plan || !instruction)) {
            return reply.status(400).send({ error: 'plan and instruction required for edit mode' });
        }
        const runId = (0, uuid_1.v4)();
        activeStreams.set(runId, []);
        const ctx = {
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
        };
        // Run the loop asynchronously; events are buffered for the SSE stream
        (async () => {
            try {
                const resultPlan = await (0, loop_1.runAgentLoop)(ctx, (event) => {
                    const events = activeStreams.get(runId);
                    if (events)
                        events.push(event);
                });
                if (ctx.awaitingUser) {
                    pauseRun(runId, ctx);
                }
                completedRuns.set(runId, { plan: resultPlan });
            }
            catch (err) {
                const events = activeStreams.get(runId);
                if (events) {
                    events.push({ kind: 'error', message: err.message });
                }
                completedRuns.set(runId, { plan: null, error: err.message });
            }
        })();
        reply.send({ runId });
    });
    app.post('/v1/runs/:id/answer', async (req, reply) => {
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
        ctx.messages.push({
            role: 'user',
            content: `User answered the follow-up question. Continue from the existing research and tool observations; do not restart completed lookups. Answer: ${answer}`,
        });
        (async () => {
            try {
                const resultPlan = await (0, loop_1.runAgentLoop)(ctx, (event) => {
                    const events = activeStreams.get(runId);
                    if (events)
                        events.push(event);
                });
                if (ctx.awaitingUser) {
                    pauseRun(runId, ctx);
                }
                completedRuns.set(runId, { plan: resultPlan });
            }
            catch (err) {
                const events = activeStreams.get(runId);
                if (events) {
                    events.push({ kind: 'error', message: err.message });
                }
                completedRuns.set(runId, { plan: null, error: err.message });
            }
        })();
        reply.send({ runId });
    });
    // GET /v1/runs/:id/stream — SSE stream of agent events
    app.get('/v1/runs/:id/stream', async (req, reply) => {
        const authHeader = req.headers.authorization;
        if (!authHeader?.startsWith('Bearer ')) {
            return reply.status(401).send({ error: 'Missing authorization header' });
        }
        try {
            await (0, supabase_1.verifyJwt)(authHeader.slice(7));
        }
        catch {
            return reply.status(401).send({ error: 'Invalid token' });
        }
        const { id: runId } = req.params;
        reply.raw.setHeader('Content-Type', 'text/event-stream');
        reply.raw.setHeader('Cache-Control', 'no-cache');
        reply.raw.setHeader('Connection', 'keep-alive');
        reply.raw.setHeader('X-Accel-Buffering', 'no');
        reply.raw.flushHeaders();
        const send = (event) => {
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
                }
                else {
                    // Clean up memory after 60s
                    setTimeout(() => {
                        activeStreams.delete(runId);
                        completedRuns.delete(runId);
                    }, 60_000);
                }
            }
        }, 150);
        req.raw.on('close', () => clearInterval(poll));
    });
}
