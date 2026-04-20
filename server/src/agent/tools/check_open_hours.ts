// Opening hours via OSM Overpass API — free.

export async function checkOpenHours(
  lat: number,
  lng: number,
  placeName: string,
): Promise<string> {
  const delta = 0.002; // ~200m bounding box
  const bbox = `${lat - delta},${lng - delta},${lat + delta},${lng + delta}`;
  const query = `[out:json][timeout:10];
(
  node["opening_hours"](${bbox});
  way["opening_hours"](${bbox});
);
out 3;`;

  try {
    const res = await fetch('https://overpass-api.de/api/interpreter', {
      method: 'POST',
      body: query,
      headers: { 'Content-Type': 'text/plain' },
      signal: AbortSignal.timeout(12_000),
    });
    if (!res.ok) return `Could not fetch opening hours (HTTP ${res.status}).`;

    const data = (await res.json()) as {
      elements?: Array<{ tags?: { name?: string; opening_hours?: string } }>;
    };

    const match = data.elements?.find((e) => e.tags?.opening_hours);
    if (!match) return `No opening hours found for "${placeName}" via OpenStreetMap.`;

    const name = match.tags?.name ?? placeName;
    const hours = match.tags?.opening_hours ?? 'unknown';
    return `Opening hours for ${name}: ${hours}`;
  } catch {
    return `Opening hours lookup timed out for "${placeName}".`;
  }
}
