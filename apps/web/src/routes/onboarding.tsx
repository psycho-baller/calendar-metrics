import { api } from "@calendar-metrics/backend/convex/_generated/api";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Authenticated, AuthLoading, Unauthenticated, useAction, useMutation, useQuery } from "convex/react";
import { useState, useEffect } from "react";
import { toast } from "sonner";

import SignInForm from "@/components/sign-in-form";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export const Route = createFileRoute("/onboarding")({
  component: RouteComponent,
});

function RouteComponent() {
  const [showSignIn, setShowSignIn] = useState(false);

  return (
    <>
      <Authenticated>
        <CalendarSelector />
      </Authenticated>
      <Unauthenticated>
        <div className="flex flex-col items-center justify-center min-h-[60vh] p-8">
          <h2 className="text-2xl font-bold mb-4">Sign in to continue</h2>
          <p className="text-muted-foreground mb-6">You need to sign in with Google to access your calendars.</p>
          <SignInForm onSwitchToSignUp={() => setShowSignIn(false)} />
        </div>
      </Unauthenticated>
      <AuthLoading>
        <div className="flex items-center justify-center min-h-[60vh]">
          <div className="animate-pulse text-muted-foreground">Loading...</div>
        </div>
      </AuthLoading>
    </>
  );
}

interface Calendar {
  id: string;
  name: string;
  description?: string;
  primary: boolean;
  backgroundColor?: string;
  accessRole?: string;
}

function CalendarSelector() {
  const navigate = useNavigate();
  const listCalendars = useAction(api.calendar.listCalendars);
  const setSelectedCalendar = useMutation(api.userSettings.setSelectedCalendar);
  const userSettings = useQuery(api.userSettings.getUserSettings);

  const [calendars, setCalendars] = useState<Calendar[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // Redirect if already completed onboarding
  useEffect(() => {
    if (userSettings?.onboardingCompleted) {
      navigate({ to: "/dashboard" });
    }
  }, [userSettings, navigate]);

  // Fetch calendars on mount
  useEffect(() => {
    const fetchCalendars = async () => {
      try {
        const result = await listCalendars({});
        setCalendars(result);
        // Pre-select primary calendar if available
        const primary = result.find((c) => c.primary);
        if (primary) {
          setSelectedId(primary.id);
        }
      } catch (error: any) {
        toast.error(error.message || "Failed to fetch calendars");
        console.error(error);
      } finally {
        setLoading(false);
      }
    };

    fetchCalendars();
  }, [listCalendars]);

  const handleSave = async () => {
    if (!selectedId) {
      toast.error("Please select a calendar");
      return;
    }

    const calendar = calendars.find((c) => c.id === selectedId);
    if (!calendar) return;

    setSaving(true);
    try {
      await setSelectedCalendar({
        calendarId: calendar.id,
        calendarName: calendar.name,
      });
      toast.success(`Selected "${calendar.name}" as your tracking calendar!`);
      navigate({ to: "/dashboard" });
    } catch (error: any) {
      toast.error(error.message || "Failed to save selection");
      console.error(error);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="container mx-auto max-w-4xl py-12 px-4">
      {/* Header */}
      <div className="text-center mb-12">
        <h1 className="text-4xl font-bold bg-gradient-to-r from-purple-500 to-pink-500 bg-clip-text text-transparent mb-4">
          Choose Your Calendar
        </h1>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
          Select which Google Calendar you want to track for your Quantified Self journey.
          Events in this calendar with YAML metadata will be parsed for metrics.
        </p>
      </div>

      {/* Calendar Grid */}
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <Skeleton key={i} className="h-32 rounded-xl" />
          ))}
        </div>
      ) : calendars.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-muted-foreground">No calendars found. Make sure you have Google Calendar set up.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
          {calendars.map((calendar) => (
            <Card
              key={calendar.id}
              className={`cursor-pointer transition-all duration-200 hover:scale-[1.02] ${
                selectedId === calendar.id
                  ? "ring-2 ring-purple-500 shadow-lg shadow-purple-500/20"
                  : "hover:shadow-md"
              }`}
              onClick={() => setSelectedId(calendar.id)}
            >
              <CardHeader className="pb-2">
                <div className="flex items-center gap-3">
                  {/* Color indicator */}
                  <div
                    className="w-4 h-4 rounded-full shrink-0"
                    style={{ backgroundColor: calendar.backgroundColor || "#6366f1" }}
                  />
                  <CardTitle className="text-lg truncate">
                    {calendar.name}
                  </CardTitle>
                </div>
              </CardHeader>
              <CardContent>
                <CardDescription className="line-clamp-2">
                  {calendar.description || (calendar.primary ? "Your primary calendar" : "No description")}
                </CardDescription>
                {calendar.primary && (
                  <span className="inline-flex items-center mt-2 px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-700 dark:bg-purple-900 dark:text-purple-300">
                    Primary
                  </span>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Action Button */}
      <div className="flex justify-center">
        <Button
          size="lg"
          className="px-8 bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600"
          onClick={handleSave}
          disabled={!selectedId || saving}
        >
          {saving ? "Saving..." : "Continue with Selected Calendar"}
        </Button>
      </div>

      {/* Help text */}
      <p className="text-center text-sm text-muted-foreground mt-6">
        You can change this later in your settings.
      </p>
    </div>
  );
}
