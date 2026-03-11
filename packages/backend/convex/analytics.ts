import { v } from "convex/values";

import type { Doc } from "./_generated/dataModel";
import { query } from "./_generated/server";
import { authComponent } from "./auth";

type MetricObservation = Doc<"metricObservations">;
type MetricScalar = number | boolean | string;

function observationValue(observation: MetricObservation): MetricScalar | null {
  switch (observation.valueType) {
    case "number":
      return typeof observation.numberValue === "number" ? observation.numberValue : null;
    case "boolean":
      return typeof observation.booleanValue === "boolean" ? observation.booleanValue : null;
    case "string":
      return typeof observation.stringValue === "string" ? observation.stringValue : null;
    default:
      return null;
  }
}

async function getSelectedCalendarId(ctx: any, userId: string) {
  const settings = await ctx.db
    .query("userSettings")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .first();

  return settings?.selectedCalendarId ?? null;
}

async function getRelevantObservations(
  ctx: any,
  selectedCalendarId: string | null,
  options?: { cutoffTime?: number },
) {
  const eventObservations = selectedCalendarId
    ? await ctx.db
        .query("metricObservations")
        .withIndex("by_calendarId_observedAt", (q: any) =>
          q.eq("calendarId", selectedCalendarId),
        )
        .collect()
    : [];

  const intentObservations = await ctx.db
    .query("metricObservations")
    .withIndex("by_subjectType_observedAt", (q: any) =>
      q.eq("subjectType", "intentSession"),
    )
    .collect();

  const allObservations = [...eventObservations, ...intentObservations];
  if (!options?.cutoffTime) {
    return allObservations;
  }

  return allObservations.filter(
    (observation) => observation.observedAt >= options.cutoffTime!,
  );
}

function groupObservationsBySubject(observations: MetricObservation[]) {
  return observations.reduce(
    (acc, observation) => {
      const groupKey = `${observation.subjectType}:${observation.subjectId}`;
      const existing = acc.get(groupKey);
      if (existing) {
        existing.push(observation);
      } else {
        acc.set(groupKey, [observation]);
      }
      return acc;
    },
    new Map<string, MetricObservation[]>(),
  );
}

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

    const selectedCalendarId = await getSelectedCalendarId(ctx, user._id);
    if (!selectedCalendarId) {
      return [];
    }

    const allEvents = await ctx.db.query("events").order("desc").collect();
    const filteredEvents = allEvents
      .filter((event) => event.calendarId === selectedCalendarId)
      .slice(0, args.limit || 100);

    const eventsWithMetrics = await Promise.all(
      filteredEvents.map(async (event) => {
        const observations = await ctx.db
          .query("metricObservations")
          .withIndex("by_subjectType_subjectId", (q: any) =>
            q.eq("subjectType", "event").eq("subjectId", event._id),
          )
          .collect();

        return {
          ...event,
          metrics: observations.reduce((acc, observation) => {
            const value = observationValue(observation);
            if (value !== null) {
              acc[observation.key] = value;
            }
            return acc;
          }, {} as Record<string, MetricScalar>),
        };
      }),
    );

    return eventsWithMetrics;
  },
});

// Get all unique metric keys across event and intent-session observations
export const getMetricKeys = query({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return [];
    }

    const selectedCalendarId = await getSelectedCalendarId(ctx, user._id);
    const observations = await getRelevantObservations(ctx, selectedCalendarId);
    return [...new Set(observations.map((observation) => observation.key))].sort();
  },
});

// Get metrics over time for a specific key
export const getMetricTimeSeries = query({
  args: {
    key: v.string(),
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return [];
    }

    const selectedCalendarId = await getSelectedCalendarId(ctx, user._id);
    const cutoffTime = Date.now() - (args.days || 30) * 24 * 60 * 60 * 1000;
    const observations = await getRelevantObservations(ctx, selectedCalendarId, {
      cutoffTime,
    });

    return observations
      .filter(
        (observation) =>
          observation.key === args.key &&
          observation.valueType === "number" &&
          typeof observation.numberValue === "number",
      )
      .map((observation) => ({
        date: observation.observedAt,
        value: observation.numberValue as number,
        subjectTitle: observation.subjectTitle,
        subjectType: observation.subjectType,
      }))
      .sort((left, right) => left.date - right.date);
  },
});

// Get summary statistics for all metrics (numbers, booleans, and strings)
export const getMetricsSummary = query({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return { numeric: {}, categorical: {} };
    }

    const selectedCalendarId = await getSelectedCalendarId(ctx, user._id);
    const observations = await getRelevantObservations(ctx, selectedCalendarId);

    const numericStats: Record<
      string,
      {
        type: "numeric";
        count: number;
        sum: number;
        min: number;
        max: number;
        avg: number;
      }
    > = {};

    const categoricalStats: Record<
      string,
      {
        type: "categorical";
        count: number;
        valueCounts: Record<string, number>;
        topValue: string;
      }
    > = {};

    for (const observation of observations) {
      const value = observationValue(observation);
      if (value === null) {
        continue;
      }

      if (typeof value === "number") {
        if (!numericStats[observation.key]) {
          numericStats[observation.key] = {
            type: "numeric",
            count: 0,
            sum: 0,
            min: Infinity,
            max: -Infinity,
            avg: 0,
          };
        }

        const stats = numericStats[observation.key];
        stats.count += 1;
        stats.sum += value;
        stats.min = Math.min(stats.min, value);
        stats.max = Math.max(stats.max, value);
        continue;
      }

      const stringValue = String(value);
      if (!categoricalStats[observation.key]) {
        categoricalStats[observation.key] = {
          type: "categorical",
          count: 0,
          valueCounts: {},
          topValue: "",
        };
      }

      const stats = categoricalStats[observation.key];
      stats.count += 1;
      stats.valueCounts[stringValue] = (stats.valueCounts[stringValue] || 0) + 1;
    }

    for (const key of Object.keys(numericStats)) {
      const stats = numericStats[key];
      stats.avg = stats.count > 0 ? Math.round((stats.sum / stats.count) * 100) / 100 : 0;
      stats.min = stats.min === Infinity ? 0 : stats.min;
      stats.max = stats.max === -Infinity ? 0 : stats.max;
    }

    for (const key of Object.keys(categoricalStats)) {
      const stats = categoricalStats[key];
      let maxCount = 0;
      for (const [value, count] of Object.entries(stats.valueCounts)) {
        if (count > maxCount) {
          maxCount = count;
          stats.topValue = value;
        }
      }
    }

    return {
      numeric: numericStats,
      categorical: categoricalStats,
    };
  },
});

// Get recent tracked subjects with their metrics (calendar events and reviewed sessions)
export const getRecentActivity = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return [];
    }

    const selectedCalendarId = await getSelectedCalendarId(ctx, user._id);
    const observations = await getRelevantObservations(ctx, selectedCalendarId);
    const grouped = groupObservationsBySubject(observations);

    return [...grouped.values()]
      .map((group) => {
        const sorted = [...group].sort((left, right) => right.observedAt - left.observedAt);
        const head = sorted[0];
        return {
          id: `${head.subjectType}:${head.subjectId}`,
          title: head.subjectTitle,
          date: head.observedAt,
          subjectType: head.subjectType,
          metrics: sorted
            .map((observation) => {
              const value = observationValue(observation);
              if (value === null) {
                return null;
              }

              return {
                key: observation.key,
                value,
              };
            })
            .filter((metric): metric is { key: string; value: MetricScalar } => metric !== null)
            .sort((left, right) => left.key.localeCompare(right.key)),
        };
      })
      .sort((left, right) => right.date - left.date)
      .slice(0, args.limit || 10);
  },
});
