jest.mock('openai', () => ({
  __esModule: true,
  default: jest.fn().mockImplementation(() => ({})),
}));

jest.mock('../src/db/supabase', () => ({
  getDailyUsage: jest.fn(),
  incrementDailyUsage: jest.fn(),
  loadTravelMemories: jest.fn(),
  savePlan: jest.fn(),
  saveTravelMemories: jest.fn(),
}));

import { tryApplyFastEdit } from '../src/agent/loop';
import { AgentRunContext, TripPlan } from '../src/agent/state';

function validPlan(overrides: Partial<TripPlan> = {}): TripPlan {
  return {
    id: 'trip-1',
    title: 'Japan Week',
    summary: 'A food and design trip.',
    destinations: ['Tokyo'],
    date_range: 'June 8, 2026 - June 15, 2026',
    pace: 'Balanced',
    open_questions: [],
    agent_events: [],
    updated_at: '2026-04-20T00:00:00.000Z',
    budget_currency: 'USD',
    budget_categories: { food: 200 },
    days: [
      {
        day_index: 0,
        label: 'Day 1',
        title: 'Arrival',
        guidance: 'Settle in.',
        stops: [
          {
            time: '10:00',
            title: 'Coffee',
            place: 'Tokyo Station',
            note: 'Start easy.',
            latitude: 35.6812,
            longitude: 139.7671,
            tag: 'Food',
            estimated_cost: 12,
            cost_category: 'food',
          },
        ],
      },
    ],
    ...overrides,
  };
}

function editContext(instruction: string, plan = validPlan()): AgentRunContext {
  return {
    runId: 'run-1',
    userId: 'user-1',
    mode: 'edit',
    plan,
    instruction,
    messages: [],
    accumulatedDays: [],
    tokenUsage: { prompt: 0, completion: 0 },
    stepCount: 0,
    startedAt: new Date('2026-04-20T00:00:00.000Z'),
    useMemory: false,
    memories: [],
  };
}

describe('tryApplyFastEdit', () => {
  it('updates trip year without rebuilding itinerary content', () => {
    const result = tryApplyFastEdit(editContext('Change the trip date from 2026 to 2028.'));

    expect(result?.date_range).toBe('June 8, 2028 - June 15, 2028');
    expect(result?.days).toEqual(validPlan().days);
    expect(result?.agent_events.at(-1)?.title).toBe('Quick edit');
  });

  it('treats a bare year change as a date edit', () => {
    const plan = validPlan({ date_range: 'June 1-10, 2028' });
    const result = tryApplyFastEdit(editContext('Change this to be in 2027.', plan));

    expect(result?.date_range).toBe('June 1-10, 2027');
    expect(result?.days).toEqual(plan.days);
  });

  it('does not shortcut itinerary edits', () => {
    const result = tryApplyFastEdit(editContext('Add another restaurant stop on day 1.'));

    expect(result).toBeNull();
  });

  it('updates title-only edits', () => {
    const result = tryApplyFastEdit(editContext('Rename the trip to "Tokyo Food Sprint".'));

    expect(result?.title).toBe('Tokyo Food Sprint');
    expect(result?.date_range).toBe(validPlan().date_range);
  });
});
