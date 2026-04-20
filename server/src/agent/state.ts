import OpenAI from 'openai';

export interface TripStop {
  time: string;
  title: string;
  place: string;
  note: string;
  latitude: number;
  longitude: number;
  tag: string;
  estimated_cost?: number;
  cost_category?: string;
}

export interface TripDay {
  day_index: number;
  label: string;
  title: string;
  guidance: string;
  stops: TripStop[];
}

export interface TripPlan {
  id: string;
  title: string;
  destinations: string[];
  date_range: string;
  summary: string;
  pace: string;
  days: TripDay[];
  open_questions: string[];
  agent_events: Array<{ kind: string; title: string; detail: string }>;
  updated_at: string;
  budget_currency?: string;
  budget_categories?: Record<string, number>;
}

export interface TripBrief {
  origin?: string;
  destinations: string;
  dates: string;
  travelers?: string;
  interests?: string;
  pace?: string;
  budget?: string;
  notes?: string;
}

export interface AgentRunContext {
  runId: string;
  userId: string;
  brief?: TripBrief;
  plan?: TripPlan;         // provided for edit mode
  instruction?: string;    // provided for edit mode
  mode: 'create' | 'edit';
  messages: OpenAI.Chat.ChatCompletionMessageParam[];
  accumulatedDays: TripDay[];
  tokenUsage: { prompt: number; completion: number };
  stepCount: number;
  startedAt: Date;
  useMemory: boolean;
  memories: string[];
  awaitingUser?: boolean;
}

export type SSEEventKind =
  | 'model'
  | 'tool'
  | 'observation'
  | 'question'
  | 'complete'
  | 'error'
  | 'constraint_exceeded';

export interface SSEEvent {
  kind: SSEEventKind;
  title?: string;
  detail?: string;
  question?: string;
  plan?: TripPlan;
  message?: string;
}

export type SSEEmitter = (event: SSEEvent) => void;
