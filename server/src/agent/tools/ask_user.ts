import type { ToolResult } from './registry';

export async function askUser(args: Record<string, unknown>): Promise<ToolResult> {
  const question = args.question as string;
  return {
    observation: `Asking user: ${question}`,
    question,
    terminal: true,
  };
}
