import type {
  DailyAggregate,
  DashboardMetricsSummary,
  MetricTimeSeriesPoint,
  RecentActivityItem,
  WeeklyComparison,
} from "@/routes/dashboard";

export type DemoDashboardData = {
  userSettings: {
    selectedCalendarName: string;
  };
  metricsSummary: DashboardMetricsSummary;
  recentActivity: RecentActivityItem[];
  dailyAggregates: DailyAggregate[];
  weeklyComparison: WeeklyComparison;
  metricTimeSeriesByKey: Record<string, MetricTimeSeriesPoint[]>;
};

const NUMERIC_KEYS = [
  "focus",
  "discipline",
  "energy",
  "mindfulness",
  "intentionality",
  "purpose",
  "distractions",
];

const CORE_KEYS = NUMERIC_KEYS.filter((key) => key !== "distractions");

const SESSION_TITLES = [
  "Deep work block",
  "Planning review",
  "Design implementation",
  "Inbox reset",
  "Strategy session",
  "Writing sprint",
  "Code review pass",
  "Research synthesis",
];

const EVENT_TITLES = [
  "Product sync",
  "Customer interview",
  "Roadmap review",
  "Engineering standup",
  "Metrics review",
  "Design critique",
  "Hiring screen",
  "Stakeholder update",
];

const TASK_CATEGORIES = ["Engineering", "Strategy", "Design", "Operations", "Research", "Writing"];
const WORK_MODES = ["Deep work", "Collaboration", "Planning", "Review", "Recovery"];

function seededUnit(seed: number) {
  const value = Math.sin(seed * 12.9898) * 43758.5453;
  return value - Math.floor(value);
}

function choose<T>(items: T[], seed: number): T {
  return items[Math.floor(seededUnit(seed) * items.length) % items.length];
}

function clampScore(value: number) {
  return Math.max(1, Math.min(10, Math.round(value * 10) / 10));
}

function dateKey(date: Date) {
  return date.toISOString().slice(0, 10);
}

function startOfUtcDay(date: Date) {
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function average(values: number[]) {
  return Math.round((values.reduce((sum, value) => sum + value, 0) / values.length) * 10) / 10;
}

function addCount(counts: Record<string, number>, value: string) {
  counts[value] = (counts[value] || 0) + 1;
}

function topValue(counts: Record<string, number>) {
  return Object.entries(counts).sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0]))[0]?.[0] ?? "";
}

export function createDemoDashboardData(now = new Date()): DemoDashboardData {
  const todayMs = startOfUtcDay(now);
  const numericValues: Record<string, number[]> = Object.fromEntries(NUMERIC_KEYS.map((key) => [key, []]));
  const metricTimeSeriesByKey: Record<string, MetricTimeSeriesPoint[]> = Object.fromEntries(
    NUMERIC_KEYS.map((key) => [key, []]),
  );
  const taskCategoryCounts: Record<string, number> = {};
  const workModeCounts: Record<string, number> = {};
  const recentActivity: RecentActivityItem[] = [];
  const dailyAggregates: DailyAggregate[] = [];

  for (let dayIndex = 0; dayIndex < 100; dayIndex++) {
    const daysAgo = 99 - dayIndex;
    const date = new Date(todayMs - daysAgo * 86_400_000);
    const dateStr = dateKey(date);
    const weekday = date.getUTCDay();
    const weekdayBoost = weekday >= 1 && weekday <= 5 ? 0.35 : -0.2;
    const trend = dayIndex * 0.018;
    const cadence = Math.sin(dayIndex / 8) * 0.5;
    const active = daysAgo <= 9 || seededUnit(dayIndex + 3) < (weekday >= 1 && weekday <= 5 ? 0.82 : 0.58);
    const dayBuckets: Record<string, number[]> = Object.fromEntries(NUMERIC_KEYS.map((key) => [key, []]));
    let sessionCount = 0;
    let totalHours = 0;

    if (active) {
      const subjectCount = 1 + (seededUnit(dayIndex + 21) > 0.72 ? 1 : 0) + (seededUnit(dayIndex + 55) > 0.9 ? 1 : 0);

      for (let subjectIndex = 0; subjectIndex < subjectCount; subjectIndex++) {
        const subjectSeed = dayIndex * 17 + subjectIndex * 31;
        const subjectType = seededUnit(subjectSeed + 8) < 0.64 ? "intentSession" : "event";
        const hour = 8 + Math.floor(seededUnit(subjectSeed + 9) * 10);
        const minute = seededUnit(subjectSeed + 10) > 0.5 ? 30 : 0;
        const observedAt = todayMs - daysAgo * 86_400_000 + hour * 3_600_000 + minute * 60_000;
        const titlePrefix = subjectType === "intentSession" ? SESSION_TITLES : EVENT_TITLES;
        const subjectTitle = choose(titlePrefix, subjectSeed + 11);
        const taskCategory = choose(TASK_CATEGORIES, subjectSeed + 12);
        const workMode = choose(WORK_MODES, subjectSeed + 13);
        const base = 6.15 + weekdayBoost + trend + cadence + (seededUnit(subjectSeed + 14) - 0.5) * 1.4;
        const focus = clampScore(base + 0.55 + (seededUnit(subjectSeed + 15) - 0.5) * 1.2);
        const discipline = clampScore(base + 0.1 + (seededUnit(subjectSeed + 16) - 0.5) * 1.1);
        const energy = clampScore(base + Math.sin(dayIndex / 5) * 0.55 + (seededUnit(subjectSeed + 17) - 0.5));
        const mindfulness = clampScore(base - 0.35 + (seededUnit(subjectSeed + 18) - 0.5) * 1.5);
        const intentionality = clampScore(base + 0.25 + (seededUnit(subjectSeed + 19) - 0.5) * 1.1);
        const purpose = clampScore(base + 0.4 + (seededUnit(subjectSeed + 20) - 0.5) * 1.2);
        const distractions = clampScore(10.5 - focus + (seededUnit(subjectSeed + 22) - 0.5) * 1.8);
        const metrics = {
          focus,
          discipline,
          energy,
          mindfulness,
          intentionality,
          purpose,
          distractions,
        };

        for (const [key, value] of Object.entries(metrics)) {
          numericValues[key].push(value);
          dayBuckets[key].push(value);
          metricTimeSeriesByKey[key].push({
            date: observedAt,
            value,
            subjectTitle,
            subjectType,
          });
        }

        addCount(taskCategoryCounts, taskCategory);
        addCount(workModeCounts, workMode);

        if (subjectType === "intentSession") {
          sessionCount += 1;
          totalHours += 0.75 + seededUnit(subjectSeed + 23) * 1.9;
        }

        recentActivity.push({
          id: `demo:${dateStr}:${subjectIndex}`,
          title: subjectTitle,
          date: observedAt,
          subjectType,
          metrics: [
            { key: "focus", value: focus },
            { key: "energy", value: energy },
            { key: "intentionality", value: intentionality },
            { key: "taskCategory", value: taskCategory },
            { key: "workMode", value: workMode },
          ],
        });
      }
    }

    const avgMetrics = Object.fromEntries(
      Object.entries(dayBuckets)
        .filter(([, values]) => values.length > 0)
        .map(([key, values]) => [key, average(values)]),
    );
    const compositeValues = CORE_KEYS.map((key) => avgMetrics[key]).filter((value): value is number => value !== undefined);

    dailyAggregates.push({
      dateStr,
      sessionCount,
      anyActivity: active,
      totalHours: Math.round(totalHours * 10) / 10,
      avgMetrics,
      compositeScore: compositeValues.length > 0 ? average(compositeValues) : 0,
    });
  }

  const numeric = Object.fromEntries(
    Object.entries(numericValues).map(([key, values]) => [
      key,
      {
        count: values.length,
        avg: average(values),
        min: Math.min(...values),
        max: Math.max(...values),
      },
    ]),
  );
  const sortedActivity = recentActivity.sort((left, right) => right.date - left.date);

  return {
    userSettings: {
      selectedCalendarName: "Demo Work Calendar",
    },
    metricsSummary: {
      numeric,
      categorical: {
        taskCategory: {
          count: Object.values(taskCategoryCounts).reduce((sum, count) => sum + count, 0),
          valueCounts: taskCategoryCounts,
          topValue: topValue(taskCategoryCounts),
        },
        workMode: {
          count: Object.values(workModeCounts).reduce((sum, count) => sum + count, 0),
          valueCounts: workModeCounts,
          topValue: topValue(workModeCounts),
        },
      },
    },
    recentActivity: sortedActivity.slice(0, 8),
    dailyAggregates,
    weeklyComparison: createWeeklyComparison(metricTimeSeriesByKey, todayMs),
    metricTimeSeriesByKey,
  };
}

function createWeeklyComparison(
  metricTimeSeriesByKey: Record<string, MetricTimeSeriesPoint[]>,
  todayMs: number,
): WeeklyComparison {
  const dayOfWeek = new Date(todayMs).getUTCDay();
  const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  const thisMondayMs = todayMs - daysToMonday * 86_400_000;
  const lastMondayMs = thisMondayMs - 7 * 86_400_000;

  return {
    thisWeek: averageWindow(metricTimeSeriesByKey, thisMondayMs, todayMs + 86_400_000),
    lastWeek: averageWindow(metricTimeSeriesByKey, lastMondayMs, thisMondayMs),
  };
}

function averageWindow(
  metricTimeSeriesByKey: Record<string, MetricTimeSeriesPoint[]>,
  startMs: number,
  endMs: number,
) {
  return Object.fromEntries(
    Object.entries(metricTimeSeriesByKey)
      .map(([key, points]) => {
        const values = points.filter((point) => point.date >= startMs && point.date < endMs).map((point) => point.value);
        return values.length > 0 ? [key, average(values)] : null;
      })
      .filter((entry): entry is [string, number] => entry !== null),
  );
}
