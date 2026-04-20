import OpenAI from 'openai';
import { AgentRunContext, TripPlan, SSEEmitter } from './state';
import { TOOL_SCHEMAS, TOOL_HANDLERS } from './tools/registry';
import { checkConstraints, checkToolCallCount, ConstraintError } from './constraints';
import { evaluatePlan, validationIssuesToString } from './evaluator';
import { getDailyUsage, incrementDailyUsage, loadTravelMemories, savePlan, saveTravelMemories, type DailyUsage } from '../db/supabase';
import { v4 as uuidv4 } from 'uuid';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

function formatResetCountdown(resetAt: string): string {
  const ms = Math.max(0, new Date(resetAt).getTime() - Date.now());
  const totalMinutes = Math.ceil(ms / 60_000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours <= 0) return `${minutes}m`;
  if (minutes === 0) return `${hours}h`;
  return `${hours}h ${minutes}m`;
}

function usageLimitMessage(usage: DailyUsage): string {
  return `Usage limit reached. Your daily AI usage resets in ${formatResetCountdown(usage.resetAt)} at ${usage.resetAt}.`;
}

async function checkDailyUsageLimit(ctx: AgentRunContext): Promise<string | null> {
  const usage = await getDailyUsage(ctx.userId);
  if (usage.tokensUsed >= usage.tokenLimit) return usageLimitMessage(usage);
  return null;
}

function memorySection(ctx: AgentRunContext): string {
  if (!ctx.useMemory || ctx.memories.length === 0) return '';

  return `\nKnown user travel preferences from previous trips:
${ctx.memories.map((memory) => `- ${memory}`).join('\n')}

Use these preferences only when they are relevant to the current trip. Do not mention memory unless the user asks.`;
}

const internalTextPattern =
  /\b(adjusted|validated?|validates?|validation|coordinate|coordinates|geocod(?:e|ed|ing)|tool|internal|model|agent)\b/i;

function compactText(value: unknown, maxChars: number): string {
  const text = typeof value === 'string' ? value.replace(/\s+/g, ' ').trim() : '';
  const publicSentences = text
    .split(/(?<=[.!?])\s+/)
    .map((sentence) => sentence.trim())
    .filter((sentence) => sentence.length > 0 && !internalTextPattern.test(sentence));
  const publicText = publicSentences.length > 0 ? publicSentences.join(' ') : text;
  if (publicText.length <= maxChars) return publicText;
  const truncated = publicText.slice(0, maxChars + 1);
  const boundary = truncated.search(/\s+\S*$/);
  return `${truncated.slice(0, boundary > 24 ? boundary : maxChars).trim()}...`;
}

function normalizeStopTime(value: unknown, index: number): string {
  const raw = typeof value === 'string' ? value.trim().toLowerCase() : '';
  const hhmm = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(raw);
  if (hhmm) return `${hhmm[1].padStart(2, '0')}:${hhmm[2]}`;

  const hourMinute = /^(\d{1,2})(?::([0-5]\d))?\s*([ap])\.?m?\.?$/.exec(raw);
  if (hourMinute) {
    let hour = Number(hourMinute[1]);
    const minute = hourMinute[2] ?? '00';
    const period = hourMinute[3];
    if (period === 'p' && hour < 12) hour += 12;
    if (period === 'a' && hour === 12) hour = 0;
    if (hour >= 0 && hour <= 23) return `${String(hour).padStart(2, '0')}:${minute}`;
  }

  if (raw.includes('early') && raw.includes('morning')) return '08:00';
  if (raw.includes('morning')) return '09:00';
  if (raw.includes('lunch')) return '12:30';
  if (raw.includes('late') && raw.includes('afternoon')) return '16:00';
  if (raw.includes('afternoon')) return '13:30';
  if (raw.includes('dinner')) return '19:00';
  if (raw.includes('evening')) return '18:30';
  if (raw.includes('night')) return '20:00';

  const defaults = ['09:00', '12:30', '15:30', '18:30', '20:00'];
  return defaults[Math.min(index, defaults.length - 1)];
}

function normalizeFollowUp(value: unknown): string | null {
  let text = compactText(value, 90).replace(/\?+$/g, '.').trim();
  if (!text) return null;
  const lower = text.toLowerCase();
  if (/^(do|does|did|are|is|was|were|will|would|should|can|could|have|has)\b/.test(lower)) {
    text = `Confirm: ${text.replace(/\.$/, '')}.`;
  } else if (/^(what|where|when|who|which|how)\b/.test(lower)) {
    text = `Provide: ${text.replace(/\.$/, '')}.`;
  }
  if (!/[.!]$/.test(text)) text = `${text}.`;
  return text;
}

function sanitizePlan(plan: TripPlan): TripPlan {
  return {
    ...plan,
    title: compactText(plan.title, 46),
    summary: compactText(plan.summary, 160),
    destinations: plan.destinations.map((destination) => compactText(destination, 28)),
    days: plan.days.map((day) => ({
      ...day,
      title: compactText(day.title, 36),
      guidance: compactText(day.guidance, 110),
      stops: day.stops.map((stop, index) => ({
        ...stop,
        time: normalizeStopTime(stop.time, index),
        title: compactText(stop.title, 34),
        place: compactText(stop.place, 42),
        note: compactText(stop.note, 90),
      })),
    })),
    open_questions: plan.open_questions
      .map(normalizeFollowUp)
      .filter((question): question is string => Boolean(question))
      .slice(0, 4),
  };
}

function buildSystemPrompt(ctx: AgentRunContext): string {
  if (ctx.mode === 'create') {
    const brief = ctx.brief!;
    return `You are Northstar, a world-class travel planning AI. Your job is to create a detailed, realistic trip itinerary.

Trip brief:
- Destinations: ${brief.destinations}
- Dates: ${brief.dates}
- Travelers: ${brief.travelers ?? 'not specified'}
- Interests: ${brief.interests ?? 'not specified'}
- Pace: ${brief.pace ?? 'Balanced'}
- Budget: ${brief.budget ?? 'not specified'}
- Notes: ${brief.notes ?? 'none'}
- Origin: ${brief.origin ?? 'not specified'}
${memorySection(ctx)}

Your process:
1. Call web_search to research the destination(s) — popular attractions, current events, best neighborhoods.
2. Call geocode_place for each planned stop to get accurate coordinates.
3. Optionally call search_places to discover nearby POIs.
4. Optionally call get_weather for the trip dates.
5. Call build_day for each day of the trip. Each day needs 2-5 stops.
6. Call audit_timing to validate each day's feasibility.
7. Call finalize_plan when all days are built and validated.
8. Only call ask_user if destination, dates, or number of travelers are genuinely missing.

Rules:
- All stops MUST be geocoded before calling build_day. Never use (0,0) coordinates.
- Reuse prior web_search, search_places, weather, and geocode observations already in this conversation. After a follow-up answer, do not restart research or repeat lookups unless the answer changes the route or specific stops.
- Prefer fewer, high-confidence mapped stops over repeatedly geocoding many alternate trailheads or duplicate city-center stops.
- Match the pace: Easy = 2-3 stops/day, Balanced = 3-4, Packed = 4-5.
- Stops should be geographically clustered within each day.
- Keep all user-facing text brief: plan title max 6 words, summary max 2 sentences, day title max 5 words, day guidance max 1 sentence, stop title max 5 words, stop note max 1 sentence.
- Every stop time MUST be a concrete 24-hour HH:MM value such as "09:00" or "14:30". Never use words like "morning", "afternoon", "late afternoon", or "evening" in the time field.
- Never include internal implementation notes in the plan. Do not mention validation, coordinates, geocoding, tools, model behavior, or adjustments made to satisfy validators.
- open_questions are clickable follow-up commands, not questions. Write each as a short imperative statement ending with a period, such as "Confirm the hotel neighborhood." Do not use question marks.
- Every stop MUST include estimated_cost (in USD, use 0 for free stops) and cost_category (lodging/food/transport/activities/other).
- When calling finalize_plan, sum all stop costs by category for budget_categories. Set budget_currency to the most appropriate currency for the destination (USD by default).`;
  }

  const plan = ctx.plan!;
  const instr = ctx.instruction!;
  return `You are Northstar, a travel planning AI. The user wants to edit an existing trip plan.

Current plan: "${plan.title}" (${plan.destinations.join(', ')}, ${plan.date_range})
Edit request: "${instr}"
${memorySection(ctx)}

Current days:
${JSON.stringify(plan.days, null, 2)}

Your process:
1. Understand what needs to change.
2. Re-geocode any new stops you introduce.
3. Call build_day to replace only the days that need changes.
4. Call audit_timing to validate modified days.
5. Call finalize_plan with the updated metadata.

Keep unchanged days as-is. Do not regress existing stops unnecessarily.
- Keep all user-facing text brief: plan title max 6 words, summary max 2 sentences, day title max 5 words, day guidance max 1 sentence, stop title max 5 words, stop note max 1 sentence.
- Every stop time MUST be a concrete 24-hour HH:MM value such as "09:00" or "14:30". Never use words like "morning", "afternoon", "late afternoon", or "evening" in the time field.
- Never include internal implementation notes in the plan. Do not mention validation, coordinates, geocoding, tools, model behavior, or adjustments made to satisfy validators.
- open_questions are clickable follow-up commands, not questions. Write each as a short imperative statement ending with a period, such as "Confirm the hotel neighborhood." Do not use question marks.
- Every stop MUST include estimated_cost (in USD, use 0 for free) and cost_category.
- When calling finalize_plan, re-sum all stop costs by category for budget_categories.`;
}

function deriveMemories(ctx: AgentRunContext, plan: TripPlan): string[] {
  const memories: string[] = [];
  const add = (memory: string) => {
    const clean = memory.replace(/\s+/g, ' ').trim();
    if (clean.length >= 8 && clean.length <= 240) memories.push(clean);
  };

  if (ctx.brief) {
    const brief = ctx.brief;
    if (brief.origin?.trim()) add(`Home/origin for travel planning: ${brief.origin.trim()}.`);
    if (brief.travelers?.trim()) add(`Usually plans for this traveler group: ${brief.travelers.trim()}.`);
    if (brief.interests?.trim()) add(`Travel interests mentioned: ${brief.interests.trim()}.`);
    if (brief.budget?.trim()) add(`Budget preference mentioned: ${brief.budget.trim()}.`);
    if (brief.pace?.trim() && brief.pace.trim().toLowerCase() !== 'balanced') {
      add(`Preferred trip pace: ${brief.pace.trim()}.`);
    }
    if (brief.notes?.trim()) add(`Planning preference note: ${brief.notes.trim()}.`);
  }

  if (ctx.instruction?.trim()) {
    add(`Trip edit preference mentioned: ${ctx.instruction.trim()}.`);
  }

  const tagCounts = new Map<string, number>();
  for (const day of plan.days) {
    for (const stop of day.stops) {
      if (!stop.tag) continue;
      tagCounts.set(stop.tag, (tagCounts.get(stop.tag) ?? 0) + 1);
    }
  }
  const topTags = [...tagCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([tag]) => tag.toLowerCase());
  if (topTags.length > 0) add(`Recent itineraries emphasized: ${topTags.join(', ')}.`);

  return [...new Set(memories)];
}

export async function runAgentLoop(ctx: AgentRunContext, emit: SSEEmitter): Promise<TripPlan | null> {
  // For edit mode, seed accumulated days from the existing plan
  if (ctx.mode === 'edit' && ctx.plan && ctx.accumulatedDays.length === 0) {
    ctx.accumulatedDays = [...ctx.plan.days];
  }

  if (ctx.useMemory && ctx.messages.length === 0) {
    try {
      ctx.memories = await loadTravelMemories(ctx.userId);
    } catch (err) {
      console.warn('[memory] Failed to load travel memories:', (err as Error).message);
      ctx.memories = [];
    }
  }

  if (ctx.messages.length === 0) {
    ctx.messages = [
      { role: 'system', content: buildSystemPrompt(ctx) },
    ];
  }

  ctx.awaitingUser = false;

  let correctionAttempts = 0;

  while (true) {
    try {
      checkConstraints(ctx);
    } catch (err) {
      if (err instanceof ConstraintError) {
        emit({ kind: 'constraint_exceeded', message: err.message });
        return null;
      }
      throw err;
    }

    try {
      const usageMessage = await checkDailyUsageLimit(ctx);
      if (usageMessage) {
        emit({ kind: 'error', message: usageMessage });
        return null;
      }
    } catch (err) {
      emit({ kind: 'error', message: `Failed to check usage limit: ${(err as Error).message}` });
      return null;
    }

    emit({ kind: 'model', title: 'Thinking…', detail: `Step ${ctx.stepCount + 1}` });

    // Call the model
    const stream = await openai.chat.completions.create({
      model: 'gpt-5.4-mini',
      messages: ctx.messages,
      tools: TOOL_SCHEMAS,
      tool_choice: 'auto',
      max_completion_tokens: 4096,
      stream: true,
      stream_options: { include_usage: true },
    });

    // Assemble the full response from the stream
    let content = '';
    const toolCallMap: Record<number, { id: string; name: string; args: string }> = {};
    let promptTokens = 0;
    let completionTokens = 0;

    for await (const chunk of stream) {
      if (chunk.usage) {
        promptTokens = chunk.usage.prompt_tokens ?? 0;
        completionTokens = chunk.usage.completion_tokens ?? 0;
      }

      const delta = chunk.choices[0]?.delta;
      if (!delta) continue;

      if (delta.content) content += delta.content;

      for (const tc of delta.tool_calls ?? []) {
        const idx = tc.index ?? 0;
        if (!toolCallMap[idx]) {
          toolCallMap[idx] = { id: tc.id ?? '', name: tc.function?.name ?? '', args: '' };
        }
        if (tc.id) toolCallMap[idx].id = tc.id;
        if (tc.function?.name) toolCallMap[idx].name = tc.function.name;
        if (tc.function?.arguments) toolCallMap[idx].args += tc.function.arguments;
      }

    }

    ctx.tokenUsage.prompt += promptTokens;
    ctx.tokenUsage.completion += completionTokens;
    ctx.stepCount++;

    const stepTokens = promptTokens + completionTokens;
    if (stepTokens > 0) {
      try {
        await incrementDailyUsage(ctx.userId, stepTokens);
      } catch (err) {
        emit({ kind: 'error', message: `Failed to update usage limit: ${(err as Error).message}` });
        return null;
      }
    }

    const toolCalls = Object.values(toolCallMap);

    // Add assistant message to history
    ctx.messages.push({
      role: 'assistant',
      content: content || null,
      tool_calls: toolCalls.length > 0
        ? toolCalls.map((tc) => ({
            id: tc.id,
            type: 'function' as const,
            function: { name: tc.name, arguments: tc.args },
          }))
        : undefined,
    });

    // If the model produced no tool calls, nudge it
    if (toolCalls.length === 0) {
      ctx.messages.push({
        role: 'user',
        content: 'You must call a tool. Call finalize_plan if the itinerary is complete, or ask_user if critical info is missing.',
      });
      continue;
    }

    try {
      checkToolCallCount(toolCalls.length);
    } catch (err) {
      if (err instanceof ConstraintError) {
        emit({ kind: 'constraint_exceeded', message: err.message });
        return null;
      }
    }

    // Execute tool calls sequentially
    for (const tc of toolCalls) {
      emit({ kind: 'tool', title: tc.name, detail: tc.args.slice(0, 120) });

      const handler = TOOL_HANDLERS[tc.name];
      if (!handler) {
        const errMsg = `Unknown tool: ${tc.name}`;
        ctx.messages.push({ role: 'tool', tool_call_id: tc.id, content: errMsg });
        continue;
      }

      let args: Record<string, unknown>;
      try {
        args = JSON.parse(tc.args) as Record<string, unknown>;
      } catch {
        const errMsg = `Invalid JSON args for ${tc.name}`;
        ctx.messages.push({ role: 'tool', tool_call_id: tc.id, content: errMsg });
        continue;
      }

      const result = await handler(args, ctx);
      emit({ kind: 'observation', title: tc.name, detail: result.observation.slice(0, 200) });
      ctx.messages.push({ role: 'tool', tool_call_id: tc.id, content: result.observation });

      // ── ask_user: pause and surface question ──
      if (tc.name === 'ask_user' && result.question) {
        ctx.awaitingUser = true;
        emit({ kind: 'question', question: result.question });
        return null;
      }

      // ── finalize_plan: assemble, validate, save ──
      if (tc.name === 'finalize_plan') {
        const finalArgs = args as {
          title: string; summary: string; destinations: string[];
          date_range: string; pace: string; open_questions: string[];
          budget_currency?: string; budget_categories?: Record<string, number>;
        };

        const sortedDays = [...ctx.accumulatedDays].sort((a, b) => a.day_index - b.day_index);
        const rawPlan: TripPlan = {
          id: ctx.plan?.id ?? uuidv4(),
          title: finalArgs.title,
          summary: finalArgs.summary,
          destinations: finalArgs.destinations,
          date_range: finalArgs.date_range,
          pace: finalArgs.pace,
          days: sortedDays,
          open_questions: finalArgs.open_questions,
          agent_events: ctx.messages
            .filter((m) => m.role === 'assistant')
            .map((m, i) => ({
              kind: 'model',
              title: `Step ${i + 1}`,
              detail: typeof m.content === 'string' ? m.content.slice(0, 100) : '',
            })),
          updated_at: new Date().toISOString(),
          budget_currency: finalArgs.budget_currency ?? 'USD',
          budget_categories: finalArgs.budget_categories,
        };
        const plan = sanitizePlan(rawPlan);

        const issues = evaluatePlan(plan);
        if (issues.length > 0 && correctionAttempts < 2) {
          correctionAttempts++;
          const correction = `Plan validation failed. Fix these issues before finalizing:\n${validationIssuesToString(issues)}`;
          ctx.messages.push({ role: 'user', content: correction });
          emit({ kind: 'observation', title: 'Validation failed', detail: correction.slice(0, 200) });
          break; // re-enter the loop with correction injected
        }

        // Save to Supabase and emit complete
        try {
          await savePlan(ctx.userId, plan);
        } catch (err) {
          emit({ kind: 'error', message: `Failed to save plan: ${(err as Error).message}` });
          return null;
        }

        try {
          await saveTravelMemories(ctx.userId, plan.id, deriveMemories(ctx, plan));
        } catch (err) {
          console.warn('[memory] Failed to save travel memories:', (err as Error).message);
        }

        emit({ kind: 'complete', plan });
        return plan;
      }
    }
  }
}
