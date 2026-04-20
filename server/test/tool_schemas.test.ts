import { TOOL_SCHEMAS, TOOL_HANDLERS } from '../src/agent/tools/registry';

describe('tool schemas', () => {
  it('all 9 expected tools are defined in TOOL_SCHEMAS', () => {
    const names = TOOL_SCHEMAS.map((t) => t.function.name);
    const expected = [
      'geocode_place',
      'web_search',
      'search_places',
      'get_weather',
      'build_day',
      'audit_timing',
      'check_open_hours',
      'finalize_plan',
      'ask_user',
    ];
    for (const name of expected) {
      expect(names).toContain(name);
    }
    expect(names).toHaveLength(expected.length);
  });

  it('each schema has type:function and a parameters object', () => {
    for (const tool of TOOL_SCHEMAS) {
      expect(tool.type).toBe('function');
      expect(tool.function.name).toBeTruthy();
      expect(tool.function.description).toBeTruthy();
      expect(tool.function.parameters).toBeDefined();
    }
  });

  it('all schemas with required fields list them as arrays', () => {
    for (const tool of TOOL_SCHEMAS) {
      const req = tool.function.parameters?.required;
      if (req !== undefined) {
        expect(Array.isArray(req)).toBe(true);
      }
    }
  });

  it('all 9 tools have a matching handler', () => {
    for (const tool of TOOL_SCHEMAS) {
      expect(TOOL_HANDLERS[tool.function.name]).toBeDefined();
    }
  });

  it('build_day stops items require all 7 stop fields', () => {
    const buildDay = TOOL_SCHEMAS.find((t) => t.function.name === 'build_day')!;
    const stopRequired = (buildDay.function.parameters as any).properties.stops.items.required as string[];
    const expected = ['time', 'title', 'place', 'note', 'latitude', 'longitude', 'tag'];
    for (const f of expected) {
      expect(stopRequired).toContain(f);
    }
  });

  it('finalize_plan pace is restricted to enum', () => {
    const fp = TOOL_SCHEMAS.find((t) => t.function.name === 'finalize_plan')!;
    const pace = (fp.function.parameters as any).properties.pace;
    expect(pace.enum).toEqual(['Easy', 'Balanced', 'Packed']);
  });
});
