import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";

import { buttonVariants } from "@/components/ui/button";
import { createDemoDashboardData } from "@/lib/demo-dashboard-data";
import { cn } from "@/lib/utils";

import { DashboardView } from "./dashboard";

export const Route = createFileRoute("/demo-dashboard")({
  component: DemoDashboardRoute,
});

function DemoDashboardRoute() {
  const demoData = useMemo(() => createDemoDashboardData(), []);
  const [selectedMetric, setSelectedMetric] = useState<string | null>("focus");
  const [metricWindowDays, setMetricWindowDays] = useState(30);
  const metricTimeSeries = selectedMetric
    ? (demoData.metricTimeSeriesByKey[selectedMetric] ?? []).filter(
        (point) => point.date >= Date.now() - metricWindowDays * 86_400_000,
      )
    : undefined;

  return (
    <DashboardView
      userSettings={demoData.userSettings}
      metricsSummary={demoData.metricsSummary}
      recentActivity={demoData.recentActivity}
      dailyAggregates={demoData.dailyAggregates}
      weeklyComparison={demoData.weeklyComparison}
      selectedMetric={selectedMetric}
      onSelectedMetricChange={setSelectedMetric}
      metricWindowDays={metricWindowDays}
      onMetricWindowDaysChange={setMetricWindowDays}
      metricTimeSeries={metricTimeSeries}
      heroActions={
        <>
          <span className="rounded-full border border-white/15 bg-white/10 px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-white/75">
            Public demo
          </span>
          <a
            href="/dashboard"
            className={cn(
              buttonVariants({ variant: "outline" }),
              "border-white/20 bg-white/10 text-white hover:bg-white/15 hover:text-white",
            )}
          >
            Use my data
          </a>
        </>
      }
    />
  );
}
