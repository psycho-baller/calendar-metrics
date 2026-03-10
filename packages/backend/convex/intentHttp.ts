import { internal } from "./_generated/api";
import { httpAction } from "./_generated/server";

const TOGGL_API_BASE_URL = "https://api.track.toggl.com/api/v9";
const TOGGL_WEBHOOKS_BASE_URL = "https://api.track.toggl.com/webhooks/api/v1";

type IntentSetupBody = {
  setupKey?: string;
  deviceName?: string;
  platform?: string;
  settings?: Record<string, unknown>;
};

type DeviceAuthBody = {
  deviceId?: string;
  deviceSecret?: string;
  settings?: Record<string, unknown>;
};

type ReviewBody = DeviceAuthBody & {
  sessionId?: string;
  focusScore?: number;
  planAdherence?: string;
  energy?: string;
  distraction?: string;
  taskCategory?: string;
  performanceGrade?: number;
  reflection?: string;
  nextIntent?: string;
};

type TogglWebhookPayload = {
  id?: number;
  entity?: string;
  action?: string;
  at?: string;
  user_id?: number;
  workspace_id?: number;
  validation_code?: string;
};

type TogglTimeEntry = {
  id: number;
  workspace_id: number;
  user_id?: number;
  project_id?: number | null;
  task_id?: number | null;
  description?: string | null;
  tags?: string[] | null;
  billable?: boolean | null;
  start: string;
  stop?: string | null;
  duration?: number | null;
  at?: string | null;
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
    },
  });
}

async function readJson<T>(request: Request) {
  const text = await request.text();
  if (!text) {
    return { rawBody: "", body: null as T | null };
  }

  return {
    rawBody: text,
    body: JSON.parse(text) as T,
  };
}

function getRequiredEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function getOptionalNumberEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    return undefined;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function simpleCompare(a: string, b: string) {
  if (a.length !== b.length) {
    return false;
  }

  let mismatch = 0;
  for (let index = 0; index < a.length; index += 1) {
    mismatch |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }

  return mismatch === 0;
}

async function verifyWebhookSignature(
  rawBody: string,
  request: Request,
  expectedSecret?: string,
) {
  if (!expectedSecret) {
    return true;
  }

  const secretHeader = request.headers.get("x-webhooks-secret");
  if (secretHeader && !simpleCompare(secretHeader, expectedSecret)) {
    return false;
  }

  const signatureHeader =
    request.headers.get("x-webhook-signature-256") ??
    request.headers.get("x-webhooks-signature");
  if (!signatureHeader) {
    return secretHeader ? true : false;
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(expectedSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digestBuffer = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(rawBody),
  );
  const digest = Array.from(new Uint8Array(digestBuffer));
  const hexDigest = digest.map((value) => value.toString(16).padStart(2, "0")).join("");
  const base64Digest = btoa(String.fromCharCode(...digest));
  const normalizedSignature = signatureHeader.startsWith("sha256=")
    ? signatureHeader.slice("sha256=".length)
    : signatureHeader;

  return (
    simpleCompare(normalizedSignature, hexDigest) ||
    simpleCompare(normalizedSignature, base64Digest)
  );
}

function buildWebhookUrl(baseUrl: string) {
  return new URL("/intent/webhooks/toggl", baseUrl).toString();
}

function getBasicAuthHeader(token: string) {
  return `Basic ${btoa(`${token}:api_token`)}`;
}

async function togglRequest<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const apiToken = getRequiredEnv("TOGGL_API_TOKEN");
  const response = await fetch(`${TOGGL_WEBHOOKS_BASE_URL}${path}`, {
    ...init,
    headers: {
      authorization: getBasicAuthHeader(apiToken),
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Toggl webhook request failed (${response.status}): ${errorText}`,
    );
  }

  return (await response.json()) as T;
}

async function pingTogglWebhook(
  workspaceId: number,
  subscriptionId: number,
) {
  return await togglRequest<{ status?: string }>(
    `/ping/${workspaceId}/${subscriptionId}`,
    {
      method: "POST",
    },
  );
}

async function togglApiRequest<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const apiToken = getRequiredEnv("TOGGL_API_TOKEN");
  const response = await fetch(`${TOGGL_API_BASE_URL}${path}`, {
    ...init,
    headers: {
      authorization: getBasicAuthHeader(apiToken),
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Toggl API request failed (${response.status}): ${errorText}`,
    );
  }

  return (await response.json()) as T;
}

async function ensureTogglWebhook(ctx: any) {
  const workspaceId = getOptionalNumberEnv("TOGGL_WORKSPACE_ID");
  const publicBaseUrl = process.env.INTENT_PUBLIC_BASE_URL;

  if (!workspaceId || !publicBaseUrl || !process.env.TOGGL_API_TOKEN) {
    return {
      configured: false,
      reason:
        "Set TOGGL_API_TOKEN, TOGGL_WORKSPACE_ID, and INTENT_PUBLIC_BASE_URL in packages/backend/.env.local.",
    };
  }

  const integration = await ctx.runQuery(internal.intent.getIntegrationState, {});
  const callbackUrl = buildWebhookUrl(publicBaseUrl);
  const secret =
    integration?.togglWebhookSecret ??
    `intent_${crypto.randomUUID().replace(/-/g, "")}`;
  const description =
    integration?.togglWebhookDescription ?? `intent-${workspaceId}`;

  type TogglWebhookSubscription = {
    subscription_id?: number;
    url_callback?: string;
    description?: string;
    secret?: string;
    validated_at?: string;
    workspace_id?: number;
  };

  const subscriptions = await togglRequest<TogglWebhookSubscription[]>(
    `/subscriptions/${workspaceId}`,
    {
      method: "GET",
    },
  );

  const matching = subscriptions.find(
    (subscription) =>
      subscription.subscription_id === integration?.togglWebhookSubscriptionId ||
      subscription.description === description ||
      subscription.url_callback === callbackUrl,
  );

  const payload = {
    description,
    enabled: true,
    secret,
    url_callback: callbackUrl,
    event_filters: [
      { entity: "time_entry", action: "created" },
      { entity: "time_entry", action: "updated" },
      { entity: "time_entry", action: "deleted" },
    ],
  };

  const result = matching?.subscription_id
    ? await togglRequest<TogglWebhookSubscription>(
        `/subscriptions/${workspaceId}/${matching.subscription_id}`,
        {
          method: "PUT",
          body: JSON.stringify(payload),
        },
      )
    : await togglRequest<TogglWebhookSubscription>(`/subscriptions/${workspaceId}`, {
        method: "POST",
        body: JSON.stringify(payload),
      });

  const validationTimestamp = result.validated_at
    ? Date.parse(result.validated_at)
    : undefined;

  let reason: string | undefined;
  const subscriptionId = result.subscription_id ?? matching?.subscription_id;

  if (!validationTimestamp && subscriptionId) {
    try {
      await pingTogglWebhook(workspaceId, subscriptionId);
      reason = "Triggered a Toggl webhook validation ping.";
    } catch (error) {
      reason =
        error instanceof Error
          ? `Toggl webhook ping failed: ${error.message}`
          : "Toggl webhook ping failed.";
    }
  }

  await ctx.runMutation(internal.intent.updateIntegrationState, {
    patch: {
      togglWorkspaceId: workspaceId,
      togglWebhookSubscriptionId: subscriptionId,
      togglWebhookSecret: secret,
      togglWebhookDescription: description,
      togglWebhookUrl: callbackUrl,
      togglWebhookValidatedAt: Number.isFinite(validationTimestamp)
        ? validationTimestamp
        : undefined,
      lastWebhookError:
        !validationTimestamp && reason?.startsWith("Toggl webhook ping failed")
          ? reason
          : undefined,
    },
  });

  return {
    configured: true,
    workspaceId,
    callbackUrl,
    subscriptionId: subscriptionId ?? null,
    validatedAt: validationTimestamp ?? null,
    reason,
  };
}

async function authenticateDevice(ctx: any, body: DeviceAuthBody) {
  if (!body.deviceId || !body.deviceSecret) {
    return null;
  }

  return await ctx.runQuery(internal.intent.authenticateDevice, {
    deviceId: body.deviceId,
    deviceSecret: body.deviceSecret,
  });
}

async function fetchTogglTimeEntry(
  _workspaceId: number,
  timeEntryId: number,
): Promise<TogglTimeEntry> {
  const timeEntry = await togglApiRequest<TogglTimeEntry>(
    `/me/time_entries/${timeEntryId}`,
    {
      method: "GET",
    },
  );

  return {
    id: timeEntry.id,
    workspace_id: timeEntry.workspace_id,
    user_id: timeEntry.user_id ?? undefined,
    project_id: timeEntry.project_id ?? undefined,
    task_id: timeEntry.task_id ?? undefined,
    description: timeEntry.description ?? undefined,
    tags: timeEntry.tags ?? undefined,
    billable: timeEntry.billable ?? undefined,
    start: timeEntry.start,
    stop: timeEntry.stop ?? undefined,
    duration: timeEntry.duration ?? undefined,
    at: timeEntry.at ?? undefined,
  };
}

async function fetchCurrentTogglTimeEntry() {
  const apiToken = getRequiredEnv("TOGGL_API_TOKEN");
  const response = await fetch(`${TOGGL_API_BASE_URL}/me/time_entries/current`, {
    method: "GET",
    headers: {
      authorization: getBasicAuthHeader(apiToken),
      "content-type": "application/json",
    },
  });

  if (response.status === 404 || response.status === 405) {
    return null;
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Toggl API request failed (${response.status}): ${errorText}`,
    );
  }

  const timeEntry = (await response.json()) as TogglTimeEntry | null;

  if (!timeEntry) {
    return null;
  }

  return {
    id: timeEntry.id,
    workspace_id: timeEntry.workspace_id,
    user_id: timeEntry.user_id ?? undefined,
    project_id: timeEntry.project_id ?? undefined,
    task_id: timeEntry.task_id ?? undefined,
    description: timeEntry.description ?? undefined,
    tags: timeEntry.tags ?? undefined,
    billable: timeEntry.billable ?? undefined,
    start: timeEntry.start,
    stop: timeEntry.stop ?? undefined,
    duration: timeEntry.duration ?? undefined,
    at: timeEntry.at ?? undefined,
  };
}

async function validateWebhookIfNeeded(
  payload: TogglWebhookPayload,
) {
  if (
    !payload.validation_code ||
    typeof payload.workspace_id !== "number" ||
    typeof payload.id !== "number"
  ) {
    return;
  }

  await togglRequest<unknown>(
    `/validate/${payload.workspace_id}/${payload.id}/${payload.validation_code}`,
    {
      method: "GET",
    },
  );
}

export const bootstrap = httpAction(async (ctx, request) => {
  try {
    const { body } = await readJson<IntentSetupBody>(request);
    const expectedSetupKey = process.env.INTENT_SETUP_KEY;

    if (!expectedSetupKey) {
      return json(500, {
        error:
          "Missing INTENT_SETUP_KEY on the backend. Set it in packages/backend/.env.local.",
      });
    }

    if (body?.setupKey !== expectedSetupKey) {
      return json(401, { error: "Invalid setup key." });
    }

    if (!body?.deviceName || !body.platform) {
      return json(400, {
        error: "deviceName and platform are required.",
      });
    }

    const registered = await ctx.runMutation(internal.intent.registerDevice, {
      deviceName: body.deviceName,
      platform: body.platform,
      settings: body.settings ?? {},
    });

    const webhook = await ensureTogglWebhook(ctx);
    const integration = await ctx.runQuery(internal.intent.getIntegrationState, {});

    return json(200, {
      ok: true,
      device: registered,
      integration: {
        defaultDeviceId: integration?.defaultDeviceId ?? null,
        togglWorkspaceId: integration?.togglWorkspaceId ?? null,
        togglWebhookSubscriptionId:
          integration?.togglWebhookSubscriptionId ?? null,
        togglWebhookUrl: integration?.togglWebhookUrl ?? null,
        togglWebhookValidatedAt:
          integration?.togglWebhookValidatedAt ?? null,
      },
      webhook,
    });
  } catch (error) {
    return json(500, {
      error: error instanceof Error ? error.message : "Failed to bootstrap Intent.",
    });
  }
});

export const pollDevice = httpAction(async (ctx, request) => {
  try {
    const { body } = await readJson<DeviceAuthBody>(request);
    const device = await authenticateDevice(ctx, body ?? {});
    if (!device || !body?.deviceId) {
      return json(401, { error: "Invalid device credentials." });
    }

    await ctx.runMutation(internal.intent.heartbeatDevice, {
      deviceId: body.deviceId,
      settings: body.settings ?? {},
    });

    const state = await ctx.runQuery(internal.intent.getDevicePollState, {
      deviceId: body.deviceId,
    });

    return json(200, {
      ok: true,
      state,
    });
  } catch (error) {
    return json(500, {
      error: error instanceof Error ? error.message : "Failed to poll device.",
    });
  }
});

export const pullDevice = httpAction(async (ctx, request) => {
  try {
    const { body } = await readJson<DeviceAuthBody>(request);
    const device = await authenticateDevice(ctx, body ?? {});
    if (!device || !body?.deviceId) {
      return json(401, { error: "Invalid device credentials." });
    }

    const integration = await ctx.runQuery(internal.intent.getIntegrationState, {});
    const state = await ctx.runQuery(internal.intent.getDevicePollState, {
      deviceId: body.deviceId,
    });
    const workspaceId =
      integration?.togglWorkspaceId ?? getOptionalNumberEnv("TOGGL_WORKSPACE_ID");

    if (!workspaceId || !process.env.TOGGL_API_TOKEN) {
      return json(400, { error: "Toggl integration is not configured." });
    }

    let pulled = false;
    let reason: string | null = null;
    let session: unknown = null;

    const currentTimeEntry = await fetchCurrentTogglTimeEntry();
    if (currentTimeEntry && currentTimeEntry.workspace_id === workspaceId) {
      const result = await ctx.runMutation(internal.intent.upsertSessionFromToggl, {
        action: "updated",
        timeEntry: currentTimeEntry,
      });
      pulled = true;
      reason = "Pulled the current Toggl time entry.";
      session = result.session;
    } else if (currentTimeEntry) {
      reason =
        `The active Toggl timer belongs to workspace ${currentTimeEntry.workspace_id}, not ${workspaceId}.`;
    }

    const activeSession = state?.activeSession;
    const activeSourceTimeEntryId = activeSession?.sourceTimeEntryId;
    const activeWorkspaceId = activeSession?.workspaceId ?? workspaceId;
    const activeTimeEntryId = Number(activeSourceTimeEntryId);

    if (
      activeSourceTimeEntryId &&
      Number.isFinite(activeTimeEntryId) &&
      activeSourceTimeEntryId !== String(currentTimeEntry?.id ?? "")
    ) {
      const syncedTimeEntry = await fetchTogglTimeEntry(activeWorkspaceId, activeTimeEntryId);
      const result = await ctx.runMutation(internal.intent.upsertSessionFromToggl, {
        action: "updated",
        timeEntry: syncedTimeEntry,
      });

      if (syncedTimeEntry.stop) {
        pulled = true;
        reason = "Pulled the recently stopped Toggl time entry.";
        session = result.session;
      } else if (!pulled) {
        pulled = true;
        reason = "Refreshed the active Toggl time entry from the backend record.";
        session = result.session;
      }
    }

    return json(200, {
      ok: true,
      pulled,
      reason: reason ?? "No active Toggl time entry found.",
      session,
    });
  } catch (error) {
    return json(500, {
      error: error instanceof Error ? error.message : "Failed to pull from Toggl.",
    });
  }
});

export const acknowledgeFocusStart = httpAction(async (ctx, request) => {
  try {
    const { body } = await readJson<
      DeviceAuthBody & { sessionId?: string }
    >(request);
    const device = await authenticateDevice(ctx, body ?? {});
    if (!device || !body?.deviceId || !body.sessionId) {
      return json(401, { error: "Invalid request." });
    }

    const session = await ctx.runMutation(internal.intent.markFocusStarted, {
      deviceId: body.deviceId,
      sessionId: body.sessionId,
    });

    return json(200, {
      ok: true,
      session,
    });
  } catch (error) {
    return json(500, {
      error:
        error instanceof Error ? error.message : "Failed to acknowledge focus start.",
    });
  }
});

export const acknowledgeFocusComplete = httpAction(async (ctx, request) => {
  try {
    const { body } = await readJson<
      DeviceAuthBody & { sessionId?: string }
    >(request);
    const device = await authenticateDevice(ctx, body ?? {});
    if (!device || !body?.deviceId || !body.sessionId) {
      return json(401, { error: "Invalid request." });
    }

    const session = await ctx.runMutation(internal.intent.markFocusCompleted, {
      deviceId: body.deviceId,
      sessionId: body.sessionId,
    });

    return json(200, {
      ok: true,
      session,
    });
  } catch (error) {
    return json(500, {
      error:
        error instanceof Error
          ? error.message
          : "Failed to acknowledge focus completion.",
    });
  }
});

export const acknowledgeReviewPresented = httpAction(async (ctx, request) => {
  try {
    const { body } = await readJson<
      DeviceAuthBody & { sessionId?: string }
    >(request);
    const device = await authenticateDevice(ctx, body ?? {});
    if (!device || !body?.deviceId || !body.sessionId) {
      return json(401, { error: "Invalid request." });
    }

    const session = await ctx.runMutation(internal.intent.markReviewPresented, {
      deviceId: body.deviceId,
      sessionId: body.sessionId,
    });

    return json(200, {
      ok: true,
      session,
    });
  } catch (error) {
    return json(500, {
      error:
        error instanceof Error
          ? error.message
          : "Failed to acknowledge review presentation.",
    });
  }
});

export const submitReview = httpAction(async (ctx, request) => {
  try {
    const { body } = await readJson<ReviewBody>(request);
    const device = await authenticateDevice(ctx, body ?? {});

    if (
      !device ||
      !body?.sessionId ||
      typeof body.focusScore !== "number" ||
      !body.planAdherence ||
      !body.energy ||
      !body.distraction ||
      !body.taskCategory
    ) {
      return json(400, { error: "Missing required review fields." });
    }

    const session = await ctx.runMutation(internal.intent.submitReview, {
      sessionId: body.sessionId,
      review: {
        focusScore: body.focusScore,
        planAdherence: body.planAdherence,
        energy: body.energy,
        distraction: body.distraction,
        taskCategory: body.taskCategory,
        performanceGrade: body.performanceGrade,
        reflection: body.reflection,
        nextIntent: body.nextIntent,
      },
    });

    return json(200, {
      ok: true,
      session,
    });
  } catch (error) {
    return json(500, {
      error: error instanceof Error ? error.message : "Failed to submit review.",
    });
  }
});

export const togglWebhook = httpAction(async (ctx, request) => {
  const integration = await ctx.runQuery(internal.intent.getIntegrationState, {});

  try {
    const { rawBody, body } = await readJson<TogglWebhookPayload>(request);
    if (!body) {
      return json(400, { error: "Expected JSON body." });
    }

    if (
      !body.validation_code &&
      !(await verifyWebhookSignature(
        rawBody,
        request,
        integration?.togglWebhookSecret,
      ))
    ) {
      return json(401, { error: "Webhook signature validation failed." });
    }

    await validateWebhookIfNeeded(body);

    const dedupeKey = [
      body.entity ?? "unknown",
      body.action ?? "unknown",
      body.id ?? "unknown",
      body.at ?? "unknown",
      body.validation_code ?? "no_validation_code",
    ].join(":");

    const event = await ctx.runMutation(internal.intent.recordWebhookEvent, {
      dedupeKey,
      entity: body.entity ?? "unknown",
      action: body.action ?? "unknown",
      entityId: String(body.id ?? "unknown"),
      workspaceId: body.workspace_id,
      happenedAt: body.at ? Date.parse(body.at) : undefined,
      payloadJson: rawBody || JSON.stringify(body),
    });

    await ctx.runMutation(internal.intent.updateIntegrationState, {
      patch: {
        lastWebhookAt: Date.now(),
        lastWebhookEntity: body.entity ?? "unknown",
        lastWebhookAction: body.action ?? "unknown",
        lastWebhookTimeEntryId:
          typeof body.id === "number" ? String(body.id) : undefined,
        togglWebhookValidatedAt: body.validation_code ? Date.now() : undefined,
        lastWebhookError: undefined,
      },
    });

    if (event.isDuplicate) {
      return json(200, {
        ok: true,
        duplicate: true,
      });
    }

    if (body.validation_code) {
      return json(200, {
        validation_code: body.validation_code,
      });
    }

    if (
      body.entity !== "time_entry" ||
      typeof body.workspace_id !== "number" ||
      typeof body.id !== "number" ||
      !body.action
    ) {
      return json(200, {
        ok: true,
        ignored: true,
      });
    }

    if (body.action === "deleted") {
      const deleted = await ctx.runMutation(
        internal.intent.markSessionDeletedBySourceId,
        {
          action: body.action,
          sourceTimeEntryId: String(body.id),
          sourceUpdatedAt: body.at ? Date.parse(body.at) : undefined,
        },
      );

      return json(200, {
        ok: true,
        deleted,
      });
    }

    const timeEntry = await fetchTogglTimeEntry(body.workspace_id, body.id);
    const result = await ctx.runMutation(internal.intent.upsertSessionFromToggl, {
      action: body.action,
      timeEntry,
    });

    return json(200, {
      ok: true,
      result,
    });
  } catch (error) {
    await ctx.runMutation(internal.intent.updateIntegrationState, {
      patch: {
        lastWebhookError:
          error instanceof Error ? error.message : "Unknown webhook failure.",
      },
    });

    return json(500, {
      error:
        error instanceof Error ? error.message : "Failed to process Toggl webhook.",
    });
  }
});

export const health = httpAction(async () => {
  return json(200, {
    ok: true,
    service: "intent",
  });
});
