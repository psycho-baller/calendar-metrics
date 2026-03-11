import { api } from "@calendar-metrics/backend/convex/_generated/api";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Authenticated, AuthLoading, Unauthenticated, useAction, useQuery } from "convex/react";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
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

type NumericMetricStats = {
  count: number;
  avg: number;
  min: number;
  max: number;
};

type CategoricalMetricStats = {
  count: number;
  valueCounts: Record<string, number>;
  topValue: string;
};

type DashboardMetricsSummary = {
  numeric: Record<string, NumericMetricStats>;
  categorical: Record<string, CategoricalMetricStats>;
};

type RecentActivityItem = {
  id: string;
  title: string;
  date: number;
  subjectType: "event" | "intentSession";
  metrics: Array<{ key: string; value: number | boolean | string }>;
};

type MetricTimeSeriesPoint = {
  date: number;
  value: number;
  subjectTitle: string;
  subjectType: "event" | "intentSession";
};

const HERO_TONES = ["#0f766e", "#ea580c", "#2563eb", "#be185d", "#7c3aed"];

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
  const [selectedMetric, setSelectedMetric] = useState<string | null>(null);
  const [metricWindowDays, setMetricWindowDays] = useState(30);

  useEffect(() => {
    if (userSettings !== undefined && !userSettings?.onboardingCompleted) {
      navigate({ to: "/onboarding" });
    }
  }, [navigate, userSettings]);

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
      setSelectedMetric(availableNumericKeys[0]);
    }
  }, [availableNumericKeys, selectedMetric]);

  useEffect(() => {
    if (selectedMetric && !numericMetrics[selectedMetric] && availableNumericKeys.length > 0) {
      setSelectedMetric(availableNumericKeys[0]);
    }
  }, [availableNumericKeys, numericMetrics, selectedMetric]);

  if (userSettings === undefined) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="animate-pulse text-muted-foreground">Loading...</div>
      </div>
    );
  }

  const hasMetrics = numericEntries.length > 0 || categoricalEntries.length > 0;
  const strongestSignal = numericEntries[0];
  const dominantCategory = preferredCategoricalKey
    ? categoricalMetrics[preferredCategoricalKey]?.topValue
    : null;
  const sessionMoments = ((recentActivity || []) as RecentActivityItem[]).filter(
    (item) => item.subjectType === "intentSession",
  ).length;
  const observationCount = numericEntries.reduce((sum, [, stats]) => sum + stats.count, 0);

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

            <div className="flex items-center gap-3 self-start">
              <SyncButton />
              <UserMenu />
            </div>
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
            <section className="grid gap-6 xl:grid-cols-[0.95fr_1.35fr]">
              <MetricSelectorRail
                metrics={numericEntries}
                selectedMetric={selectedMetric}
                onSelect={setSelectedMetric}
              />
              <MetricChartPanel
                metricKey={selectedMetric}
                stats={selectedMetric ? numericMetrics[selectedMetric] : undefined}
                metricWindowDays={metricWindowDays}
                onMetricWindowDaysChange={setMetricWindowDays}
              />
            </section>

            <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
              <CategoryFieldPanel
                metricKey={preferredCategoricalKey}
                stats={preferredCategoricalKey ? categoricalMetrics[preferredCategoricalKey] : undefined}
              />
              <RecentActivityFeed activity={(recentActivity || []) as RecentActivityItem[]} />
            </section>

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
}: {
  metricKey: string | null;
  stats: NumericMetricStats | undefined;
  metricWindowDays: number;
  onMetricWindowDaysChange: (value: number) => void;
}) {
  const timeSeries = useQuery(
    api.analytics.getMetricTimeSeries,
    metricKey
      ? {
          key: metricKey,
          days: metricWindowDays,
        }
      : "skip",
  ) as MetricTimeSeriesPoint[] | undefined;

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
                <AreaChart
                  data={timeSeries.map((point) => ({
                    date: new Date(point.date).toLocaleDateString("en-US", {
                      month: "short",
                      day: "numeric",
                    }),
                    fullDate: point.date,
                    value: point.value,
                    title: point.subjectTitle,
                    source: point.subjectType === "intentSession" ? "Session" : "Event",
                  }))}
                >
                  <defs>
                    <linearGradient id="metricFieldGlow" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#0f766e" stopOpacity={0.35} />
                      <stop offset="95%" stopColor="#0f766e" stopOpacity={0.02} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="4 4" stroke="rgba(100,116,139,0.18)" />
                  <XAxis dataKey="date" tick={{ fill: "hsl(var(--muted-foreground))", fontSize: 12 }} tickLine={false} axisLine={false} />
                  <YAxis tick={{ fill: "hsl(var(--muted-foreground))", fontSize: 12 }} tickLine={false} axisLine={false} />
                  <Tooltip
                    cursor={{ stroke: "rgba(15,118,110,0.25)", strokeWidth: 1.5 }}
                    contentStyle={{
                      background: "rgba(15,23,42,0.96)",
                      border: "1px solid rgba(148,163,184,0.18)",
                      borderRadius: "18px",
                      color: "white",
                    }}
                    formatter={(value) => [value, titleForKey(metricKey)]}
                    labelFormatter={(_, payload) => {
                      const point = payload?.[0]?.payload as
                        | { title?: string; source?: string; fullDate?: number }
                        | undefined;
                      if (!point) {
                        return "";
                      }

                      return `${point.title} · ${point.source}`;
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="value"
                    stroke="#0f766e"
                    strokeWidth={3}
                    fill="url(#metricFieldGlow)"
                    activeDot={{ r: 6, fill: "#0f766e", stroke: "#f8fafc", strokeWidth: 2 }}
                  />
                </AreaChart>
              </ResponsiveContainer>
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
                  <XAxis type="number" tick={{ fill: "hsl(var(--muted-foreground))", fontSize: 12 }} tickLine={false} axisLine={false} />
                  <YAxis
                    type="category"
                    dataKey="value"
                    width={110}
                    tick={{ fill: "hsl(var(--foreground))", fontSize: 12 }}
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
