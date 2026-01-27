import { api } from "@calendar-metrics/backend/convex/_generated/api";
import { createFileRoute } from "@tanstack/react-router";
import { Authenticated, AuthLoading, Unauthenticated, useAction, useQuery } from "convex/react";
import { useState } from "react";
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
        <div>
          <h1>Dashboard</h1>
          <p>privateData: {privateData?.message}</p>
          <div className="my-4">
            <SyncButton />
          </div>
          <UserMenu />
        </div>
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
function SyncButton() {
  const sync = useAction(api.calendar.syncEvents);
  const [loading, setLoading] = useState(false);

  const handleSync = async () => {
    setLoading(true);
    try {
      const result = await sync({});
      toast.success(`Synced ${result.count} events!`);
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
