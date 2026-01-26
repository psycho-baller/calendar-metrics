import { v } from "convex/values";
import { internalAction, internalMutation } from "./_generated/server";
import yaml from "js-yaml";
import { internal } from "./_generated/api";

export const syncEvents = internalAction({
  args: {
    userId: v.string(),
    calendarId: v.optional(v.string()), // Default to primary if not provided
  },
  handler: async (ctx, args) => {
    // Retrieve refresh token from userSecrets
    // Since we are in an internalAction, we can't directly Query the DB?
    // Actions can't query directly. We need to call a query or mutation.
    // Or we can pass it in via args?
    // Ideally, we fetch it via a helper query.

    // We'll call an internal query to get the secret.
    const refreshToken = await ctx.runQuery(internal.secrets.getSecret, {
      userId: args.userId,
      key: "google_refresh_token"
    });

    if (!refreshToken) {
      console.error("No refresh token found for user", args.userId);
      return;
    }

    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET
    );

    oauth2Client.setCredentials({ refresh_token: refreshToken });

    const calendar = google.calendar({ version: "v3", auth: oauth2Client });

    // Fetch events (last 30 days for now, or use sync token)
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const response = await calendar.events.list({
      calendarId: args.calendarId || "primary",
      timeMin: thirtyDaysAgo.toISOString(),
      singleEvents: true,
      orderBy: "startTime",
    });

    const events = response.data.items || [];

    const parsedEvents = events.map((event) => {
      let metrics: Record<string, number | boolean> = {};

      if (event.description) {
        try {
          // Attempt to parse YAML from description
          // We look for a YAML block or parse the whole thing?
          // Let's assume the description IS the YAML or contains it.
          // For robustness, let's try to parse the whole string first.
          const doc = yaml.load(event.description);
          if (typeof doc === "object" && doc !== null) {
            // Filter only number/boolean values
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

    // Save to DB
    await ctx.runMutation(internal.calendar.saveEvents, {
      events: parsedEvents
    });
  },
});

export const saveEvents = internalMutation({
  args: {
    events: v.array(v.object({
      googleEventId: v.string(),
      calendarId: v.string(),
      title: v.string(),
      description: v.optional(v.string()),
      startTime: v.number(),
      endTime: v.number(),
      metrics: v.any(), // Record<string, number|boolean>
    }))
  },
  handler: async (ctx, args) => {
    for (const evt of args.events) {
      // Upsert event
      const existing = await ctx.db
        .query("events")
        .withIndex("by_googleEventId", (q) => q.eq("googleEventId", evt.googleEventId))
        .first();

      let eventId;
      if (existing) {
        eventId = existing._id;
        await ctx.db.patch(existing._id, {
          title: evt.title,
          description: evt.description,
          startTime: evt.startTime,
          endTime: evt.endTime,
        });
        // Remove old metrics? Or merge?
        // Strategy: Delete old metrics for this event, insert new ones.
        const oldMetrics = await ctx.db
          .query("metricValues")
          .withIndex("by_eventId", (q) => q.eq("eventId", eventId))
          .collect();
        for (const m of oldMetrics) {
          await ctx.db.delete(m._id);
        }
      } else {
        eventId = await ctx.db.insert("events", {
          googleEventId: evt.googleEventId,
          calendarId: evt.calendarId,
          title: evt.title,
          description: evt.description,
          startTime: evt.startTime,
          endTime: evt.endTime,
        });
      }

      // Insert metrics
      for (const [key, value] of Object.entries(evt.metrics as Record<string, number | boolean>)) {
        await ctx.db.insert("metricValues", {
          eventId,
          key,
          value,
        });
      }
    }
  }
});
