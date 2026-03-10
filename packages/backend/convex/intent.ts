import { v } from "convex/values";

import type { Doc, Id } from "./_generated/dataModel";
import {
  internalMutation,
  internalQuery,
} from "./_generated/server";

const DEFAULT_INTEGRATION_SLUG = "default";

type DeviceSettings = {
  autoStartFocus?: boolean;
  autoCompleteFocus?: boolean;
  autoShowReview?: boolean;
  startShortcutName?: string;
  completeShortcutName?: string;
  bundleId?: string;
};

type TogglTimeEntry = {
  id: number;
  workspace_id: number;
  user_id?: number;
  project_id?: number;
  task_id?: number;
  description?: string;
  tags?: string[];
  billable?: boolean;
  start: string;
  stop?: string;
  duration?: number;
  at?: string;
};

function now() {
  return Date.now();
}

function generateToken(prefix: string) {
  return `${prefix}_${crypto.randomUUID().replace(/-/g, "")}`;
}

function parseTags(tagJson?: string) {
  if (!tagJson) {
    return [] as string[];
  }

  try {
    const parsed = JSON.parse(tagJson);
    return Array.isArray(parsed)
      ? parsed.filter((value): value is string => typeof value === "string")
      : [];
  } catch {
    return [];
  }
}

function toSessionSummary(session: Doc<"intentSessions">) {
  return {
    id: session._id,
    source: session.source,
    sourceTimeEntryId: session.sourceTimeEntryId,
    workspaceId: session.workspaceId,
    togglUserId: session.togglUserId ?? null,
    togglProjectId: session.togglProjectId ?? null,
    togglTaskId: session.togglTaskId ?? null,
    description: session.description ?? "",
    tags: parseTags(session.tagJson),
    billable: session.billable ?? null,
    startTimeMs: session.startTimeMs,
    stopTimeMs: session.stopTimeMs ?? null,
    durationMs: session.durationMs ?? null,
    status: session.status,
    focusStatus: session.focusStatus,
    reviewStatus: session.reviewStatus,
    sourceUpdatedAt: session.sourceUpdatedAt,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
  };
}

function isPendingReviewStatus(status: string) {
  return status === "pending" || status === "presented";
}

async function getIntegrationDoc(ctx: any) {
  const existing = await ctx.db
    .query("intentIntegrationState")
    .withIndex("by_slug", (q: any) => q.eq("slug", DEFAULT_INTEGRATION_SLUG))
    .first();

  if (existing) {
    return existing;
  }

  const timestamp = now();
  const createdId = await ctx.db.insert("intentIntegrationState", {
    slug: DEFAULT_INTEGRATION_SLUG,
    createdAt: timestamp,
    updatedAt: timestamp,
  });

  const created = await ctx.db.get(createdId);
  if (!created) {
    throw new Error("Failed to create integration state.");
  }

  return created;
}

async function getDeviceDoc(ctx: any, deviceId: string) {
  return await ctx.db
    .query("intentDevices")
    .withIndex("by_deviceId", (q: any) => q.eq("deviceId", deviceId))
    .first();
}

function mergeDeviceSettings(
  existing: Doc<"intentDevices"> | null,
  settings: DeviceSettings | undefined,
) {
  return {
    autoStartFocus: settings?.autoStartFocus ?? existing?.autoStartFocus ?? true,
    autoCompleteFocus:
      settings?.autoCompleteFocus ?? existing?.autoCompleteFocus ?? true,
    autoShowReview: settings?.autoShowReview ?? existing?.autoShowReview ?? true,
    startShortcutName:
      settings?.startShortcutName ?? existing?.startShortcutName,
    completeShortcutName:
      settings?.completeShortcutName ?? existing?.completeShortcutName,
    bundleId: settings?.bundleId ?? existing?.bundleId,
  };
}

export const registerDevice = internalMutation({
  args: {
    deviceName: v.string(),
    platform: v.string(),
    settings: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    const integration = await getIntegrationDoc(ctx);
    const timestamp = now();
    const deviceId = generateToken("intent_device");
    const deviceSecret = generateToken("intent_secret");
    const merged = mergeDeviceSettings(null, args.settings as DeviceSettings);
    const isDefault = !integration.defaultDeviceId;

    await ctx.db.insert("intentDevices", {
      deviceId,
      deviceSecret,
      name: args.deviceName,
      platform: args.platform,
      bundleId: merged.bundleId,
      autoStartFocus: merged.autoStartFocus,
      autoCompleteFocus: merged.autoCompleteFocus,
      autoShowReview: merged.autoShowReview,
      startShortcutName: merged.startShortcutName,
      completeShortcutName: merged.completeShortcutName,
      lastSeenAt: timestamp,
      isDefault,
      createdAt: timestamp,
      updatedAt: timestamp,
    });

    if (isDefault) {
      await ctx.db.patch(integration._id, {
        defaultDeviceId: deviceId,
        updatedAt: timestamp,
      });
    }

    return {
      deviceId,
      deviceSecret,
      isDefault,
    };
  },
});

export const authenticateDevice = internalQuery({
  args: {
    deviceId: v.string(),
    deviceSecret: v.string(),
  },
  handler: async (ctx, args) => {
    const device = await getDeviceDoc(ctx, args.deviceId);
    if (!device || device.deviceSecret !== args.deviceSecret) {
      return null;
    }

    return device;
  },
});

export const heartbeatDevice = internalMutation({
  args: {
    deviceId: v.string(),
    settings: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    const device = await getDeviceDoc(ctx, args.deviceId);
    if (!device) {
      return null;
    }

    const timestamp = now();
    const merged = mergeDeviceSettings(device, args.settings as DeviceSettings);

    await ctx.db.patch(device._id, {
      bundleId: merged.bundleId,
      autoStartFocus: merged.autoStartFocus,
      autoCompleteFocus: merged.autoCompleteFocus,
      autoShowReview: merged.autoShowReview,
      startShortcutName: merged.startShortcutName,
      completeShortcutName: merged.completeShortcutName,
      lastSeenAt: timestamp,
      updatedAt: timestamp,
    });

    return {
      ...device,
      ...merged,
      lastSeenAt: timestamp,
      updatedAt: timestamp,
    };
  },
});

export const updateIntegrationState = internalMutation({
  args: {
    patch: v.any(),
  },
  handler: async (ctx, args) => {
    const integration = await getIntegrationDoc(ctx);
    const timestamp = now();

    await ctx.db.patch(integration._id, {
      ...(args.patch as Record<string, unknown>),
      updatedAt: timestamp,
    });

    return await ctx.db.get(integration._id);
  },
});

export const getIntegrationState = internalQuery({
  args: {},
  handler: async (ctx) => {
    return await getIntegrationDoc(ctx);
  },
});

export const recordWebhookEvent = internalMutation({
  args: {
    dedupeKey: v.string(),
    entity: v.string(),
    action: v.string(),
    entityId: v.string(),
    workspaceId: v.optional(v.number()),
    happenedAt: v.optional(v.number()),
    payloadJson: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("intentWebhookEvents")
      .withIndex("by_dedupeKey", (q: any) => q.eq("dedupeKey", args.dedupeKey))
      .first();

    if (existing) {
      return { isDuplicate: true, eventId: existing._id };
    }

    const timestamp = now();
    const eventId = await ctx.db.insert("intentWebhookEvents", {
      dedupeKey: args.dedupeKey,
      entity: args.entity,
      action: args.action,
      entityId: args.entityId,
      workspaceId: args.workspaceId,
      happenedAt: args.happenedAt,
      receivedAt: timestamp,
      payloadJson: args.payloadJson,
    });

    return { isDuplicate: false, eventId };
  },
});

export const upsertSessionFromToggl = internalMutation({
  args: {
    action: v.string(),
    timeEntry: v.any(),
  },
  handler: async (ctx, args) => {
    const timeEntry = args.timeEntry as TogglTimeEntry;
    const sourceTimeEntryId = String(timeEntry.id);
    const existing = await ctx.db
      .query("intentSessions")
      .withIndex("by_sourceTimeEntryId", (q: any) =>
        q.eq("sourceTimeEntryId", sourceTimeEntryId),
      )
      .first();

    const timestamp = now();
    const stopTimeMs = timeEntry.stop ? Date.parse(timeEntry.stop) : undefined;
    const status =
      args.action === "deleted"
        ? "deleted"
        : stopTimeMs
          ? "completed"
          : "running";

    let focusStatus = existing?.focusStatus ?? "idle";
    if (status === "running" && !existing) {
      focusStatus = "pending";
    } else if (status === "running" && existing?.focusStatus === "completed") {
      focusStatus = "pending";
    } else if (!stopTimeMs && focusStatus === "idle") {
      focusStatus = "pending";
    } else if (status !== "running" && !existing) {
      focusStatus = "idle";
    }

    let reviewStatus = existing?.reviewStatus ?? "idle";
    if (status === "completed" && (!existing || existing.reviewStatus === "idle")) {
      reviewStatus = "pending";
    } else if (status === "running") {
      reviewStatus = "idle";
    } else if (status === "deleted") {
      reviewStatus = existing?.reviewStatus ?? "skipped";
    }

    const patch = {
      source: "toggl",
      sourceTimeEntryId,
      workspaceId: timeEntry.workspace_id,
      togglUserId: timeEntry.user_id,
      togglProjectId: timeEntry.project_id,
      togglTaskId: timeEntry.task_id,
      description: timeEntry.description,
      tagJson: JSON.stringify(timeEntry.tags ?? []),
      billable: timeEntry.billable,
      startTimeMs: Date.parse(timeEntry.start),
      stopTimeMs,
      durationMs:
        typeof timeEntry.duration === "number" && timeEntry.duration >= 0
          ? timeEntry.duration * 1000
          : stopTimeMs && Date.parse(timeEntry.start) <= stopTimeMs
            ? stopTimeMs - Date.parse(timeEntry.start)
            : undefined,
      status,
      focusStatus,
      reviewStatus,
      lastWebhookAction: args.action,
      sourceUpdatedAt: timeEntry.at ? Date.parse(timeEntry.at) : timestamp,
      updatedAt: timestamp,
    };

    let sessionId: Id<"intentSessions">;
    let lifecycle: "started" | "stopped" | "updated" | "created_completed" | "deleted";

    if (existing) {
      await ctx.db.patch(existing._id, patch);
      sessionId = existing._id;

      if (existing.status === "running" && status === "completed") {
        lifecycle = "stopped";
      } else if (status === "deleted") {
        lifecycle = "deleted";
      } else {
        lifecycle = "updated";
      }
    } else {
      sessionId = await ctx.db.insert("intentSessions", {
        ...patch,
        createdAt: timestamp,
      });

      lifecycle = status === "running" ? "started" : "created_completed";
    }

    const session = await ctx.db.get(sessionId);
    if (!session) {
      throw new Error("Failed to load session after upsert.");
    }

    return {
      sessionId,
      lifecycle,
      session: toSessionSummary(session),
    };
  },
});

export const markFocusStarted = internalMutation({
  args: {
    sessionId: v.string(),
    deviceId: v.string(),
  },
  handler: async (ctx, args) => {
    const sessionId = args.sessionId as Id<"intentSessions">;
    const session = await ctx.db.get(sessionId);
    if (!session) {
      return null;
    }

    const timestamp = now();
    await ctx.db.patch(sessionId, {
      focusStatus: "started",
      focusStartedAt: timestamp,
      focusDeviceId: args.deviceId,
      updatedAt: timestamp,
    });

    return await ctx.db.get(sessionId);
  },
});

export const markSessionDeletedBySourceId = internalMutation({
  args: {
    action: v.string(),
    sourceTimeEntryId: v.string(),
    sourceUpdatedAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("intentSessions")
      .withIndex("by_sourceTimeEntryId", (q: any) =>
        q.eq("sourceTimeEntryId", args.sourceTimeEntryId),
      )
      .first();

    if (!session) {
      return null;
    }

    const timestamp = now();
    await ctx.db.patch(session._id, {
      status: "deleted",
      reviewStatus:
        session.reviewStatus === "submitted" ? "submitted" : "skipped",
      lastWebhookAction: args.action,
      sourceUpdatedAt: args.sourceUpdatedAt ?? timestamp,
      updatedAt: timestamp,
    });

    return await ctx.db.get(session._id);
  },
});

export const markFocusCompleted = internalMutation({
  args: {
    sessionId: v.string(),
    deviceId: v.string(),
  },
  handler: async (ctx, args) => {
    const sessionId = args.sessionId as Id<"intentSessions">;
    const session = await ctx.db.get(sessionId);
    if (!session) {
      return null;
    }

    const timestamp = now();
    await ctx.db.patch(sessionId, {
      focusStatus: "completed",
      focusCompletedAt: timestamp,
      focusDeviceId: args.deviceId,
      updatedAt: timestamp,
    });

    return await ctx.db.get(sessionId);
  },
});

export const markReviewPresented = internalMutation({
  args: {
    sessionId: v.string(),
    deviceId: v.string(),
  },
  handler: async (ctx, args) => {
    const sessionId = args.sessionId as Id<"intentSessions">;
    const session = await ctx.db.get(sessionId);
    if (!session) {
      return null;
    }

    const timestamp = now();
    await ctx.db.patch(sessionId, {
      reviewStatus: "presented",
      reviewPresentedAt: timestamp,
      reviewPresentedDeviceId: args.deviceId,
      updatedAt: timestamp,
    });

    return await ctx.db.get(sessionId);
  },
});

export const submitReview = internalMutation({
  args: {
    sessionId: v.string(),
    review: v.any(),
  },
  handler: async (ctx, args) => {
    const sessionId = args.sessionId as Id<"intentSessions">;
    const session = await ctx.db.get(sessionId);
    if (!session) {
      throw new Error("Session not found.");
    }

    const timestamp = now();
    const reviewData = args.review as {
      focusScore: number;
      planAdherence: string;
      energy: string;
      distraction: string;
      taskCategory: string;
      performanceGrade?: number;
      reflection?: string;
      nextIntent?: string;
    };

    const existing = await ctx.db
      .query("intentSessionReviews")
      .withIndex("by_sessionId", (q: any) => q.eq("sessionId", sessionId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        ...reviewData,
        updatedAt: timestamp,
      });
    } else {
      await ctx.db.insert("intentSessionReviews", {
        sessionId,
        ...reviewData,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
    }

    await ctx.db.patch(sessionId, {
      reviewStatus: "submitted",
      reviewSubmittedAt: timestamp,
      updatedAt: timestamp,
    });

    return await ctx.db.get(sessionId);
  },
});

export const getDevicePollState = internalQuery({
  args: {
    deviceId: v.string(),
  },
  handler: async (ctx, args) => {
    const integration = await getIntegrationDoc(ctx);
    const device = await getDeviceDoc(ctx, args.deviceId);
    if (!device) {
      return null;
    }

    const runningSessions = await ctx.db
      .query("intentSessions")
      .withIndex("by_status_startTimeMs", (q: any) => q.eq("status", "running"))
      .order("desc")
      .collect();

    const activeSession = runningSessions[0] ?? null;
    const pendingFocusStart =
      device.autoStartFocus && activeSession?.focusStatus === "pending"
        ? activeSession
        : null;

    const pendingFocusCompleteSessions = await ctx.db
      .query("intentSessions")
      .withIndex("by_status_startTimeMs", (q: any) => q.eq("status", "completed"))
      .order("asc")
      .collect();

    const pendingFocusComplete =
      device.autoCompleteFocus
        ? pendingFocusCompleteSessions.find(
            (session) => session.focusStatus === "started",
          ) ?? null
        : null;

    const pendingReviewSessions = (
      await Promise.all(
        ["pending", "presented"].map((status) =>
          ctx.db
            .query("intentSessions")
            .withIndex("by_reviewStatus_updatedAt", (q: any) =>
              q.eq("reviewStatus", status),
            )
            .order("asc")
            .collect(),
        ),
      )
    ).flat();

    const pendingReview =
      device.autoShowReview
        ? pendingReviewSessions.find((session) =>
            isPendingReviewStatus(session.reviewStatus),
          ) ?? null
        : null;

    const activeReviewDoc = pendingReview
      ? await ctx.db
          .query("intentSessionReviews")
          .withIndex("by_sessionId", (q: any) => q.eq("sessionId", pendingReview._id))
          .first()
      : null;

    return {
      device: {
        id: device.deviceId,
        name: device.name,
        platform: device.platform,
        isDefault: device.isDefault,
        autoStartFocus: device.autoStartFocus,
        autoCompleteFocus: device.autoCompleteFocus,
        autoShowReview: device.autoShowReview,
        startShortcutName: device.startShortcutName ?? null,
        completeShortcutName: device.completeShortcutName ?? null,
        lastSeenAt: device.lastSeenAt ?? null,
      },
      integration: {
        defaultDeviceId: integration.defaultDeviceId ?? null,
        togglWorkspaceId: integration.togglWorkspaceId ?? null,
        togglWebhookSubscriptionId: integration.togglWebhookSubscriptionId ?? null,
        togglWebhookUrl: integration.togglWebhookUrl ?? null,
        togglWebhookValidatedAt: integration.togglWebhookValidatedAt ?? null,
        lastWebhookAt: integration.lastWebhookAt ?? null,
        lastWebhookAction: integration.lastWebhookAction ?? null,
        lastWebhookTimeEntryId: integration.lastWebhookTimeEntryId ?? null,
        lastWebhookError: integration.lastWebhookError ?? null,
      },
      activeSession: activeSession ? toSessionSummary(activeSession) : null,
      pendingFocusStart: pendingFocusStart
        ? toSessionSummary(pendingFocusStart)
        : null,
      pendingFocusComplete: pendingFocusComplete
        ? toSessionSummary(pendingFocusComplete)
        : null,
      pendingReview: pendingReview
        ? {
            ...toSessionSummary(pendingReview),
            existingReview: activeReviewDoc
              ? {
                  focusScore: activeReviewDoc.focusScore,
                  planAdherence: activeReviewDoc.planAdherence,
                  energy: activeReviewDoc.energy,
                  distraction: activeReviewDoc.distraction,
                  taskCategory: activeReviewDoc.taskCategory,
                  performanceGrade: activeReviewDoc.performanceGrade ?? null,
                  reflection: activeReviewDoc.reflection ?? "",
                  nextIntent: activeReviewDoc.nextIntent ?? "",
                }
              : null,
          }
        : null,
      pendingReviewsCount: pendingReviewSessions.length,
    };
  },
});
