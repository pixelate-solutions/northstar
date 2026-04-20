// Points of interest via Foursquare Places Search.
// API key required: https://location.foursquare.com/developer/

export async function searchPlaces(
  lat: number,
  lng: number,
  category: string,
  radiusMeters = 2000,
  limit = 8,
): Promise<string> {
  const apiKey = process.env.FOURSQUARE_API_KEY;
  if (!apiKey) {
    return `[search_places] FOURSQUARE_API_KEY not set - skipping POI search for (${lat}, ${lng}).`;
  }

  const params = new URLSearchParams({
    ll: `${lat},${lng}`,
    radius: String(Math.min(Math.max(radiusMeters, 1), 100_000)),
    query: queryForCategory(category),
    limit: String(Math.min(Math.max(limit, 1), 50)),
    sort: 'DISTANCE',
    fields: 'name,geocodes,location,categories,distance',
  });

  const res = await fetch(`https://api.foursquare.com/v3/places/search?${params}`, {
    headers: {
      Accept: 'application/json',
      Authorization: apiKey,
    },
  });
  if (!res.ok) return `Foursquare POI search failed: HTTP ${res.status}`;

  const data = (await res.json()) as {
    results?: FoursquarePlace[];
  };
  const places = data.results ?? [];
  if (!places || places.length === 0) {
    return `No ${category} places found near (${lat.toFixed(3)}, ${lng.toFixed(3)}).`;
  }

  const lines = places
    .filter((p) => p.name && p.name.trim().length > 0)
    .map(formatPlace);

  return `Found ${lines.length} ${category} places:\n${lines.join('\n')}`;
}

interface FoursquarePlace {
  name?: string;
  distance?: number;
  geocodes?: {
    main?: {
      latitude?: number;
      longitude?: number;
    };
  };
  location?: {
    formatted_address?: string;
  };
  categories?: Array<{
    name?: string;
  }>;
}

function queryForCategory(category: string): string {
  const map: Record<string, string> = {
    attractions: 'attractions',
    cultural: 'museum culture',
    restaurants: 'restaurants',
    natural: 'parks nature',
    architecture: 'architecture landmarks',
    shops: 'shopping',
    transport: 'transit station',
    general: 'places',
  };
  return map[category] ?? 'places';
}

function formatPlace(place: FoursquarePlace): string {
  const coords = place.geocodes?.main;
  const coordText =
    coords?.latitude !== undefined && coords?.longitude !== undefined
      ? ` (${coords.latitude.toFixed(4)}, ${coords.longitude.toFixed(4)})`
      : '';
  const category = place.categories?.[0]?.name;
  const categoryText = category ? ` - ${category}` : '';
  const address = place.location?.formatted_address;
  const addressText = address ? ` - ${address}` : '';
  const distanceText =
    place.distance !== undefined ? ` - ${Math.round(place.distance)}m away` : '';

  return `- ${place.name}${coordText}${categoryText}${addressText}${distanceText}`;
}
