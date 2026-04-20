import { AgentRunContext } from './state';

export interface ConstraintConfig {
  maxSteps: number;
  maxTokensTotal: number;
  timeoutMs: number;
  maxToolCallsPerStep: number;
}

function envInt(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export const DEFAULT_CONSTRAINTS: ConstraintConfig = {
  maxSteps: envInt('AGENT_MAX_STEPS', 30),
  maxTokensTotal: envInt('AGENT_MAX_TOKENS_TOTAL', 80_000),
  timeoutMs: envInt('AGENT_TIMEOUT_MS', 1_200_000),
  maxToolCallsPerStep: envInt('AGENT_MAX_TOOL_CALLS_PER_STEP', 40),
};

export class ConstraintError extends Error {
  constructor(
    public readonly kind: 'max_steps' | 'max_tokens' | 'timeout' | 'too_many_tools',
    message: string,
  ) {
    super(message);
    this.name = 'ConstraintError';
  }
}

export function checkConstraints(
  ctx: AgentRunContext,
  config: ConstraintConfig = DEFAULT_CONSTRAINTS,
): void {
  const elapsed = Date.now() - ctx.startedAt.getTime();
  if (elapsed >= config.timeoutMs) {
    throw new ConstraintError(
      'timeout',
      `Agent run exceeded time limit (${config.timeoutMs / 1000}s).`,
    );
  }
}

export function checkToolCallCount(
  count: number,
  config: ConstraintConfig = DEFAULT_CONSTRAINTS,
): void {
  if (count > config.maxToolCallsPerStep) {
    throw new ConstraintError(
      'too_many_tools',
      `Model requested ${count} tool calls in one step (max ${config.maxToolCallsPerStep}).`,
    );
  }
}
