"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.auditTiming = auditTiming;
async function auditTiming(args, ctx) {
    const dayIndex = args.day_index;
    const day = ctx.accumulatedDays.find((d) => d.day_index === dayIndex);
    if (!day)
        return { observation: `Day ${dayIndex} not found in accumulated days.` };
    const issues = [];
    for (let i = 1; i < day.stops.length; i++) {
        const prev = day.stops[i - 1];
        const curr = day.stops[i];
        const distKm = haversineKm(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
        const mode = args.transport_mode ?? 'transit';
        const speedKmh = mode === 'walking' ? 4 : mode === 'taxi' ? 30 : 20;
        const travelMins = (distKm / speedKmh) * 60;
        if (travelMins > 90) {
            issues.push(`${prev.place} -> ${curr.place}: ~${Math.round(travelMins)} min by ${mode} (${distKm.toFixed(1)} km). Consider consolidating stops or adding more time.`);
        }
    }
    return {
        observation: issues.length === 0
            ? `Day ${day.label} timing looks feasible.`
            : `Timing issues in ${day.label}:\n${issues.join('\n')}`,
    };
}
function haversineKm(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a = Math.sin(dLat / 2) ** 2 +
        Math.cos((lat1 * Math.PI) / 180) *
            Math.cos((lat2 * Math.PI) / 180) *
            Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
