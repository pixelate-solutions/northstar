// Weather via Open-Meteo — free, no API key required.

export async function getWeather(
  lat: number,
  lng: number,
  startDate: string,
  endDate: string,
): Promise<string> {
  const params = new URLSearchParams({
    latitude: String(lat),
    longitude: String(lng),
    daily: 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode',
    start_date: startDate,
    end_date: endDate,
    timezone: 'auto',
    temperature_unit: 'fahrenheit',
  });

  const res = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`);
  if (!res.ok) return `Weather lookup failed: HTTP ${res.status}`;

  const data = (await res.json()) as {
    daily?: {
      time: string[];
      temperature_2m_max: number[];
      temperature_2m_min: number[];
      precipitation_probability_max: number[];
    };
  };

  const daily = data.daily;
  if (!daily || daily.time.length === 0) return 'No weather data available for these dates.';

  const lines = daily.time.map((date, i) => {
    const hi = daily.temperature_2m_max[i]?.toFixed(0) ?? '?';
    const lo = daily.temperature_2m_min[i]?.toFixed(0) ?? '?';
    const rain = daily.precipitation_probability_max[i] ?? 0;
    return `${date}: ${lo}–${hi}°F, ${rain}% rain`;
  });

  return `Weather forecast:\n${lines.join('\n')}`;
}
