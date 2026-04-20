"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.evaluatePlan = evaluatePlan;
exports.validationIssuesToString = validationIssuesToString;
function evaluatePlan(plan) {
    const issues = [];
    if (!plan.title || plan.title.trim().length === 0) {
        issues.push({ field: 'title', message: 'Plan title is missing.' });
    }
    if (plan.title && plan.title.length > 200) {
        issues.push({ field: 'title', message: 'Plan title is too long (max 200 chars).' });
    }
    if (!plan.summary || plan.summary.trim().length === 0) {
        issues.push({ field: 'summary', message: 'Plan summary is missing.' });
    }
    if (!plan.days || plan.days.length === 0) {
        issues.push({ field: 'days', message: 'Plan has no days.' });
    }
    for (const day of plan.days ?? []) {
        if (!day.stops || day.stops.length === 0) {
            issues.push({
                field: `day_${day.day_index}`,
                message: `Day ${day.label} has no stops.`,
            });
            continue;
        }
        const seenCoords = new Set();
        for (const stop of day.stops) {
            // Reject null island coordinates
            if (stop.latitude === 0 && stop.longitude === 0) {
                issues.push({
                    field: `stop_${stop.place}`,
                    message: `Stop "${stop.place}" has invalid coordinates (0,0). Call geocode_place first.`,
                });
            }
            if (isNaN(stop.latitude) || isNaN(stop.longitude)) {
                issues.push({
                    field: `stop_${stop.place}`,
                    message: `Stop "${stop.place}" has NaN coordinates.`,
                });
            }
            // Reject duplicate coordinates within the same day
            const coordKey = `${stop.latitude.toFixed(4)},${stop.longitude.toFixed(4)}`;
            if (seenCoords.has(coordKey)) {
                issues.push({
                    field: `stop_${stop.place}`,
                    message: `Two stops in ${day.label} share identical coordinates. Check geocoding.`,
                });
            }
            seenCoords.add(coordKey);
        }
    }
    if (!plan.open_questions) {
        issues.push({ field: 'open_questions', message: 'open_questions array is missing.' });
    }
    return issues;
}
function validationIssuesToString(issues) {
    return issues.map((i) => `[${i.field}] ${i.message}`).join('; ');
}
