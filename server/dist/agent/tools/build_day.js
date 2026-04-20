"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildDay = buildDay;
async function buildDay(args, ctx) {
    const day = {
        day_index: args.day_index,
        label: args.label,
        title: args.title,
        guidance: args.guidance,
        stops: args.stops,
    };
    const idx = ctx.accumulatedDays.findIndex((d) => d.day_index === day.day_index);
    if (idx >= 0) {
        ctx.accumulatedDays[idx] = day;
    }
    else {
        ctx.accumulatedDays.push(day);
    }
    return {
        observation: `Day ${day.label} committed with ${day.stops.length} stops.`,
    };
}
