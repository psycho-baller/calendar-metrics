import { query } from "./_generated/server";
import { v } from "convex/values";
import { authComponent } from "./auth";

// Get all events for the current user's selected calendar
export const getEvents = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return [];
    }

    // Get user's selected calendar
    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!settings?.selectedCalendarId) {
      return [];
    }

    // Fetch events ordered by start time (most recent first)
    let eventsQuery = ctx.db
      .query("events")
      .order("desc");

    const allEvents = await eventsQuery.collect();

    // Filter by calendar and limit
    const filteredEvents = allEvents
      .filter((e) => e.calendarId === settings.selectedCalendarId)
      .slice(0, args.limit || 100);

    // For each event, get its metrics
    const eventsWithMetrics = await Promise.all(
      filteredEvents.map(async (event) => {
        const metrics = await ctx.db
          .query("metricValues")
          .withIndex("by_eventId", (q) => q.eq("eventId", event._id))
          .collect();

        return {
          ...event,
          metrics: metrics.reduce((acc, m) => {
            acc[m.key] = m.value;
            return acc;
          }, {} as Record<string, number | boolean>),
        };
      })
    );

    return eventsWithMetrics;
  },
});

// Get all unique metric keys
export const getMetricKeys = query({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return [];
    }

    // Get all metric values
    const allMetrics = await ctx.db.query("metricValues").collect();

    // Get unique keys
    const keys = [...new Set(allMetrics.map((m) => m.key))];

    return keys.sort();
  },
});

// Get metrics over time for a specific key
export const getMetricTimeSeries = query({
  args: {
    key: v.string(),
    days: v.optional(v.number()), // Default 30 days
  },
  handler: async (ctx, args) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return [];
    }

    // Get user's selected calendar
    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!settings?.selectedCalendarId) {
      return [];
    }

    const daysAgo = args.days || 30;
    const cutoffTime = Date.now() - daysAgo * 24 * 60 * 60 * 1000;

    // Get all events from the selected calendar
    const events = await ctx.db.query("events").collect();
    const filteredEvents = events.filter(
      (e) => e.calendarId === settings.selectedCalendarId && e.startTime >= cutoffTime
    );

    // Get metrics for these events
    const dataPoints = await Promise.all(
      filteredEvents.map(async (event) => {
        const metric = await ctx.db
          .query("metricValues")
          .withIndex("by_eventId", (q) => q.eq("eventId", event._id))
          .filter((q) => q.eq(q.field("key"), args.key))
          .first();

        if (metric && typeof metric.value === "number") {
          return {
            date: event.startTime,
            value: metric.value,
            eventTitle: event.title,
          };
        }
        return null;
      })
    );

    // Filter out nulls and sort by date
    return dataPoints
      .filter((d): d is NonNullable<typeof d> => d !== null)
      .sort((a, b) => a.date - b.date);
  },
});

// Get summary statistics for all metrics
export const getMetricsSummary = query({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return {};
    }

    // Get user's selected calendar
    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!settings?.selectedCalendarId) {
      return {};
    }

    // Get events from selected calendar
    const events = await ctx.db.query("events").collect();
    const calendarEvents = events.filter(
      (e) => e.calendarId === settings.selectedCalendarId
    );
    const eventIds = new Set(calendarEvents.map((e) => e._id));

    // Get all metrics for these events
    const allMetrics = await ctx.db.query("metricValues").collect();
    const relevantMetrics = allMetrics.filter((m) => eventIds.has(m.eventId));

    // Group by key and calculate stats
    const statsByKey: Record<string, {
      count: number;
      sum: number;
      min: number;
      max: number;
      avg: number;
      values: number[];
    }> = {};

    for (const metric of relevantMetrics) {
      if (typeof metric.value !== "number") continue;

      if (!statsByKey[metric.key]) {
        statsByKey[metric.key] = {
          count: 0,
          sum: 0,
          min: Infinity,
          max: -Infinity,
          avg: 0,
          values: [],
        };
      }

      const stats = statsByKey[metric.key];
      stats.count++;
      stats.sum += metric.value;
      stats.min = Math.min(stats.min, metric.value);
      stats.max = Math.max(stats.max, metric.value);
      stats.values.push(metric.value);
    }

    // Calculate averages
    for (const key of Object.keys(statsByKey)) {
      const stats = statsByKey[key];
      stats.avg = stats.count > 0 ? stats.sum / stats.count : 0;
      // Round to 2 decimal places
      stats.avg = Math.round(stats.avg * 100) / 100;
      stats.min = stats.min === Infinity ? 0 : stats.min;
      stats.max = stats.max === -Infinity ? 0 : stats.max;
    }

    return statsByKey;
  },
});

// Get recent events with their metrics (for activity feed)
export const getRecentActivity = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return [];
    }

    // Get user's selected calendar
    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!settings?.selectedCalendarId) {
      return [];
    }

    // Get recent events
    const events = await ctx.db.query("events").order("desc").collect();
    const recentEvents = events
      .filter((e) => e.calendarId === settings.selectedCalendarId)
      .slice(0, args.limit || 10);

    // Get metrics for each event
    const activity = await Promise.all(
      recentEvents.map(async (event) => {
        const metrics = await ctx.db
          .query("metricValues")
          .withIndex("by_eventId", (q) => q.eq("eventId", event._id))
          .collect();

        return {
          id: event._id,
          title: event.title,
          date: event.startTime,
          metrics: metrics.map((m) => ({ key: m.key, value: m.value })),
        };
      })
    );

    return activity;
  },
});
