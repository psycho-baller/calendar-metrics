"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { google } from "googleapis";
import { internal, components } from "./_generated/api";
import { authComponent } from "./auth";
import yaml from "js-yaml";

// Helper function to get OAuth2 client with user's refresh token
async function getOAuth2Client(ctx: any, userId: string) {
  const account = await ctx.runQuery(components.betterAuth.adapter.findOne, {
    model: "account",
    where: [
      { field: "userId", operator: "eq", value: userId },
      { field: "providerId", operator: "eq", value: "google", connector: "AND" },
    ],
    select: ["refreshToken"],
  });

  const refreshToken = account?.refreshToken;

  if (!refreshToken) {
    throw new Error("No Google Refresh Token found. Please sign in with Google again.");
  }

  const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET
  );

  oauth2Client.setCredentials({ refresh_token: refreshToken });

  return oauth2Client;
}

// List all calendars for the current user
export const listCalendars = action({
  args: {},
  handler: async (ctx) => {
    // 1. Get authenticated user
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      throw new Error("Unauthorized");
    }

    // 2. Get OAuth2 client
    const oauth2Client = await getOAuth2Client(ctx, user._id);

    // 3. Initialize the Calendar client
    const calendar = google.calendar({ version: "v3", auth: oauth2Client });

    try {
      // 4. Fetch calendar list
      const response = await calendar.calendarList.list();
      const calendars = response.data.items || [];

      // 5. Return simplified calendar data
      return calendars.map((cal) => ({
        id: cal.id!,
        name: cal.summary || "Unnamed Calendar",
        description: cal.description,
        primary: cal.primary || false,
        backgroundColor: cal.backgroundColor,
        accessRole: cal.accessRole,
      }));
    } catch (error) {
      console.error("Failed to fetch calendar list:", error);
      throw new Error("Failed to fetch calendar list from Google.");
    }
  },
});

export const syncEvents = action({
  args: {
    calendarId: v.optional(v.string()), // Override calendar ID (optional)
  },
  handler: async (ctx, args) => {
    // 1. Get authenticated user
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      throw new Error("Unauthorized");
    }

    // 2. Get calendar ID - use arg, or fall back to user's selected calendar, or "primary"
    let calendarId = args.calendarId;

    if (!calendarId) {
      // Try to get user's selected calendar from settings
      const settings = await ctx.runQuery(internal.userSettings.getUserSettingsInternal, { userId: user._id });
      calendarId = settings?.selectedCalendarId || "primary";
    }

    // 3. Get OAuth2 client
    const oauth2Client = await getOAuth2Client(ctx, user._id);

    // 4. Initialize the Calendar client
    const calendar = google.calendar({ version: "v3", auth: oauth2Client });

    try {
      // 5. Fetch events (last 30 days)
      const now = new Date();
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

      const response = await calendar.events.list({
        calendarId,
        timeMin: thirtyDaysAgo.toISOString(),
        singleEvents: true,
        orderBy: "startTime",
      });

      const events = response.data.items || [];

      // 6. Parse events
      const parsedEvents = events.map((event) => {
        let metrics: Record<string, number | boolean | string> = {};

        if (event.description) {
          try {
            const doc = yaml.load(event.description);
            if (typeof doc === "object" && doc !== null) {
              Object.entries(doc).forEach(([key, val]) => {
                if (typeof val === "number" || typeof val === "boolean" || typeof val === "string") {
                  metrics[key] = val;
                }
              });
            }
          } catch (e) {
            // invalid yaml, ignore
            console.log(`Failed to parse YAML for event ${event.summary}:`, e);
          }
        }

        return {
          googleEventId: event.id!,
          calendarId,
          title: event.summary || "No Title",
          description: event.description || undefined,
          isAllDay: !event.start?.dateTime,
          startTime: new Date(event.start?.dateTime || event.start?.date || 0).getTime(),
          endTime: new Date(event.end?.dateTime || event.end?.date || 0).getTime(),
          metrics,
        };
      });

      // 7. Save to DB via internal mutation
      await ctx.runMutation(internal.calendarData.saveEvents, {
        events: parsedEvents,
      });

      return { count: parsedEvents.length, calendarId };
    } catch (error) {
      console.error("Google Calendar API request failed:", error);
      throw new Error("Failed to fetch calendar events from Google.");
    }
  },
});
