import { api } from "@calendar-metrics/backend/convex/_generated/api";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Authenticated, AuthLoading, Unauthenticated, useAction, useQuery } from "convex/react";
import type { ReactNode } from "react";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import {
  Area,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ComposedChart,
  Legend,
  Line,
  PolarAngleAxis,
  PolarGrid,
  PolarRadiusAxis,
  Radar,
  RadarChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import SignInForm from "@/components/sign-in-form";
import SignUpForm from "@/components/sign-up-form";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import UserMenu from "@/components/user-menu";
import { cn } from "@/lib/utils";

export type NumericMetricStats = {
  count: number;
  avg: number;
  min: number;
  max: number;
};

export type CategoricalMetricStats = {
  count: number;
  valueCounts: Record<string, number>;
  topValue: string;
};

export type DashboardMetricsSummary = {
  numeric: Record<string, NumericMetricStats>;
  categorical: Record<string, CategoricalMetricStats>;
};

export type RecentActivityItem = {
  id: string;
  title: string;
  date: number;
  subjectType: "event" | "intentSession";
  metrics: Array<{ key: string; value: number | boolean | string }>;
};

export type MetricTimeSeriesPoint = {
  date: number;
  value: number;
  subjectTitle: string;
  subjectType: "event" | "intentSession";
};

export type DailyAggregate = {
  dateStr: string;
  sessionCount: number;
  anyActivity: boolean;
  totalHours: number;
  avgMetrics: Record<string, number>;
  compositeScore: number;
};

export type WeeklyComparison = {
  thisWeek: Record<string, number>;
  lastWeek: Record<string, number>;
};

const CORE_METRICS = ["focus", "discipline", "energy", "mindfulness", "intentionality", "purpose"];
const METRIC_COLORS: Record<string, string> = {
  focus: "#2563eb",
  discipline: "#0f766e",
  energy: "#ea580c",
  mindfulness: "#7c3aed",
  intentionality: "#be185d",
  purpose: "#d97706",
  distractions: "#dc2626",
};

function computeMovingAverage(points: { date: number; value: number }[], window: number) {
  return points.map((point, i) => {
    const slice = points.slice(Math.max(0, i - window + 1), i + 1);
    const ma = slice.reduce((s, p) => s + p.value, 0) / slice.length;
    return { ...point, ma7: Math.round(ma * 10) / 10 };
  });
}

function computeStreak(dailyData: Pick<DailyAggregate, "dateStr" | "sessionCount">[]) {
  const today = new Date().toISOString().slice(0, 10);
  const yesterday = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);
  const activeDays = new Set(dailyData.filter((d) => d.sessionCount > 0).map((d) => d.dateStr));
  let current: string | null = activeDays.has(today)
    ? today
    : activeDays.has(yesterday)
      ? yesterday
      : null;
  let streak = 0;
  while (current && activeDays.has(current)) {
    streak++;
    const date = new Date(`${current}T12:00:00Z`);
    date.setUTCDate(date.getUTCDate() - 1);
    current = date.toISOString().slice(0, 10);
  }
  return streak;
}

function compositeFromSummary(numeric: Record<string, NumericMetricStats>): number | null {
  const values = CORE_METRICS.map((k) => numeric[k]?.avg).filter((v) => v !== undefined) as number[];
  if (values.length === 0) return null;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function compositeFromWeek(week: Record<string, number>): number | null {
  const values = CORE_METRICS.map((k) => week[k]).filter((v) => v !== undefined);
  if (values.length === 0) return null;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function heatmapCellClass(data: DailyAggregate | undefined): string {
  if (!data || (!data.sessionCount && !data.anyActivity)) return "bg-muted/30";
  if (data.compositeScore === 0) return "bg-teal-500/20";
  if (data.compositeScore >= 8) return "bg-teal-500";
  if (data.compositeScore >= 6.5) return "bg-teal-500/70";
  if (data.compositeScore >= 5) return "bg-amber-500/60";
  return "bg-red-400/60";
}

const HERO_TONES = ["#0f766e", "#ea580c", "#2563eb", "#be185d", "#7c3aed"];
const CHART_TEXT = "var(--foreground)";
const CHART_MUTED_TEXT = "var(--muted-foreground)";

export const Route = createFileRoute("/dashboard")({
  component: RouteComponent,
});

function RouteComponent() {
  const [showSignIn, setShowSignIn] = useState(false);

  return (
    <>
      <Authenticated>
        <DashboardContent />
      </Authenticated>
      <Unauthenticated>
        {showSignIn ? (
          <SignInForm onSwitchToSignUp={() => setShowSignIn(false)} />
        ) : (
          <SignUpForm onSwitchToSignIn={() => setShowSignIn(true)} />
        )}
      </Unauthenticated>
      <AuthLoading>
        <div>Loading...</div>
      </AuthLoading>
    </>
  );
}

function DashboardContent() {
  const navigate = useNavigate();
  const userSettings = useQuery(api.userSettings.getUserSettings);
  const metricsSummary = useQuery(api.analytics.getMetricsSummary);
  const recentActivity = useQuery(api.analytics.getRecentActivity, { limit: 8 });
  const dailyAggregates = useQuery(api.analytics.getDailyAggregates, { days: 91 }) as DailyAggregate[] | undefined;
  const weeklyComparison = useQuery(api.analytics.getWeeklyComparison) as WeeklyComparison | undefined;
  const [selectedMetric, setSelectedMetric] = useState<string | null>(null);
  const [metricWindowDays, setMetricWindowDays] = useState(30);
  const metricTimeSeries = useQuery(
    api.analytics.getMetricTimeSeries,
    selectedMetric
      ? {
          key: selectedMetric,
          days: metricWindowDays,
        }
      : "skip",
  ) as MetricTimeSeriesPoint[] | undefined;

  useEffect(() => {
    if (userSettings !== undefined && !userSettings?.onboardingCompleted) {
      navigate({ to: "/onboarding" });
    }
  }, [navigate, userSettings]);

  if (userSettings === undefined) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="animate-pulse text-muted-foreground">Loading...</div>
      </div>
    );
  }

  return (
    <DashboardView
      userSettings={userSettings}
      metricsSummary={metricsSummary as DashboardMetricsSummary | undefined}
      recentActivity={(recentActivity || []) as RecentActivityItem[]}
      dailyAggregates={dailyAggregates}
      weeklyComparison={weeklyComparison}
      selectedMetric={selectedMetric}
      onSelectedMetricChange={setSelectedMetric}
      metricWindowDays={metricWindowDays}
      onMetricWindowDaysChange={setMetricWindowDays}
      metricTimeSeries={metricTimeSeries}
      heroActions={
        <>
          <SyncButton />
          <UserMenu />
        </>
      }
    />
  );
}

export type DashboardViewProps = {
  userSettings?: {
    selectedCalendarName?: string | null;
  } | null;
  metricsSummary?: DashboardMetricsSummary;
  recentActivity?: RecentActivityItem[];
  dailyAggregates?: DailyAggregate[];
  weeklyComparison?: WeeklyComparison;
  selectedMetric: string | null;
  onSelectedMetricChange: (value: string) => void;
  metricWindowDays: number;
  onMetricWindowDaysChange: (value: number) => void;
  metricTimeSeries?: MetricTimeSeriesPoint[];
  heroActions?: ReactNode;
};

export function DashboardView({
  userSettings,
  metricsSummary,
  recentActivity = [],
  dailyAggregates,
  weeklyComparison,
  selectedMetric,
  onSelectedMetricChange,
  metricWindowDays,
  onMetricWindowDaysChange,
  metricTimeSeries,
  heroActions,
}: DashboardViewProps) {
  const summary = (metricsSummary ?? { numeric: {}, categorical: {} }) as DashboardMetricsSummary;
  const numericMetrics = summary.numeric;
  const categoricalMetrics = summary.categorical;
  const numericEntries = Object.entries(numericMetrics).sort((left, right) => {
    if (left[1].avg === right[1].avg) {
      return left[0].localeCompare(right[0]);
    }
    return right[1].avg - left[1].avg;
  });
  const categoricalEntries = Object.entries(categoricalMetrics).sort((left, right) => {
    if (left[1].count === right[1].count) {
      return left[0].localeCompare(right[0]);
    }
    return right[1].count - left[1].count;
  });
  const availableNumericKeys = numericEntries.map(([key]) => key);
  const preferredCategoricalKey =
    categoricalMetrics.taskCategory ? "taskCategory" : categoricalEntries[0]?.[0] ?? null;

  useEffect(() => {
    if (!selectedMetric && availableNumericKeys.length > 0) {
      onSelectedMetricChange(availableNumericKeys[0]);
    }
  }, [availableNumericKeys, onSelectedMetricChange, selectedMetric]);

  useEffect(() => {
    if (selectedMetric && !numericMetrics[selectedMetric] && availableNumericKeys.length > 0) {
      onSelectedMetricChange(availableNumericKeys[0]);
    }
  }, [availableNumericKeys, numericMetrics, onSelectedMetricChange, selectedMetric]);

  const hasMetrics = numericEntries.length > 0 || categoricalEntries.length > 0;
  const strongestSignal = numericEntries[0];
  const dominantCategory = preferredCategoricalKey
    ? categoricalMetrics[preferredCategoricalKey]?.topValue
    : null;
  const sessionMoments = ((recentActivity || []) as RecentActivityItem[]).filter(
    (item) => item.subjectType === "intentSession",
  ).length;
  const observationCount = numericEntries.reduce((sum, [, stats]) => sum + stats.count, 0);

  const currentStreak = dailyAggregates ? computeStreak(dailyAggregates) : 0;
  const totalHours = dailyAggregates
    ? Math.round(dailyAggregates.reduce((s, d) => s + d.totalHours, 0) * 10) / 10
    : 0;
  const compositeNow = compositeFromSummary(numericMetrics);
  const compositeThisWeek = weeklyComparison ? compositeFromWeek(weeklyComparison.thisWeek) : null;
  const compositeLastWeek = weeklyComparison ? compositeFromWeek(weeklyComparison.lastWeek) : null;
  const compositeDelta =
    compositeThisWeek !== null && compositeLastWeek !== null
      ? Math.round((compositeThisWeek - compositeLastWeek) * 10) / 10
      : null;

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top_left,_rgba(13,148,136,0.16),_transparent_30%),radial-gradient(circle_at_top_right,_rgba(249,115,22,0.14),_transparent_28%),linear-gradient(180deg,_rgba(248,250,252,0.88),_rgba(248,250,252,1))] px-4 py-8 dark:bg-[radial-gradient(circle_at_top_left,_rgba(13,148,136,0.2),_transparent_28%),radial-gradient(circle_at_top_right,_rgba(234,88,12,0.16),_transparent_30%),linear-gradient(180deg,_rgba(9,12,18,0.96),_rgba(11,16,24,1))]">
      <div className="mx-auto flex max-w-7xl flex-col gap-6">
        <section className="relative overflow-hidden rounded-[32px] border border-white/50 bg-[linear-gradient(135deg,_rgba(15,23,42,0.92),_rgba(15,118,110,0.85)_56%,_rgba(180,83,9,0.84))] p-6 text-white shadow-[0_30px_90px_-45px_rgba(15,23,42,0.9)]">
          <div className="pointer-events-none absolute -left-10 top-[-5rem] h-64 w-64 rounded-full bg-white/10 blur-3xl" />
          <div className="pointer-events-none absolute right-[-4rem] top-10 h-56 w-56 rounded-full bg-teal-300/20 blur-3xl" />
          <div className="relative flex flex-col gap-8 lg:flex-row lg:items-start lg:justify-between">
            <div className="max-w-2xl">
              <p className="mb-3 text-[11px] font-semibold uppercase tracking-[0.35em] text-white/60">
                Unified Analytics
              </p>
              <h1 className="max-w-xl font-serif text-4xl leading-none tracking-tight sm:text-5xl">
                Your calendar facts and session reflections finally live on the same surface.
              </h1>
              <p className="mt-4 max-w-xl text-sm leading-6 text-white/72">
                {userSettings?.selectedCalendarName ? (
                  <>
                    Watching <span className="font-semibold text-white">{userSettings.selectedCalendarName}</span>, plus
                    reviewed focus sessions from the Mac app.
                  </>
                ) : (
                  <>Watching reviewed focus sessions and any synced calendar metrics that carry structured data.</>
                )}
              </p>
            </div>

            {heroActions ? <div className="flex items-center gap-3 self-start">{heroActions}</div> : null}
          </div>

          {hasMetrics ? (
            <div className="relative mt-8 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
              <HeroFactCard
                label="Strongest signal"
                value={strongestSignal ? titleForKey(strongestSignal[0]) : "—"}
                meta={strongestSignal ? `${formatScore(strongestSignal[1].avg)} average` : "No numeric metrics yet"}
              />
              <HeroFactCard
                label="Observation count"
                value={String(observationCount)}
                meta={`${numericEntries.length} numeric metrics active`}
              />
              <HeroFactCard
                label="Dominant lane"
                value={dominantCategory ? dominantCategory : "Mixed"}
                meta={preferredCategoricalKey ? titleForKey(preferredCategoricalKey) : "No category data"}
              />
              <HeroFactCard
                label="Recent rhythm"
                value={`${sessionMoments} session${sessionMoments === 1 ? "" : "s"}`}
                meta="In the latest activity strip"
              />
            </div>
          ) : null}
        </section>

        {!hasMetrics ? (
          <EmptyState />
        ) : (
          <>
            <CompositeStatRow
              compositeNow={compositeNow}
              compositeDelta={compositeDelta}
              currentStreak={currentStreak}
              totalHours={totalHours}
              observationCount={observationCount}
            />

            {dailyAggregates && dailyAggregates.length > 0 && (
              <ConsistencyHeatmap dailyAggregates={dailyAggregates} currentStreak={currentStreak} />
            )}

            <section className="grid gap-6 xl:grid-cols-[0.95fr_1.35fr]">
              <MetricSelectorRail
                metrics={numericEntries}
                selectedMetric={selectedMetric}
                onSelect={onSelectedMetricChange}
              />
              <MetricChartPanel
                metricKey={selectedMetric}
                stats={selectedMetric ? numericMetrics[selectedMetric] : undefined}
                metricWindowDays={metricWindowDays}
                onMetricWindowDaysChange={onMetricWindowDaysChange}
                timeSeries={metricTimeSeries}
              />
            </section>

            {weeklyComparison && (
              <section className="grid gap-6 xl:grid-cols-[1fr_1fr]">
                <RadarPanel summary={summary} weeklyComparison={weeklyComparison} />
                <WeekOverWeekPanel weeklyComparison={weeklyComparison} />
              </section>
            )}

            <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
              <CategoryFieldPanel
                metricKey={preferredCategoricalKey}
                stats={preferredCategoricalKey ? categoricalMetrics[preferredCategoricalKey] : undefined}
              />
              <RecentActivityFeed activity={(recentActivity || []) as RecentActivityItem[]} />
            </section>

            {dailyAggregates && dailyAggregates.length > 0 && (
              <SessionsPerDayChart dailyAggregates={dailyAggregates} />
            )}

            <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
              {numericEntries.slice(0, 4).map(([key, stats], index) => (
                <SignalStoryCard key={key} tone={HERO_TONES[index % HERO_TONES.length]} title={titleForKey(key)} stats={stats} />
              ))}
            </section>
          </>
        )}
      </div>
    </div>
  );
}

function HeroFactCard({ label, value, meta }: { label: string; value: string; meta: string }) {
  return (
    <div className="rounded-[24px] border border-white/15 bg-white/10 p-4 backdrop-blur-sm">
      <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-white/55">{label}</p>
      <p className="mt-3 text-2xl font-semibold text-white">{value}</p>
      <p className="mt-1 text-sm text-white/70">{meta}</p>
    </div>
  );
}

function MetricSelectorRail({
  metrics,
  selectedMetric,
  onSelect,
}: {
  metrics: Array<[string, NumericMetricStats]>;
  selectedMetric: string | null;
  onSelect: (value: string) => void;
}) {
  return (
    <Card className="rounded-[28px] border border-border/60 bg-card/85 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.55)] backdrop-blur">
      <CardHeader className="border-b border-border/60 pb-5">
        <CardDescription className="uppercase tracking-[0.22em]">Signal Atlas</CardDescription>
        <CardTitle className="font-serif text-2xl">Choose a signal to inspect</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3 pb-5 pt-5">
        {metrics.map(([key, stats]) => {
          const active = key === selectedMetric;
          const normalized = metricProgress(stats);

          return (
            <button
              key={key}
              type="button"
              onClick={() => onSelect(key)}
              className={cn(
                "w-full rounded-[24px] border px-4 py-4 text-left transition-all",
                active
                  ? "border-teal-500/60 bg-teal-500/10 shadow-[0_20px_45px_-30px_rgba(13,148,136,0.65)]"
                  : "border-border/70 bg-background/70 hover:border-teal-500/35 hover:bg-teal-500/[0.04]",
              )}
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-sm font-semibold">{titleForKey(key)}</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {stats.count} observations · {metricDescriptor(stats.avg)}
                  </p>
                </div>
                <span className="rounded-full bg-foreground/[0.05] px-2 py-1 text-xs font-semibold text-muted-foreground">
                  {formatScore(stats.avg)}
                </span>
              </div>

              <div className="mt-4 h-2 rounded-full bg-muted/80">
                <div
                  className="h-full rounded-full bg-[linear-gradient(90deg,_#0f766e,_#14b8a6)] transition-all"
                  style={{ width: `${Math.max(normalized * 100, 10)}%` }}
                />
              </div>

              <div className="mt-3 flex items-center justify-between text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
                <span>Min {formatScore(stats.min)}</span>
                <span>Max {formatScore(stats.max)}</span>
              </div>
            </button>
          );
        })}
      </CardContent>
    </Card>
  );
}

function MetricChartPanel({
  metricKey,
  stats,
  metricWindowDays,
  onMetricWindowDaysChange,
  timeSeries,
}: {
  metricKey: string | null;
  stats: NumericMetricStats | undefined;
  metricWindowDays: number;
  onMetricWindowDaysChange: (value: number) => void;
  timeSeries: MetricTimeSeriesPoint[] | undefined;
}) {
  return (
    <Card className="rounded-[28px] border border-border/60 bg-card/85 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.55)] backdrop-blur">
      <CardHeader className="border-b border-border/60 pb-5">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <CardDescription className="uppercase tracking-[0.22em]">Trend Reader</CardDescription>
            <CardTitle className="font-serif text-2xl">
              {metricKey ? `${titleForKey(metricKey)} over the last ${metricWindowDays} days` : "Pick a numeric metric"}
            </CardTitle>
            <CardDescription>
              {stats
                ? `${stats.count} observations, ranging from ${formatScore(stats.min)} to ${formatScore(stats.max)}.`
                : "The chart appears once a numeric metric is selected."}
            </CardDescription>
          </div>

          <WindowToggle value={metricWindowDays} onChange={onMetricWindowDaysChange} />
        </div>
      </CardHeader>
      <CardContent className="pb-5 pt-5">
        {!metricKey || !stats ? (
          <div className="flex h-[340px] items-center justify-center text-muted-foreground">
            No numeric metric selected yet.
          </div>
        ) : timeSeries === undefined ? (
          <Skeleton className="h-[340px] w-full rounded-[22px]" />
        ) : timeSeries.length === 0 ? (
          <div className="flex h-[340px] items-center justify-center text-muted-foreground">
            No time-series data for this signal yet.
          </div>
        ) : (
          <div className="space-y-5">
            <div className="grid gap-3 md:grid-cols-3">
              <StageFact label="Average" value={formatScore(stats.avg)} />
              <StageFact label="Min" value={formatScore(stats.min)} />
              <StageFact label="Max" value={formatScore(stats.max)} />
            </div>

            <div className="h-[320px] rounded-[24px] bg-[linear-gradient(180deg,_rgba(13,148,136,0.08),_rgba(13,148,136,0.02))] p-4">
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart
                  data={computeMovingAverage(
                    timeSeries.map((point) => ({ date: point.date, value: point.value })),
                    7,
                  ).map((point, i) => ({
                    date: new Date(point.date).toLocaleDateString("en-US", {
                      month: "short",
                      day: "numeric",
                    }),
                    fullDate: point.date,
                    value: point.value,
                    ma7: point.ma7,
                    title: timeSeries[i].subjectTitle,
                    source: timeSeries[i].subjectType === "intentSession" ? "Session" : "Event",
                  }))}
                >
                  <defs>
                    <linearGradient id="metricFieldGlow" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#0f766e" stopOpacity={0.35} />
                      <stop offset="95%" stopColor="#0f766e" stopOpacity={0.02} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="4 4" stroke="rgba(100,116,139,0.18)" />
                  <XAxis dataKey="date" tick={{ fill: CHART_MUTED_TEXT, fontSize: 12 }} tickLine={false} axisLine={false} />
                  <YAxis domain={[0, 10]} tick={{ fill: CHART_MUTED_TEXT, fontSize: 12 }} tickLine={false} axisLine={false} />
                  <ReferenceLine y={stats.avg} stroke="rgba(148,163,184,0.35)" strokeDasharray="6 3" label={{ value: `avg ${formatScore(stats.avg)}`, fill: CHART_MUTED_TEXT, fontSize: 11, position: "insideTopRight" }} />
                  <Tooltip
                    cursor={{ stroke: "rgba(15,118,110,0.25)", strokeWidth: 1.5 }}
                    contentStyle={{
                      background: "rgba(15,23,42,0.96)",
                      border: "1px solid rgba(148,163,184,0.18)",
                      borderRadius: "18px",
                      color: "white",
                    }}
                    formatter={(value, name) => [value, name === "ma7" ? "7-pt avg" : titleForKey(metricKey)]}
                    labelFormatter={(_, payload) => {
                      const point = payload?.[0]?.payload as
                        | { title?: string; source?: string; fullDate?: number }
                        | undefined;
                      if (!point) return "";
                      return `${point.title} · ${point.source}`;
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="value"
                    stroke="#0f766e"
                    strokeWidth={2}
                    fill="url(#metricFieldGlow)"
                    activeDot={{ r: 5, fill: "#0f766e", stroke: "#f8fafc", strokeWidth: 2 }}
                    dot={false}
                  />
                  <Line
                    type="monotone"
                    dataKey="ma7"
                    stroke="#ea580c"
                    strokeWidth={2.5}
                    dot={false}
                    strokeDasharray="0"
                    activeDot={{ r: 4, fill: "#ea580c", stroke: "#f8fafc", strokeWidth: 2 }}
                  />
                </ComposedChart>
              </ResponsiveContainer>
            </div>

            <div className="flex items-center gap-4 px-1 text-xs text-muted-foreground">
              <span className="flex items-center gap-1.5">
                <span className="inline-block h-2.5 w-5 rounded-sm bg-teal-600/70" />
                Raw values
              </span>
              <span className="flex items-center gap-1.5">
                <span className="inline-block h-0.5 w-5 bg-orange-500" />
                7-point moving avg
              </span>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function CategoryFieldPanel({
  metricKey,
  stats,
}: {
  metricKey: string | null;
  stats: CategoricalMetricStats | undefined;
}) {
  const values = stats
    ? Object.entries(stats.valueCounts)
        .sort((left, right) => {
          if (left[1] === right[1]) {
            return left[0].localeCompare(right[0]);
          }
          return right[1] - left[1];
        })
        .slice(0, 6)
        .map(([value, count]) => ({
          value,
          count,
        }))
    : [];

  return (
    <Card className="rounded-[28px] border border-border/60 bg-card/85 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.55)] backdrop-blur">
      <CardHeader className="border-b border-border/60 pb-5">
        <CardDescription className="uppercase tracking-[0.22em]">Category Field</CardDescription>
        <CardTitle className="font-serif text-2xl">
          {metricKey ? titleForKey(metricKey) : "No categorical metric yet"}
        </CardTitle>
        <CardDescription>
          {stats ? `${stats.count} observations with ${Object.keys(stats.valueCounts).length} unique values.` : "Once string or boolean metrics accumulate, this panel shows how the mix is shifting."}
        </CardDescription>
      </CardHeader>
      <CardContent className="pb-5 pt-5">
        {!stats || values.length === 0 ? (
          <div className="flex h-[320px] items-center justify-center text-muted-foreground">
            No categorical signal available yet.
          </div>
        ) : (
          <div className="grid gap-5 lg:grid-cols-[1.05fr_0.95fr]">
            <div className="h-[320px] rounded-[24px] bg-[linear-gradient(180deg,_rgba(249,115,22,0.08),_rgba(249,115,22,0.02))] p-4">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={values}
                  layout="vertical"
                  margin={{ left: 10, right: 10, top: 10, bottom: 10 }}
                >
                  <CartesianGrid strokeDasharray="4 4" stroke="rgba(100,116,139,0.18)" horizontal={false} />
                  <XAxis type="number" tick={{ fill: CHART_MUTED_TEXT, fontSize: 12 }} tickLine={false} axisLine={false} />
                  <YAxis
                    type="category"
                    dataKey="value"
                    width={110}
                    tick={{ fill: CHART_TEXT, fontSize: 12 }}
                    tickLine={false}
                    axisLine={false}
                  />
                  <Tooltip
                    cursor={{ fill: "rgba(249,115,22,0.08)" }}
                    contentStyle={{
                      background: "rgba(15,23,42,0.96)",
                      border: "1px solid rgba(148,163,184,0.18)",
                      borderRadius: "18px",
                      color: "white",
                    }}
                  />
                  <Bar dataKey="count" radius={[0, 10, 10, 0]}>
                    {values.map((entry, index) => (
                      <Cell key={entry.value} fill={HERO_TONES[index % HERO_TONES.length]} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>

            <div className="space-y-3">
              {values.map((entry, index) => {
                const share = stats.count > 0 ? Math.round((entry.count / stats.count) * 100) : 0;
                return (
                  <div key={entry.value} className="rounded-[22px] border border-border/70 bg-background/65 p-4">
                    <div className="flex items-center justify-between gap-3">
                      <p className="font-medium">{entry.value}</p>
                      <span className="rounded-full px-2 py-1 text-xs font-semibold text-white" style={{ backgroundColor: HERO_TONES[index % HERO_TONES.length] }}>
                        {entry.count}
                      </span>
                    </div>
                    <div className="mt-3 h-2 rounded-full bg-muted/80">
                      <div
                        className="h-full rounded-full"
                        style={{
                          width: `${Math.max(share, 8)}%`,
                          backgroundColor: HERO_TONES[index % HERO_TONES.length],
                        }}
                      />
                    </div>
                    <p className="mt-2 text-xs uppercase tracking-[0.18em] text-muted-foreground">{share}% of observations</p>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function SignalStoryCard({
  tone,
  title,
  stats,
}: {
  tone: string;
  title: string;
  stats: NumericMetricStats;
}) {
  return (
    <Card className="rounded-[26px] border border-border/60 bg-card/80 shadow-[0_18px_50px_-40px_rgba(15,23,42,0.65)] backdrop-blur">
      <CardHeader>
        <CardDescription className="uppercase tracking-[0.22em]">{title}</CardDescription>
        <CardTitle className="font-serif text-4xl" style={{ color: tone }}>
          {formatScore(stats.avg)}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="h-2 rounded-full bg-muted/70">
          <div
            className="h-full rounded-full"
            style={{ width: `${Math.max(metricProgress(stats) * 100, 10)}%`, backgroundColor: tone }}
          />
        </div>
        <div className="flex items-center justify-between text-xs uppercase tracking-[0.18em] text-muted-foreground">
          <span>{stats.count} pts</span>
          <span>{metricDescriptor(stats.avg)}</span>
        </div>
      </CardContent>
    </Card>
  );
}

function RecentActivityFeed({ activity }: { activity: RecentActivityItem[] }) {
  return (
    <Card className="rounded-[28px] border border-border/60 bg-card/85 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.55)] backdrop-blur">
      <CardHeader className="border-b border-border/60 pb-5">
        <CardDescription className="uppercase tracking-[0.22em]">Recent Activity</CardDescription>
        <CardTitle className="font-serif text-2xl">The latest tracked subjects</CardTitle>
        <CardDescription>Events and reviewed sessions share the same feed now, with source badges preserved.</CardDescription>
      </CardHeader>
      <CardContent className="pb-5 pt-5">
        {activity.length === 0 ? (
          <div className="flex h-[320px] items-center justify-center text-muted-foreground">
            No tracked activity yet.
          </div>
        ) : (
          <div className="space-y-4">
            {activity.map((item) => (
              <div
                key={item.id}
                className="rounded-[24px] border border-border/65 bg-background/70 p-4 transition-colors hover:border-teal-500/30 hover:bg-background"
              >
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <h4 className="font-medium">{item.title}</h4>
                      <span
                        className={cn(
                          "rounded-full px-2 py-1 text-[10px] font-semibold uppercase tracking-[0.2em]",
                          item.subjectType === "intentSession"
                            ? "bg-teal-500/10 text-teal-700 dark:text-teal-300"
                            : "bg-orange-500/10 text-orange-700 dark:text-orange-300",
                        )}
                      >
                        {item.subjectType === "intentSession" ? "Session" : "Event"}
                      </span>
                    </div>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {new Date(item.date).toLocaleDateString("en-US", {
                        weekday: "short",
                        month: "short",
                        day: "numeric",
                        hour: "numeric",
                        minute: "2-digit",
                      })}
                    </p>
                  </div>
                </div>

                <div className="mt-4 flex flex-wrap gap-2">
                  {item.metrics.map((metric) => (
                    <span
                      key={`${item.id}:${metric.key}`}
                      className="rounded-full border border-border/60 bg-muted/60 px-3 py-1 text-xs font-medium text-foreground/85"
                    >
                      {titleForKey(metric.key)}: {formatMetricValue(metric.value)}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function CompositeStatRow({
  compositeNow,
  compositeDelta,
  currentStreak,
  totalHours,
  observationCount,
}: {
  compositeNow: number | null;
  compositeDelta: number | null;
  currentStreak: number;
  totalHours: number;
  observationCount: number;
}) {
  const deltaColor =
    compositeDelta === null ? "text-muted-foreground" : compositeDelta > 0 ? "text-teal-400" : compositeDelta < 0 ? "text-red-400" : "text-muted-foreground";
  const deltaLabel =
    compositeDelta === null
      ? "no prior week data"
      : `${compositeDelta > 0 ? "+" : ""}${formatScore(compositeDelta)} vs last week`;

  return (
    <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <div className="rounded-[26px] border border-border/60 bg-card/80 p-5 shadow-[0_18px_50px_-40px_rgba(15,23,42,0.65)] backdrop-blur">
        <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-muted-foreground">Composite Score</p>
        <p className="mt-3 font-serif text-4xl font-semibold" style={{ color: "#0f766e" }}>
          {compositeNow !== null ? formatScore(compositeNow) : "—"}
        </p>
        <p className={cn("mt-1 text-sm font-medium", deltaColor)}>{deltaLabel}</p>
        <p className="mt-1 text-xs text-muted-foreground">avg of 6 core metrics</p>
      </div>

      <div className="rounded-[26px] border border-border/60 bg-card/80 p-5 shadow-[0_18px_50px_-40px_rgba(15,23,42,0.65)] backdrop-blur">
        <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-muted-foreground">Current Streak</p>
        <p className="mt-3 font-serif text-4xl font-semibold" style={{ color: currentStreak >= 7 ? "#0f766e" : currentStreak >= 3 ? "#d97706" : "#6b7280" }}>
          {currentStreak}
        </p>
        <p className="mt-1 text-sm text-muted-foreground">
          {currentStreak === 0
            ? "No active streak — log a session!"
            : currentStreak === 1
              ? "day in a row"
              : `days in a row`}
        </p>
        <div className="mt-2 flex gap-1">
          {Array.from({ length: 7 }).map((_, i) => (
            <div
              key={i}
              className={cn("h-1.5 flex-1 rounded-full", i < Math.min(currentStreak, 7) ? "bg-teal-500" : "bg-muted/60")}
            />
          ))}
        </div>
      </div>

      <div className="rounded-[26px] border border-border/60 bg-card/80 p-5 shadow-[0_18px_50px_-40px_rgba(15,23,42,0.65)] backdrop-blur">
        <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-muted-foreground">Hours Tracked</p>
        <p className="mt-3 font-serif text-4xl font-semibold" style={{ color: "#ea580c" }}>
          {totalHours > 0 ? `${totalHours}h` : "—"}
        </p>
        <p className="mt-1 text-sm text-muted-foreground">across all reviewed sessions</p>
        <p className="mt-1 text-xs text-muted-foreground">last 91 days</p>
      </div>

      <div className="rounded-[26px] border border-border/60 bg-card/80 p-5 shadow-[0_18px_50px_-40px_rgba(15,23,42,0.65)] backdrop-blur">
        <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-muted-foreground">Total Observations</p>
        <p className="mt-3 font-serif text-4xl font-semibold" style={{ color: "#7c3aed" }}>
          {observationCount}
        </p>
        <p className="mt-1 text-sm text-muted-foreground">data points collected</p>
        <p className="mt-1 text-xs text-muted-foreground">always growing</p>
      </div>
    </section>
  );
}

function ConsistencyHeatmap({
  dailyAggregates,
  currentStreak,
}: {
  dailyAggregates: DailyAggregate[];
  currentStreak: number;
}) {
  const dataMap = new Map(dailyAggregates.map((d) => [d.dateStr, d]));

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Start 12 weeks (84 days) back, snapped to Monday
  const startDate = new Date(today);
  startDate.setDate(today.getDate() - 84);
  const startDow = startDate.getDay();
  const daysBackToMonday = startDow === 0 ? 6 : startDow - 1;
  startDate.setDate(startDate.getDate() - daysBackToMonday);

  const cells: { date: Date; dateStr: string; data: DailyAggregate | undefined }[] = [];
  const cur = new Date(startDate);
  while (cur <= today) {
    const dateStr = cur.toISOString().slice(0, 10);
    cells.push({ date: new Date(cur), dateStr, data: dataMap.get(dateStr) });
    cur.setDate(cur.getDate() + 1);
  }

  // Pad to full weeks
  while (cells.length % 7 !== 0) {
    const next = new Date(cells[cells.length - 1].date);
    next.setDate(next.getDate() + 1);
    cells.push({ date: next, dateStr: next.toISOString().slice(0, 10), data: undefined });
  }

  const weeks: typeof cells[] = [];
  for (let i = 0; i < cells.length; i += 7) {
    weeks.push(cells.slice(i, i + 7));
  }

  const totalSessions = dailyAggregates.reduce((s, d) => s + d.sessionCount, 0);
  const activeDays = dailyAggregates.filter((d) => d.sessionCount > 0).length;

  const MONTH_LABELS: string[] = [];
  let lastMonth = -1;
  for (const week of weeks) {
    const mon = week[0].date.getUTCMonth();
    if (mon !== lastMonth) {
      MONTH_LABELS.push(week[0].date.toLocaleDateString("en-US", { month: "short" }));
      lastMonth = mon;
    } else {
      MONTH_LABELS.push("");
    }
  }

  return (
    <Card className="rounded-[28px] border border-border/60 bg-card/85 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.55)] backdrop-blur">
      <CardHeader className="border-b border-border/60 pb-5">
        <CardDescription className="uppercase tracking-[0.22em]">Consistency Calendar</CardDescription>
        <CardTitle className="font-serif text-2xl">
          {currentStreak > 0 ? `${currentStreak}-day streak — keep it going!` : "Build your streak"}
        </CardTitle>
        <CardDescription>
          {activeDays} active days · {totalSessions} sessions reviewed · darker = higher composite score
        </CardDescription>
      </CardHeader>
      <CardContent className="overflow-x-auto pb-5 pt-5">
        <div className="inline-flex flex-col gap-1">
          <div className="flex gap-1 pl-7">
            {MONTH_LABELS.map((label, i) => (
              <div key={i} className="w-[18px] text-[10px] text-muted-foreground">{label}</div>
            ))}
          </div>
          <div className="flex gap-1">
            <div className="flex flex-col justify-around gap-1 pr-2">
              {["M", "T", "W", "T", "F", "S", "S"].map((d, i) => (
                <div key={i} className="flex h-[18px] items-center text-[10px] text-muted-foreground">{d}</div>
              ))}
            </div>
            {weeks.map((week, wi) => (
              <div key={wi} className="flex flex-col gap-1">
                {week.map((cell) => {
                  const isFuture = cell.date > today;
                  return (
                    <div
                      key={cell.dateStr}
                      className={cn(
                        "h-[18px] w-[18px] rounded-[3px] transition-all",
                        isFuture ? "bg-transparent" : heatmapCellClass(cell.data),
                      )}
                      title={
                        isFuture
                          ? ""
                          : cell.data
                            ? `${cell.dateStr}: ${cell.data.sessionCount} session${cell.data.sessionCount !== 1 ? "s" : ""}, score ${cell.data.compositeScore}`
                            : `${cell.dateStr}: no sessions`
                      }
                    />
                  );
                })}
              </div>
            ))}
          </div>
        </div>

        <div className="mt-4 flex items-center gap-3">
          <span className="text-[11px] text-muted-foreground">Less</span>
          {["bg-muted/30", "bg-red-400/60", "bg-amber-500/60", "bg-teal-500/70", "bg-teal-500"].map((cls, i) => (
            <div key={i} className={cn("h-[14px] w-[14px] rounded-[2px]", cls)} />
          ))}
          <span className="text-[11px] text-muted-foreground">More</span>
        </div>
      </CardContent>
    </Card>
  );
}

function RadarPanel({
  summary,
  weeklyComparison,
}: {
  summary: DashboardMetricsSummary;
  weeklyComparison: WeeklyComparison;
}) {
  const radarData = CORE_METRICS.filter(
    (key) => summary.numeric[key] || weeklyComparison.thisWeek[key] || weeklyComparison.lastWeek[key],
  ).map((key) => ({
    metric: titleForKey(key),
    thisWeek: Math.round((weeklyComparison.thisWeek[key] ?? 0) * 10) / 10,
    lastWeek: Math.round((weeklyComparison.lastWeek[key] ?? 0) * 10) / 10,
    allTime: Math.round((summary.numeric[key]?.avg ?? 0) * 10) / 10,
  }));

  const hasThisWeek = Object.keys(weeklyComparison.thisWeek).length > 0;
  const hasLastWeek = Object.keys(weeklyComparison.lastWeek).length > 0;

  return (
    <Card className="rounded-[28px] border border-border/60 bg-card/85 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.55)] backdrop-blur">
      <CardHeader className="border-b border-border/60 pb-5">
        <CardDescription className="uppercase tracking-[0.22em]">Metric Radar</CardDescription>
        <CardTitle className="font-serif text-2xl">All metrics at a glance</CardTitle>
        <CardDescription>
          {hasLastWeek ? "This week (teal) vs last week (orange)" : "Your metric profile across all tracked time"}
        </CardDescription>
      </CardHeader>
      <CardContent className="pb-5 pt-5">
        {radarData.length === 0 ? (
          <div className="flex h-[340px] items-center justify-center text-muted-foreground">
            Not enough data for radar view yet.
          </div>
        ) : (
          <div className="h-[340px]">
            <ResponsiveContainer width="100%" height="100%">
              <RadarChart data={radarData} margin={{ top: 10, right: 30, bottom: 10, left: 30 }}>
                <PolarGrid stroke="rgba(100,116,139,0.2)" />
                <PolarAngleAxis
                  dataKey="metric"
                  tick={{ fill: CHART_TEXT, fontSize: 12, fontWeight: 600 }}
                />
                <PolarRadiusAxis
                  domain={[0, 10]}
                  tick={{ fill: CHART_MUTED_TEXT, fontSize: 10 }}
                  axisLine={false}
                  tickCount={3}
                />
                {hasLastWeek && (
                  <Radar
                    name="Last Week"
                    dataKey="lastWeek"
                    stroke="#ea580c"
                    fill="#ea580c"
                    fillOpacity={0.1}
                    strokeWidth={1.5}
                    strokeDasharray="4 3"
                  />
                )}
                <Radar
                  name={hasThisWeek ? "This Week" : "All Time"}
                  dataKey={hasThisWeek ? "thisWeek" : "allTime"}
                  stroke="#0f766e"
                  fill="#0f766e"
                  fillOpacity={0.25}
                  strokeWidth={2.5}
                />
                <Legend
                  wrapperStyle={{ fontSize: "12px", paddingTop: "8px" }}
                  iconType="circle"
                  iconSize={8}
                />
                <Tooltip
                  contentStyle={{
                    background: "rgba(15,23,42,0.96)",
                    border: "1px solid rgba(148,163,184,0.18)",
                    borderRadius: "14px",
                    color: "white",
                    fontSize: "13px",
                  }}
                />
              </RadarChart>
            </ResponsiveContainer>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function WeekOverWeekPanel({ weeklyComparison }: { weeklyComparison: WeeklyComparison }) {
  const { thisWeek, lastWeek } = weeklyComparison;
  const allKeys = [...new Set([...Object.keys(thisWeek), ...Object.keys(lastWeek)])].sort();

  const barData = allKeys.map((key) => ({
    metric: titleForKey(key).slice(0, 10),
    fullName: titleForKey(key),
    thisWeek: thisWeek[key] ?? 0,
    lastWeek: lastWeek[key] ?? 0,
  }));

  const deltaCards = allKeys.map((key) => {
    const curr = thisWeek[key] ?? null;
    const prev = lastWeek[key] ?? null;
    const delta = curr !== null && prev !== null ? Math.round((curr - prev) * 10) / 10 : null;
    return { key, curr, prev, delta };
  });

  const hasThisWeek = Object.keys(thisWeek).length > 0;

  return (
    <Card className="rounded-[28px] border border-border/60 bg-card/85 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.55)] backdrop-blur">
      <CardHeader className="border-b border-border/60 pb-5">
        <CardDescription className="uppercase tracking-[0.22em]">Week Over Week</CardDescription>
        <CardTitle className="font-serif text-2xl">
          {hasThisWeek ? "Are you improving?" : "No data this week yet"}
        </CardTitle>
        <CardDescription>
          {hasThisWeek
            ? "Current week average vs previous week. Green = improving."
            : "Log sessions this week to see your progress vs last week."}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4 pb-5 pt-5">
        {!hasThisWeek ? (
          <div className="flex h-[300px] items-center justify-center text-muted-foreground">
            Keep logging — your trend will appear here.
          </div>
        ) : (
          <>
            <div className="h-[180px] rounded-[20px] bg-[linear-gradient(180deg,_rgba(13,148,136,0.06),_rgba(13,148,136,0.01))] p-3">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={barData} barGap={2} barCategoryGap="25%">
                  <CartesianGrid strokeDasharray="4 4" stroke="rgba(100,116,139,0.12)" vertical={false} />
                  <XAxis dataKey="metric" tick={{ fill: CHART_TEXT, fontSize: 10, fontWeight: 600 }} tickLine={false} axisLine={false} />
                  <YAxis domain={[0, 10]} tick={{ fill: CHART_MUTED_TEXT, fontSize: 10 }} tickLine={false} axisLine={false} width={22} />
                  <Tooltip
                    contentStyle={{
                      background: "rgba(15,23,42,0.96)",
                      border: "1px solid rgba(148,163,184,0.18)",
                      borderRadius: "14px",
                      color: "white",
                      fontSize: "12px",
                    }}
                    formatter={(value, name) => [value, name === "thisWeek" ? "This week" : "Last week"]}
                    labelFormatter={(_, payload) => payload?.[0]?.payload?.fullName ?? ""}
                  />
                  <Bar dataKey="lastWeek" fill="#ea580c" fillOpacity={0.4} radius={[4, 4, 0, 0]} name="lastWeek" />
                  <Bar dataKey="thisWeek" fill="#0f766e" fillOpacity={0.85} radius={[4, 4, 0, 0]} name="thisWeek" />
                </BarChart>
              </ResponsiveContainer>
            </div>

            <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
              {deltaCards.map(({ key, curr, prev, delta }) => {
                const isPositive = delta !== null && delta > 0;
                const isNegative = delta !== null && delta < 0;
                const metricColor = METRIC_COLORS[key] ?? "#6b7280";
                return (
                  <div
                    key={key}
                    className="rounded-[18px] border border-border/60 bg-background/70 p-3"
                  >
                    <div className="flex items-center justify-between">
                      <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
                        {titleForKey(key).slice(0, 12)}
                      </p>
                      {delta !== null && (
                        <span
                          className={cn(
                            "text-xs font-bold",
                            isPositive ? "text-teal-500" : isNegative ? "text-red-400" : "text-muted-foreground",
                          )}
                        >
                          {isPositive ? "+" : ""}{formatScore(delta)}
                        </span>
                      )}
                    </div>
                    <div className="mt-2 flex items-baseline gap-1">
                      {prev !== null && (
                        <span className="text-xs text-muted-foreground line-through">{formatScore(prev)}</span>
                      )}
                      <span className="text-lg font-semibold" style={{ color: metricColor }}>
                        {curr !== null ? formatScore(curr) : "—"}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </CardContent>
    </Card>
  );
}

function SessionsPerDayChart({ dailyAggregates }: { dailyAggregates: DailyAggregate[] }) {
  const recent = [...dailyAggregates].slice(-30);

  const data = recent.map((d) => ({
    date: new Date(d.dateStr + "T12:00:00Z").toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
    }),
    fullDate: d.dateStr,
    sessions: d.sessionCount,
    score: d.compositeScore,
    hours: d.totalHours,
  }));

  const maxSessions = Math.max(...data.map((d) => d.sessions), 1);

  return (
    <Card className="rounded-[28px] border border-border/60 bg-card/85 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.55)] backdrop-blur">
      <CardHeader className="border-b border-border/60 pb-5">
        <CardDescription className="uppercase tracking-[0.22em]">Logging Momentum</CardDescription>
        <CardTitle className="font-serif text-2xl">Sessions logged per day</CardTitle>
        <CardDescription>
          Every gap is a day you can reclaim. Color intensity shows your composite score that day.
        </CardDescription>
      </CardHeader>
      <CardContent className="pb-5 pt-5">
        <div className="h-[220px] rounded-[24px] bg-[linear-gradient(180deg,_rgba(37,99,235,0.06),_rgba(37,99,235,0.01))] p-4">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} barCategoryGap="20%">
              <CartesianGrid strokeDasharray="4 4" stroke="rgba(100,116,139,0.15)" vertical={false} />
              <XAxis
                dataKey="date"
                tick={{ fill: CHART_MUTED_TEXT, fontSize: 11 }}
                tickLine={false}
                axisLine={false}
                interval={Math.ceil(data.length / 10)}
              />
              <YAxis
                allowDecimals={false}
                domain={[0, maxSessions + 1]}
                tick={{ fill: CHART_MUTED_TEXT, fontSize: 11 }}
                tickLine={false}
                axisLine={false}
                width={24}
              />
              <Tooltip
                cursor={{ fill: "rgba(37,99,235,0.06)" }}
                contentStyle={{
                  background: "rgba(15,23,42,0.96)",
                  border: "1px solid rgba(148,163,184,0.18)",
                  borderRadius: "14px",
                  color: "white",
                  fontSize: "12px",
                }}
                formatter={(value, name) =>
                  name === "sessions"
                    ? [`${value} session${Number(value) !== 1 ? "s" : ""}`, "Logged"]
                    : [value, "Composite score"]
                }
                labelFormatter={(_, payload) => payload?.[0]?.payload?.fullDate ?? ""}
              />
              <Bar dataKey="sessions" radius={[5, 5, 0, 0]}>
                {data.map((entry, index) => {
                  const score = entry.score;
                  const color =
                    entry.sessions === 0
                      ? "rgba(100,116,139,0.12)"
                      : score >= 8
                        ? "#0f766e"
                        : score >= 6.5
                          ? "#14b8a6"
                          : score >= 5
                            ? "#d97706"
                            : score > 0
                              ? "#f87171"
                              : "#0f766e";
                  return <Cell key={index} fill={color} />;
                })}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-4 text-[11px] text-muted-foreground">
          {[
            { color: "#0f766e", label: "Score 8+" },
            { color: "#14b8a6", label: "Score 6.5+" },
            { color: "#d97706", label: "Score 5+" },
            { color: "#f87171", label: "Score < 5" },
            { color: "rgba(100,116,139,0.25)", label: "No sessions" },
          ].map(({ color, label }) => (
            <span key={label} className="flex items-center gap-1.5">
              <span className="inline-block h-3 w-3 rounded-[2px]" style={{ backgroundColor: color }} />
              {label}
            </span>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

function EmptyState() {
  return (
    <Card className="rounded-[32px] border border-dashed border-border/80 bg-card/80 shadow-[0_24px_70px_-45px_rgba(15,23,42,0.6)] backdrop-blur">
      <CardContent className="flex flex-col items-center justify-center py-20">
        <div className="mb-6 rounded-full border border-border/70 bg-[radial-gradient(circle,_rgba(13,148,136,0.18),_transparent_70%)] px-6 py-6">
          <div className="h-16 w-16 rounded-full border border-teal-500/30 bg-teal-500/10" />
        </div>
        <h3 className="font-serif text-3xl">No unified analytics yet</h3>
        <p className="mt-3 max-w-xl text-center text-sm leading-6 text-muted-foreground">
          Sync a calendar with structured YAML metadata, or review a few focus sessions in the Mac app.
          This dashboard is waiting for either source to start drawing patterns.
        </p>
        <div className="mt-8 rounded-[24px] border border-border/70 bg-background/70 p-4 font-mono text-sm text-muted-foreground">
          <pre>{`focus: 8
energy: 7
taskCategory: engineering
whatWentWell: Shipped the sync fix
whatDidntGoWell: Drifted into side cleanup twice`}</pre>
        </div>
      </CardContent>
    </Card>
  );
}

function StageFact({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[20px] border border-border/65 bg-background/75 p-4">
      <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-muted-foreground">{label}</p>
      <p className="mt-2 text-2xl font-semibold">{value}</p>
    </div>
  );
}

function WindowToggle({
  value,
  onChange,
}: {
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <div className="inline-flex rounded-full border border-border/70 bg-background/70 p-1">
      {[14, 30, 90].map((option) => (
        <button
          key={option}
          type="button"
          onClick={() => onChange(option)}
          className={cn(
            "rounded-full px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] transition-colors",
            value === option
              ? "bg-teal-600 text-white"
              : "text-muted-foreground hover:text-foreground",
          )}
        >
          {option}d
        </button>
      ))}
    </div>
  );
}

function SyncButton() {
  const sync = useAction(api.calendar.syncEvents);
  const [loading, setLoading] = useState(false);

  const handleSync = async () => {
    setLoading(true);
    try {
      const result = await sync({});
      toast.success(`Synced ${result.count} events from ${result.calendarId}!`);
    } catch (error: any) {
      toast.error(error.message || "Failed to sync events");
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Button onClick={handleSync} disabled={loading} variant="outline" className="border-white/20 bg-white/10 text-white hover:bg-white/15 hover:text-white">
      {loading ? "Syncing..." : "Sync Now"}
    </Button>
  );
}

function titleForKey(key: string) {
  return key
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function metricProgress(stats: NumericMetricStats) {
  if (stats.max <= 10 && stats.min >= 0) {
    return Math.min(stats.avg / 10, 1);
  }

  if (stats.max === 0) {
    return 0;
  }

  return Math.min(stats.avg / stats.max, 1);
}

function metricDescriptor(value: number) {
  if (value >= 8) {
    return "Locked in";
  }

  if (value >= 6.5) {
    return "Strong";
  }

  if (value >= 5) {
    return "Mixed";
  }

  return "Fragile";
}

function formatScore(value: number) {
  return Number.isInteger(value) ? String(value) : value.toFixed(1);
}

function formatMetricValue(value: number | boolean | string) {
  if (typeof value === "boolean") {
    return value ? "Yes" : "No";
  }

  if (typeof value === "number") {
    return formatScore(value);
  }

  return value;
}
