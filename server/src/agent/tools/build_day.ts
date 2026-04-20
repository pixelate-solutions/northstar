import type { AgentRunContext } from '../state';
import type { ToolResult } from './registry';

export async function buildDay(
  args: Record<string, unknown>,
  ctx: AgentRunContext,
): Promise<ToolResult> {
  const day = {
    day_index: args.day_index as number,
    label: args.label as string,
    title: args.title as string,
    guidance: args.guidance as string,
    stops: args.stops as Array<{
      time: string;
      title: string;
      place: string;
      note: string;
      latitude: number;
      longitude: number;
      tag: string;
    }>,
  };

  const idx = ctx.accumulatedDays.findIndex((d) => d.day_index === day.day_index);
  if (idx >= 0) {
    ctx.accumulatedDays[idx] = day;
  } else {
    ctx.accumulatedDays.push(day);
  }

  return {
    observation: `Day ${day.label} committed with ${day.stops.length} stops.`,
  };
}
