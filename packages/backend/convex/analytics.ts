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

const COMPOSITE_EXCLUDED = new Set(["distractions"]);

export const getDailyAggregates = query({
  args: {
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) return [];

    const windowDays = args.days ?? 91;
    const cutoffTime = Date.now() - windowDays * 24 * 60 * 60 * 1000;
    const selectedCalendarId = await getSelectedCalendarId(ctx, user._id);
    const observations = await getRelevantObservations(ctx, selectedCalendarId, { cutoffTime });

    type DayBucket = {
      metrics: Record<string, number[]>;
      sessionIds: Set<string>;
      anySubjectIds: Set<string>;
    };

    const byDate = new Map<string, DayBucket>();

    for (const obs of observations) {
      if (obs.valueType !== "number" || typeof obs.numberValue !== "number") continue;
      const dateStr = new Date(obs.observedAt).toISOString().slice(0, 10);
      if (!byDate.has(dateStr)) {
        byDate.set(dateStr, { metrics: {}, sessionIds: new Set(), anySubjectIds: new Set() });
      }
      const day = byDate.get(dateStr)!;
      if (!day.metrics[obs.key]) day.metrics[obs.key] = [];
      day.metrics[obs.key].push(obs.numberValue);
      day.anySubjectIds.add(`${obs.subjectType}:${obs.subjectId}`);
      if (obs.subjectType === "intentSession") {
        day.sessionIds.add(obs.subjectId);
      }
    }

    const completedSessions = await ctx.db
      .query("intentSessions")
      .withIndex("by_status_startTimeMs", (q: any) =>
        q.eq("status", "completed").gte("startTimeMs", cutoffTime),
      )
      .collect();

    const sessionDurations = new Map<string, number>();
    for (const session of completedSessions) {
      if (session.durationMs) {
        sessionDurations.set(String(session._id), session.durationMs);
      }
    }

    return [...byDate.entries()]
      .map(([dateStr, data]) => {
        const avgMetrics: Record<string, number> = {};
        let compositeSum = 0;
        let compositeCount = 0;

        for (const [key, values] of Object.entries(data.metrics)) {
          const avg = values.reduce((a, b) => a + b, 0) / values.length;
          avgMetrics[key] = Math.round(avg * 10) / 10;
          if (!COMPOSITE_EXCLUDED.has(key)) {
            compositeSum += avg;
            compositeCount++;
          }
        }

        let totalHours = 0;
        for (const sessionId of data.sessionIds) {
          const dur = sessionDurations.get(sessionId);
          if (dur) totalHours += dur / 3_600_000;
        }

        return {
          dateStr,
          sessionCount: data.sessionIds.size,
          anyActivity: data.anySubjectIds.size > 0,
          totalHours: Math.round(totalHours * 10) / 10,
          avgMetrics,
          compositeScore:
            compositeCount > 0 ? Math.round((compositeSum / compositeCount) * 10) / 10 : 0,
        };
      })
      .sort((a, b) => a.dateStr.localeCompare(b.dateStr));
  },
});

export const getWeeklyComparison = query({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) return { thisWeek: {} as Record<string, number>, lastWeek: {} as Record<string, number> };

    const selectedCalendarId = await getSelectedCalendarId(ctx, user._id);

    const msPerDay = 86_400_000;
    const now = Date.now();
    const todayUtcStart = Math.floor(now / msPerDay) * msPerDay;
    const dayOfWeek = new Date(now).getUTCDay();
    const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const thisMondayMs = todayUtcStart - daysToMonday * msPerDay;
    const lastMondayMs = thisMondayMs - 7 * msPerDay;

    const observations = await getRelevantObservations(ctx, selectedCalendarId, {
      cutoffTime: lastMondayMs,
    });

    const numericObs = observations.filter(
      (obs) => obs.valueType === "number" && typeof obs.numberValue === "number",
    );

    function avgByKey(obs: typeof numericObs): Record<string, number> {
      const sums: Record<string, { sum: number; count: number }> = {};
      for (const o of obs) {
        if (!sums[o.key]) sums[o.key] = { sum: 0, count: 0 };
        sums[o.key].sum += o.numberValue as number;
        sums[o.key].count++;
      }
      return Object.fromEntries(
        Object.entries(sums).map(([key, { sum, count }]) => [
          key,
          Math.round((sum / count) * 10) / 10,
        ]),
      );
    }

    return {
      thisWeek: avgByKey(numericObs.filter((o) => o.observedAt >= thisMondayMs)),
      lastWeek: avgByKey(
        numericObs.filter((o) => o.observedAt >= lastMondayMs && o.observedAt < thisMondayMs),
      ),
    };
  },
});
