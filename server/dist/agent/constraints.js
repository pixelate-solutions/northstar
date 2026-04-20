"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ConstraintError = exports.DEFAULT_CONSTRAINTS = void 0;
exports.checkConstraints = checkConstraints;
exports.checkToolCallCount = checkToolCallCount;
function envInt(name, fallback) {
    const value = process.env[name];
    if (!value)
        return fallback;
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
exports.DEFAULT_CONSTRAINTS = {
    maxSteps: envInt('AGENT_MAX_STEPS', 30),
    maxTokensTotal: envInt('AGENT_MAX_TOKENS_TOTAL', 80_000),
    timeoutMs: envInt('AGENT_TIMEOUT_MS', 1_200_000),
    maxToolCallsPerStep: envInt('AGENT_MAX_TOOL_CALLS_PER_STEP', 40),
};
class ConstraintError extends Error {
    kind;
    constructor(kind, message) {
        super(message);
        this.kind = kind;
        this.name = 'ConstraintError';
    }
}
exports.ConstraintError = ConstraintError;
function checkConstraints(ctx, config = exports.DEFAULT_CONSTRAINTS) {
    const elapsed = Date.now() - ctx.startedAt.getTime();
    if (elapsed >= config.timeoutMs) {
        throw new ConstraintError('timeout', `Agent run exceeded time limit (${config.timeoutMs / 1000}s).`);
    }
}
function checkToolCallCount(count, config = exports.DEFAULT_CONSTRAINTS) {
    if (count > config.maxToolCallsPerStep) {
        throw new ConstraintError('too_many_tools', `Model requested ${count} tool calls in one step (max ${config.maxToolCallsPerStep}).`);
    }
}
