import { mutation, query, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { authComponent } from "./auth";

// Get user settings for the current authenticated user (public query)
export const getUserSettings = query({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return null;
    }

    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    return settings;
  },
});

// Internal version for use in actions (uses userId directly)
export const getUserSettingsInternal = internalQuery({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();

    return settings;
  },
});

// Set the selected calendar for the current user
export const setSelectedCalendar = mutation({
  args: {
    calendarId: v.string(),
    calendarName: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      throw new Error("Unauthorized");
    }

    // Check if settings already exist
    const existing = await ctx.db
      .query("userSettings")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (existing) {
      // Update existing settings
      await ctx.db.patch(existing._id, {
        selectedCalendarId: args.calendarId,
        selectedCalendarName: args.calendarName,
        onboardingCompleted: true,
      });
      return existing._id;
    } else {
      // Create new settings
      const id = await ctx.db.insert("userSettings", {
        userId: user._id,
        selectedCalendarId: args.calendarId,
        selectedCalendarName: args.calendarName,
        onboardingCompleted: true,
      });
      return id;
    }
  },
});

// Check if user has completed onboarding
export const hasCompletedOnboarding = query({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return false;
    }

    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    return settings?.onboardingCompleted ?? false;
  },
});
