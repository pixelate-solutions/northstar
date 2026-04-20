import OpenAI from 'openai';
import { AgentRunContext } from '../state';
import { geocodePlace } from './geocode';
import { getWeather } from './weather';
import { searchPlaces } from './search_places';
import { webSearch } from './web_search';
import { checkOpenHours } from './check_open_hours';
import { buildDay } from './build_day';
import { auditTiming } from './audit_timing';
import { finalizePlan } from './finalize_plan';
import { askUser } from './ask_user';

export type ToolResult = { observation: string; terminal?: boolean; question?: string };
export type ToolHandler = (args: Record<string, unknown>, ctx: AgentRunContext) => Promise<ToolResult>;

// ────────── Tool definitions (OpenAI function_calling format) ──────────

export const TOOL_SCHEMAS: OpenAI.Chat.ChatCompletionTool[] = [
  {
    type: 'function',
    function: {
      name: 'geocode_place',
      description: 'Resolve a place name to latitude/longitude. Call this for every stop before building the itinerary.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: "Place name, e.g. 'Sagrada Familia, Barcelona'" },
          country_code: { type: 'string', description: 'ISO 3166-1 alpha-2 country hint, e.g. "ES"' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'web_search',
      description: 'Search the web for travel information: events, popular attractions, neighborhood guides, seasonal tips, advisories. Call this early to research each destination.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string' },
          topic: {
            type: 'string',
            enum: ['attractions', 'events', 'food', 'neighborhoods', 'transport', 'tips', 'general'],
          },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_places',
      description: 'Search for points of interest near coordinates. Use after geocoding to discover restaurants, museums, nature spots, etc.',
      parameters: {
        type: 'object',
        properties: {
          lat: { type: 'number' },
          lng: { type: 'number' },
          radius_meters: { type: 'integer', default: 2000 },
          category: {
            type: 'string',
            enum: ['attractions', 'cultural', 'restaurants', 'natural', 'architecture', 'shops', 'transport', 'general'],
          },
          limit: { type: 'integer', default: 8 },
        },
        required: ['lat', 'lng', 'category'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_weather',
      description: 'Get daily weather forecast for the trip dates at a given location.',
      parameters: {
        type: 'object',
        properties: {
          lat: { type: 'number' },
          lng: { type: 'number' },
          start_date: { type: 'string', description: 'YYYY-MM-DD' },
          end_date: { type: 'string', description: 'YYYY-MM-DD' },
        },
        required: ['lat', 'lng', 'start_date', 'end_date'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'build_day',
      description: 'Commit a single day to the growing itinerary. Call once per trip day after geocoding all stops.',
      parameters: {
        type: 'object',
        properties: {
          day_index: { type: 'integer' },
          label: { type: 'string', description: "e.g. 'Day 1'" },
          title: { type: 'string', description: 'Short public day title, max 5 words.' },
          guidance: { type: 'string', description: 'One brief public sentence. Do not mention validation, tools, coordinates, or geocoding.' },
          stops: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                time: { type: 'string', description: 'Concrete 24-hour HH:MM time only, e.g. 09:00 or 14:30. Do not use words like morning, afternoon, or evening.' },
                title: { type: 'string', description: 'Short public stop title, max 5 words.' },
                place: { type: 'string' },
                note: { type: 'string', description: 'One brief public sentence. Do not mention validation, tools, coordinates, or geocoding.' },
                latitude: { type: 'number' },
                longitude: { type: 'number' },
                tag: {
                  type: 'string',
                  enum: ['Arrival', 'Food', 'Walk', 'Ticket', 'Culture', 'Nature', 'Shops', 'View', 'Flex'],
                },
                estimated_cost: {
                  type: 'number',
                  description: 'Estimated cost in USD for this stop (entry fees, meal cost, transport, etc). Use 0 for free stops.',
                },
                cost_category: {
                  type: 'string',
                  enum: ['lodging', 'food', 'transport', 'activities', 'other'],
                  description: 'Budget category this cost belongs to.',
                },
              },
              required: ['time', 'title', 'place', 'note', 'latitude', 'longitude', 'tag', 'estimated_cost', 'cost_category'],
            },
          },
        },
        required: ['day_index', 'label', 'title', 'guidance', 'stops'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'audit_timing',
      description: 'Validate travel-time feasibility between consecutive stops in a day. Returns issues or empty list if valid.',
      parameters: {
        type: 'object',
        properties: {
          day_index: { type: 'integer' },
          transport_mode: { type: 'string', enum: ['walking', 'transit', 'taxi'], default: 'transit' },
        },
        required: ['day_index'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'check_open_hours',
      description: 'Look up opening hours for a specific place via OSM.',
      parameters: {
        type: 'object',
        properties: {
          lat: { type: 'number' },
          lng: { type: 'number' },
          place_name: { type: 'string' },
        },
        required: ['lat', 'lng', 'place_name'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'finalize_plan',
      description: 'Seal the plan. Call only when all days are built, all stops geocoded, timing audited. This ends the agent run.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Short public trip title, max 6 words.' },
          summary: { type: 'string', description: 'Brief public trip summary, max 2 sentences. Do not mention validation, tools, coordinates, or geocoding.' },
          destinations: { type: 'array', items: { type: 'string' } },
          date_range: { type: 'string' },
          pace: { type: 'string', enum: ['Easy', 'Balanced', 'Packed'] },
          open_questions: {
            type: 'array',
            items: {
              type: 'string',
              description: 'Short imperative follow-up command, not a question, e.g. "Confirm the hotel neighborhood."',
            },
            maxItems: 4,
          },
          budget_currency: { type: 'string', description: 'Currency code for all cost estimates, e.g. USD, EUR, GBP.' },
          budget_categories: {
            type: 'object',
            description: 'Aggregated estimated costs by category, summed from all stop estimated_cost values.',
            properties: {
              lodging: { type: 'number' },
              food: { type: 'number' },
              transport: { type: 'number' },
              activities: { type: 'number' },
              other: { type: 'number' },
            },
          },
        },
        required: ['title', 'summary', 'destinations', 'date_range', 'pace', 'open_questions', 'budget_currency', 'budget_categories'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'ask_user',
      description: 'Pause and ask the user for critical missing information. Only call if destination, dates, or number of travelers are genuinely missing and cannot be inferred.',
      parameters: {
        type: 'object',
        properties: {
          question: { type: 'string' },
          reason: { type: 'string' },
        },
        required: ['question', 'reason'],
      },
    },
  },
];

const SURGICAL_EDIT_TOOL_NAMES = new Set([
  'geocode_place',
  'build_day',
  'finalize_plan',
  'ask_user',
]);

export const SURGICAL_EDIT_TOOL_SCHEMAS = TOOL_SCHEMAS.filter((tool) =>
  SURGICAL_EDIT_TOOL_NAMES.has(tool.function.name),
);

// ────────── Tool handlers ──────────

export const TOOL_HANDLERS: Record<string, ToolHandler> = {
  async geocode_place(args) {
    const { observation, result } = await geocodePlace(
      args.query as string,
      args.country_code as string | undefined,
    );
    return {
      observation,
      ...(result ? { _meta: result } : {}),
    };
  },

  async web_search(args) {
    const text = await webSearch(args.query as string, args.topic as string | undefined);
    return { observation: text };
  },

  async search_places(args) {
    const text = await searchPlaces(
      args.lat as number,
      args.lng as number,
      args.category as string,
      (args.radius_meters as number) ?? 2000,
      (args.limit as number) ?? 8,
    );
    return { observation: text };
  },

  async get_weather(args) {
    const text = await getWeather(
      args.lat as number,
      args.lng as number,
      args.start_date as string,
      args.end_date as string,
    );
    return { observation: text };
  },

  async build_day(args, ctx) {
    return buildDay(args, ctx);
  },

  async audit_timing(args, ctx) {
    return auditTiming(args, ctx);
  },

  async check_open_hours(args) {
    const text = await checkOpenHours(args.lat as number, args.lng as number, args.place_name as string);
    return { observation: text };
  },

  async finalize_plan(args, ctx) {
    return finalizePlan();
  },

  async ask_user(args) {
    return askUser(args);
  },
};
