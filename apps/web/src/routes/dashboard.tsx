import { api } from "@calendar-metrics/backend/convex/_generated/api";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Authenticated, AuthLoading, Unauthenticated, useAction, useQuery } from "convex/react";
import { useState, useEffect } from "react";
import { toast } from "sonner";
import {
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
} from "recharts";

import SignInForm from "@/components/sign-in-form";
import SignUpForm from "@/components/sign-up-form";
import UserMenu from "@/components/user-menu";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export const Route = createFileRoute("/dashboard")({
  component: RouteComponent,
});

function RouteComponent() {
  const [showSignIn, setShowSignIn] = useState(false);
  const privateData = useQuery(api.privateData.get);

  return (
    <>
      <Authenticated>
        <DashboardContent />
      </Authenticated>
      <Unauthenticated>
        <div className="p-4 bg-red-100 dark:bg-red-900 border border-red-500 rounded my-4">
            <h3 className="font-bold">Debug Info</h3>
            <pre className="text-xs overflow-auto">
                {JSON.stringify({
                    hasPrivateData: !!privateData,
                    inUnauthenticatedBlock: true,
                }, null, 2)}
            </pre>
        </div>
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
  const metricKeys = useQuery(api.analytics.getMetricKeys);
  const recentActivity = useQuery(api.analytics.getRecentActivity, { limit: 5 });

  const [selectedMetric, setSelectedMetric] = useState<string | null>(null);

  // Redirect to onboarding if not completed
  useEffect(() => {
    if (userSettings !== undefined && !userSettings?.onboardingCompleted) {
      navigate({ to: "/onboarding" });
    }
  }, [userSettings, navigate]);

  // Set default selected metric
  useEffect(() => {
    if (metricKeys && metricKeys.length > 0 && !selectedMetric) {
      setSelectedMetric(metricKeys[0]);
    }
  }, [metricKeys, selectedMetric]);

  // Show loading while checking onboarding status
  if (userSettings === undefined) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="animate-pulse text-muted-foreground">Loading...</div>
      </div>
    );
  }

  const numericMetrics = metricsSummary?.numeric || {};
  const categoricalMetrics = metricsSummary?.categorical || {};
  const hasMetrics = Object.keys(numericMetrics).length > 0 || Object.keys(categoricalMetrics).length > 0;

  return (
    <div className="container mx-auto max-w-6xl py-8 px-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold bg-gradient-to-r from-purple-500 to-pink-500 bg-clip-text text-transparent">
            Your Metrics Dashboard
          </h1>
          {userSettings?.selectedCalendarName && (
            <p className="text-muted-foreground">
              Tracking: <span className="font-medium text-purple-500">{userSettings.selectedCalendarName}</span>
            </p>
          )}
        </div>
        <div className="flex items-center gap-4">
          <SyncButton />
          <UserMenu />
        </div>
      </div>

      {!hasMetrics ? (
        <EmptyState />
      ) : (
        <div className="space-y-8">
          {/* Numeric Metrics Cards */}
          {Object.keys(numericMetrics).length > 0 && (
            <div>
              <h2 className="text-lg font-semibold mb-4 text-muted-foreground">📊 Numeric Metrics</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {Object.entries(numericMetrics).map(([key, stats]) => (
                  <NumericMetricCard
                    key={key}
                    title={key}
                    stats={stats}
                    isSelected={selectedMetric === key}
                    onClick={() => setSelectedMetric(key)}
                  />
                ))}
              </div>
            </div>
          )}

          {/* Categorical Metrics Cards */}
          {Object.keys(categoricalMetrics).length > 0 && (
            <div>
              <h2 className="text-lg font-semibold mb-4 text-muted-foreground">🏷️ Categorical Metrics</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {Object.entries(categoricalMetrics).map(([key, stats]) => (
                  <CategoricalMetricCard
                    key={key}
                    title={key}
                    stats={stats}
                  />
                ))}
              </div>
            </div>
          )}

          {/* Chart (only for numeric metrics) */}
          {selectedMetric && numericMetrics[selectedMetric] && (
            <MetricChart metricKey={selectedMetric} />
          )}

          {/* Recent Activity */}
          <RecentActivityFeed activity={recentActivity || []} />
        </div>
      )}
    </div>
  );
}

function EmptyState() {
  return (
    <Card className="border-dashed">
      <CardContent className="flex flex-col items-center justify-center py-16">
        <div className="text-6xl mb-4">📊</div>
        <h3 className="text-xl font-semibold mb-2">No metrics yet</h3>
        <p className="text-muted-foreground text-center max-w-md mb-6">
          Add YAML metadata to your calendar events to start tracking metrics.
        </p>
        <div className="bg-muted p-4 rounded-lg font-mono text-sm">
          <pre>{`mood: 8
productivity: 9
energy: 7
category: "work"
location: "home"
exercise: true`}</pre>
        </div>
      </CardContent>
    </Card>
  );
}

function NumericMetricCard({
  title,
  stats,
  isSelected,
  onClick
}: {
  title: string;
  stats: { count: number; avg: number; min: number; max: number };
  isSelected: boolean;
  onClick: () => void;
}) {
  return (
    <Card
      className={`cursor-pointer transition-all hover:scale-[1.02] ${
        isSelected ? "ring-2 ring-purple-500 shadow-lg shadow-purple-500/20" : ""
      }`}
      onClick={onClick}
    >
      <CardHeader className="pb-2">
        <CardDescription className="capitalize">{title}</CardDescription>
        <CardTitle className="text-3xl font-bold">{stats.avg}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex justify-between text-sm text-muted-foreground">
          <span>Min: {stats.min}</span>
          <span>Max: {stats.max}</span>
        </div>
        <p className="text-xs text-muted-foreground mt-1">
          {stats.count} data points
        </p>
      </CardContent>
    </Card>
  );
}

function CategoricalMetricCard({
  title,
  stats,
}: {
  title: string;
  stats: { count: number; valueCounts: Record<string, number>; topValue: string };
}) {
  // Get top 3 values
  const topValues = Object.entries(stats.valueCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3);

  return (
    <Card className="transition-all hover:scale-[1.02]">
      <CardHeader className="pb-2">
        <CardDescription className="capitalize">{title}</CardDescription>
        <CardTitle className="text-xl font-bold truncate">
          {stats.topValue || "—"}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-1">
          {topValues.map(([value, count]) => (
            <div key={value} className="flex justify-between text-sm">
              <span className="truncate text-muted-foreground">{value}</span>
              <span className="font-medium text-purple-500">{count}×</span>
            </div>
          ))}
        </div>
        <p className="text-xs text-muted-foreground mt-2">
          {stats.count} total · {Object.keys(stats.valueCounts).length} unique
        </p>
      </CardContent>
    </Card>
  );
}

function MetricChart({ metricKey }: { metricKey: string }) {
  const timeSeries = useQuery(api.analytics.getMetricTimeSeries, {
    key: metricKey,
    days: 30
  });

  if (!timeSeries) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="capitalize">{metricKey} Over Time</CardTitle>
        </CardHeader>
        <CardContent>
          <Skeleton className="h-[300px] w-full" />
        </CardContent>
      </Card>
    );
  }

  if (timeSeries.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="capitalize">{metricKey} Over Time</CardTitle>
        </CardHeader>
        <CardContent className="flex items-center justify-center h-[300px]">
          <p className="text-muted-foreground">No data for this metric yet</p>
        </CardContent>
      </Card>
    );
  }

  // Format data for chart
  const chartData = timeSeries.map((point) => ({
    date: new Date(point.date).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    value: point.value,
    title: point.eventTitle,
  }));

  return (
    <Card>
      <CardHeader>
        <CardTitle className="capitalize">{metricKey} Over Time</CardTitle>
        <CardDescription>Last 30 days</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="h-[300px]">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chartData}>
              <defs>
                <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#a855f7" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#a855f7" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
              <XAxis
                dataKey="date"
                className="text-xs"
                tick={{ fill: "hsl(var(--muted-foreground))" }}
              />
              <YAxis
                className="text-xs"
                tick={{ fill: "hsl(var(--muted-foreground))" }}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(var(--card))",
                  border: "1px solid hsl(var(--border))",
                  borderRadius: "8px",
                }}
                labelStyle={{ color: "hsl(var(--foreground))" }}
              />
              <Area
                type="monotone"
                dataKey="value"
                stroke="#a855f7"
                strokeWidth={2}
                fill="url(#colorValue)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </CardContent>
    </Card>
  );
}

function RecentActivityFeed({ activity }: { activity: Array<{
  id: string;
  title: string;
  date: number;
  metrics: Array<{ key: string; value: number | boolean }>;
}> }) {
  if (activity.length === 0) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Recent Activity</CardTitle>
        <CardDescription>Your latest tracked events</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {activity.map((event) => (
            <div
              key={event.id}
              className="flex items-start justify-between p-3 rounded-lg bg-muted/50"
            >
              <div>
                <h4 className="font-medium">{event.title}</h4>
                <p className="text-sm text-muted-foreground">
                  {new Date(event.date).toLocaleDateString("en-US", {
                    weekday: "short",
                    month: "short",
                    day: "numeric",
                    hour: "numeric",
                    minute: "2-digit",
                  })}
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                {event.metrics.map((metric) => (
                  <span
                    key={metric.key}
                    className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-700 dark:bg-purple-900 dark:text-purple-300"
                  >
                    {metric.key}: {typeof metric.value === "boolean" ? (metric.value ? "✓" : "✗") : metric.value}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
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
    <Button onClick={handleSync} disabled={loading} variant="outline">
      {loading ? "Syncing..." : "Sync Now"}
    </Button>
  );
}
