import { api } from "@calendar-metrics/backend/convex/_generated/api";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Authenticated, AuthLoading, Unauthenticated, useAction, useQuery } from "convex/react";
import { useState, useEffect } from "react";
import { toast } from "sonner";

import SignInForm from "@/components/sign-in-form";
import SignUpForm from "@/components/sign-up-form";
import UserMenu from "@/components/user-menu";
import { Button } from "@/components/ui/button";

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
  const privateData = useQuery(api.privateData.get);

  // Redirect to onboarding if not completed
  useEffect(() => {
    if (userSettings !== undefined && !userSettings?.onboardingCompleted) {
      navigate({ to: "/onboarding" });
    }
  }, [userSettings, navigate]);

  // Show loading while checking onboarding status
  if (userSettings === undefined) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="animate-pulse text-muted-foreground">Loading...</div>
      </div>
    );
  }

  return (
    <div className="container mx-auto max-w-4xl py-8 px-4">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold">Dashboard</h1>
          {userSettings?.selectedCalendarName && (
            <p className="text-muted-foreground">
              Tracking: <span className="font-medium text-purple-500">{userSettings.selectedCalendarName}</span>
            </p>
          )}
        </div>
        <UserMenu />
      </div>

      <div className="space-y-6">
        <p>privateData: {privateData?.message}</p>
        <div className="my-4">
          <SyncButton />
        </div>
      </div>
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
    <Button onClick={handleSync} disabled={loading}>
      {loading ? "Syncing..." : "Sync Calendar"}
    </Button>
  );
}
