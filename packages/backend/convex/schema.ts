import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  events: defineTable({
    googleEventId: v.string(),
    calendarId: v.string(),
    title: v.string(),
    description: v.optional(v.string()),
    startTime: v.number(),
    endTime: v.number(),
  }).index("by_googleEventId", ["googleEventId"]),

  metricValues: defineTable({
    eventId: v.id("events"),
    key: v.string(),
    value: v.union(v.number(), v.boolean()),
  })
    .index("by_eventId", ["eventId"])
    .index("by_key", ["key"]),

  userSecrets: defineTable({
    userId: v.string(), // Links to Better Auth user ID
    key: v.string(), // e.g. "google_refresh_token"
    value: v.string(),
  }).index("by_userId_key", ["userId", "key"]),
});
