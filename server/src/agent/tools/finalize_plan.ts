import type { ToolResult } from './registry';

export async function finalizePlan(): Promise<ToolResult> {
  return { observation: 'Finalizing plan...', terminal: true };
}
