import { evaluatePlan, validationIssuesToString } from '../src/agent/evaluator';
import { TripPlan } from '../src/agent/state';

function validPlan(overrides: Partial<TripPlan> = {}): TripPlan {
  return {
    id: 'test',
    title: 'Test Trip',
    summary: 'A great trip.',
    destinations: ['Anywhere'],
    date_range: 'Jan 1–5',
    pace: 'Balanced',
    open_questions: [],
    agent_events: [],
    updated_at: new Date().toISOString(),
    days: [
      {
        day_index: 0,
        label: 'Day 1',
        title: 'Arrival',
        guidance: '',
        stops: [
          { time: '10:00', title: 'A', place: 'A', note: '', latitude: 40.0, longitude: -74.0, tag: 'Walk' },
          { time: '14:00', title: 'B', place: 'B', note: '', latitude: 40.1, longitude: -74.1, tag: 'Food' },
        ],
      },
    ],
    ...overrides,
  };
}

describe('evaluatePlan', () => {
  it('passes a valid plan with no issues', () => {
    expect(evaluatePlan(validPlan())).toHaveLength(0);
  });

  it('flags missing title', () => {
    const issues = evaluatePlan(validPlan({ title: '' }));
    expect(issues.some((i) => i.field === 'title')).toBe(true);
  });

  it('flags missing summary', () => {
    const issues = evaluatePlan(validPlan({ summary: '' }));
    expect(issues.some((i) => i.field === 'summary')).toBe(true);
  });

  it('flags plan with no days', () => {
    const issues = evaluatePlan(validPlan({ days: [] }));
    expect(issues.some((i) => i.field === 'days')).toBe(true);
  });

  it('flags day with no stops', () => {
    const plan = validPlan({
      days: [{ day_index: 0, label: 'Day 1', title: 'Empty', guidance: '', stops: [] }],
    });
    const issues = evaluatePlan(plan);
    expect(issues.some((i) => i.field === 'day_0')).toBe(true);
  });

  it('flags zero-coordinate stop', () => {
    const plan = validPlan({
      days: [
        {
          day_index: 0, label: 'Day 1', title: '', guidance: '',
          stops: [{ time: '10:00', title: 'Null Island', place: 'Null Island', note: '', latitude: 0, longitude: 0, tag: 'Walk' }],
        },
      ],
    });
    const issues = evaluatePlan(plan);
    expect(issues.some((i) => i.message.includes('(0,0)'))).toBe(true);
  });

  it('flags duplicate coordinates within a day', () => {
    const plan = validPlan({
      days: [
        {
          day_index: 0, label: 'Day 1', title: '', guidance: '',
          stops: [
            { time: '10:00', title: 'A', place: 'A', note: '', latitude: 40.0, longitude: -74.0, tag: 'Walk' },
            { time: '12:00', title: 'B', place: 'B', note: '', latitude: 40.0, longitude: -74.0, tag: 'Food' },
          ],
        },
      ],
    });
    const issues = evaluatePlan(plan);
    expect(issues.some((i) => i.message.includes('identical coordinates'))).toBe(true);
  });

  it('validationIssuesToString joins issues with semicolons', () => {
    const str = validationIssuesToString([
      { field: 'title', message: 'Missing.' },
      { field: 'days', message: 'No days.' },
    ]);
    expect(str).toBe('[title] Missing.; [days] No days.');
  });
});
