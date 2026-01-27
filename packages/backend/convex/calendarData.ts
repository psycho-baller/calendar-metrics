import { v } from "convex/values";
import { internalMutation } from "./_generated/server";

export const saveEvents = internalMutation({
  args: {
    events: v.array(
      v.object({
        googleEventId: v.string(),
        calendarId: v.string(),
        title: v.string(),
        description: v.optional(v.string()),
        startTime: v.number(),
        endTime: v.number(),
        metrics: v.any(),
      })
    ),
  },
  handler: async (ctx, args) => {
    for (const evt of args.events) {
      const existing = await ctx.db
        .query("events")
        .withIndex("by_googleEventId", (q) => q.eq("googleEventId", evt.googleEventId))
        .first();

      let eventId;
      if (existing) {
        eventId = existing._id;
        await ctx.db.patch(existing._id, {
          title: evt.title,
          description: evt.description,
          startTime: evt.startTime,
          endTime: evt.endTime,
        });

        // Replace metrics
        const oldMetrics = await ctx.db
          .query("metricValues")
          .withIndex("by_eventId", (q) => q.eq("eventId", eventId))
          .collect();
        for (const m of oldMetrics) {
          await ctx.db.delete(m._id);
        }
      } else {
        eventId = await ctx.db.insert("events", {
          googleEventId: evt.googleEventId,
          calendarId: evt.calendarId,
          title: evt.title,
          description: evt.description,
          startTime: evt.startTime,
          endTime: evt.endTime,
        });
      }

      for (const [key, value] of Object.entries(evt.metrics as Record<string, number | boolean | string>)) {
        await ctx.db.insert("metricValues", {
          eventId,
          key,
          value,
        });
      }
    }
  },
});
