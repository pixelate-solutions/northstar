// Geocoding via Mapbox Search Box API. This is used for travel stops, including
// POIs such as parks, trailheads, restaurants, landmarks, and addresses.

export interface GeocodeResult {
  display_name: string;
  lat: number;
  lng: number;
}

const geocodeCache = new Map<string, { observation: string; result?: GeocodeResult }>();
let lastRequestAt = 0;
let geocodeQueue = Promise.resolve();
const mapboxAccessToken = process.env.MAPBOX_ACCESS_TOKEN;
const minIntervalMs = Number.parseInt(process.env.MAPBOX_GEOCODE_MIN_INTERVAL_MS ?? '120', 10);

function cacheKey(query: string, countryCode?: string): string {
  return `${query.trim().toLowerCase()}|${countryCode?.trim().toLowerCase() ?? ''}`;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function throttleMapbox(): Promise<void> {
  const elapsed = Date.now() - lastRequestAt;
  const interval = Number.isFinite(minIntervalMs) && minIntervalMs > 0 ? minIntervalMs : 120;
  if (elapsed < interval) {
    await sleep(interval - elapsed);
  }
  lastRequestAt = Date.now();
}

async function queuedFetch(url: string, init: RequestInit): Promise<Response> {
  const run = geocodeQueue.then(async () => {
    await throttleMapbox();
    return fetch(url, init);
  });
  geocodeQueue = run.then(
    () => undefined,
    () => undefined,
  );
  return run;
}

export async function geocodePlace(
  query: string,
  countryCode?: string,
): Promise<{ observation: string; result?: GeocodeResult }> {
  if (!mapboxAccessToken) {
    return {
      observation:
        'Geocoding unavailable: MAPBOX_ACCESS_TOKEN is not configured on the agent server.',
    };
  }

  const key = cacheKey(query, countryCode);
  const cached = geocodeCache.get(key);
  if (cached) {
    return {
      ...cached,
      observation: `${cached.observation} (cached)`,
    };
  }

  const params = new URLSearchParams({
    q: query,
    limit: '1',
    language: 'en',
    access_token: mapboxAccessToken,
    ...(countryCode ? { country: countryCode } : {}),
  });

  const url = `https://api.mapbox.com/search/searchbox/v1/forward?${params}`;

  let res = await queuedFetch(url, {});

  if (res.status === 429) {
    const retryAfterSeconds = Number.parseInt(res.headers.get('retry-after') ?? '', 10);
    await sleep(Number.isFinite(retryAfterSeconds) ? retryAfterSeconds * 1000 : 2000);
    res = await queuedFetch(url, {});
  }

  if (!res.ok) {
    return { observation: `Mapbox geocoding failed: HTTP ${res.status}` };
  }

  const data = (await res.json()) as {
    features?: Array<{
      geometry?: { coordinates?: [number, number] };
      properties?: {
        name?: string;
        full_address?: string;
        place_formatted?: string;
        mapbox_id?: string;
      };
    }>;
  };

  const first = data.features?.[0];
  const coordinates = first?.geometry?.coordinates;
  if (!first || !coordinates) {
    return { observation: `Could not geocode "${query}" with Mapbox. No results found.` };
  }

  const name = first.properties?.name ?? query;
  const context = first.properties?.full_address ?? first.properties?.place_formatted;
  const displayName = context && context !== name ? `${name}, ${context}` : name;
  const result: GeocodeResult = {
    display_name: displayName,
    lat: coordinates[1],
    lng: coordinates[0],
  };

  const value = {
    observation: `Mapbox geocoded "${query}": ${result.display_name} at (${result.lat.toFixed(5)}, ${result.lng.toFixed(5)})`,
    result,
  };
  geocodeCache.set(key, value);
  return value;
}
