"use node";

import { action, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { google } from "googleapis";
import { internal, components } from "./_generated/api";
import { authComponent } from "./auth";
import yaml from "js-yaml";

export const syncEvents = action({
  args: {
    calendarId: v.optional(v.string()), // Default to primary if not provided
  },
  handler: async (ctx, args) => {
    // 1. Get authenticated user
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      throw new Error("Unauthorized");
    }

    // 2. Retrieve refresh token from Better Auth's account table
    // The account table stores OAuth tokens for linked providers
    const account = await ctx.runQuery(components.betterAuth.adapter.findOne, {
      model: "account",
      where: [
        { field: "userId", operator: "eq", value: user._id },
        { field: "providerId", operator: "eq", value: "google", connector: "AND" },
      ],
      select: ["refreshToken"],
    });

    const refreshToken = account?.refreshToken;

    if (!refreshToken) {
      throw new Error("No Google Refresh Token found. Please sign in with Google again.");
    }

    // 3. Initialize the OAuth2 client
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET
    );

    oauth2Client.setCredentials({ refresh_token: refreshToken });

    // 4. Initialize the Calendar client
    const calendar = google.calendar({ version: "v3", auth: oauth2Client });

    try {
      // 5. Fetch events (last 30 days)
      const now = new Date();
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

      const response = await calendar.events.list({
        calendarId: args.calendarId || "primary",
        timeMin: thirtyDaysAgo.toISOString(),
        singleEvents: true,
        orderBy: "startTime",
      });

      const events = response.data.items || [];

      // 6. Parse events
      const parsedEvents = events.map((event) => {
        let metrics: Record<string, number | boolean> = {};

        if (event.description) {
          try {
            const doc = yaml.load(event.description);
            if (typeof doc === "object" && doc !== null) {
              Object.entries(doc).forEach(([key, val]) => {
                if (typeof val === "number" || typeof val === "boolean") {
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
          calendarId: args.calendarId || "primary",
          title: event.summary || "No Title",
          description: event.description || undefined,
          startTime: new Date(event.start?.dateTime || event.start?.date || 0).getTime(),
          endTime: new Date(event.end?.dateTime || event.end?.date || 0).getTime(),
          metrics,
        };
      });

      // 7. Save to DB via internal mutation
      await ctx.runMutation(internal.calendarData.saveEvents, {
        events: parsedEvents,
      });

      return { count: parsedEvents.length };
    } catch (error) {
      console.error("Google Calendar API request failed:", error);
      throw new Error("Failed to fetch calendar events from Google.");
    }
  },
});
