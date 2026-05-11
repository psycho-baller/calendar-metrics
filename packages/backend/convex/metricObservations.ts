import type { Doc } from "./_generated/dataModel";

type MetricScalar = number | boolean | string;

type StructuredReviewMetrics = {
  numericMetrics: Record<string, number>;
  countMetrics: Record<string, number>;
  booleanMetrics: Record<string, boolean>;
  taskCategory?: string;
};

type IntentionalityObservationInput = {
  hourStartMs: number;
  score: number;
  source: string;
  sourceDeviceName?: string;
};

function now() {
  return Date.now();
}

function valueFields(value: MetricScalar) {
  if (typeof value === "number") {
    return {
      valueType: "number",
      numberValue: value,
      booleanValue: undefined,
      stringValue: undefined,
    };
  }

  if (typeof value === "boolean") {
    return {
      valueType: "boolean",
      numberValue: undefined,
      booleanValue: value,
      stringValue: undefined,
    };
  }

  return {
    valueType: "string",
    numberValue: undefined,
    booleanValue: undefined,
    stringValue: value,
  };
}

function eventObservationEntries(
  event: Doc<"events">,
  metrics: Record<string, MetricScalar>,
) {
  return Object.entries(metrics).map(([key, value]) => ({
    subjectType: "event",
    subjectId: event._id,
    eventId: event._id,
    sessionId: undefined,
    calendarId: event.calendarId,
    workspaceId: undefined,
    key,
    ...valueFields(value),
    subjectTitle: event.title,
    observedAt: event.startTime,
    source: "calendar_event",
    createdAt: now(),
    updatedAt: now(),
  }));
}

function sessionObservationEntries(
  session: Doc<"intentSessions">,
  review: StructuredReviewMetrics,
) {
  const subjectTitle = session.description ?? "Untitled session";
  const observedAt = session.startTimeMs;
  const entries: Array<Record<string, unknown>> = [];

  for (const [key, value] of Object.entries(review.numericMetrics)) {
    entries.push({
      subjectType: "intentSession",
      subjectId: session._id,
      eventId: undefined,
      sessionId: session._id,
      calendarId: undefined,
      workspaceId: session.workspaceId,
      key,
      ...valueFields(value),
      subjectTitle,
      observedAt,
      source: "intent_review",
      createdAt: now(),
      updatedAt: now(),
    });
  }

  for (const [key, value] of Object.entries(review.countMetrics)) {
    entries.push({
      subjectType: "intentSession",
      subjectId: session._id,
      eventId: undefined,
      sessionId: session._id,
      calendarId: undefined,
      workspaceId: session.workspaceId,
      key,
      ...valueFields(value),
      subjectTitle,
      observedAt,
      source: "intent_review",
      createdAt: now(),
      updatedAt: now(),
    });
  }

  for (const [key, value] of Object.entries(review.booleanMetrics)) {
    entries.push({
      subjectType: "intentSession",
      subjectId: session._id,
      eventId: undefined,
      sessionId: session._id,
      calendarId: undefined,
      workspaceId: session.workspaceId,
      key,
      ...valueFields(value),
      subjectTitle,
      observedAt,
      source: "intent_review",
      createdAt: now(),
      updatedAt: now(),
    });
  }

  const taskCategory = review.taskCategory?.trim();
  if (taskCategory) {
    entries.push({
      subjectType: "intentSession",
      subjectId: session._id,
      eventId: undefined,
      sessionId: session._id,
      calendarId: undefined,
      workspaceId: session.workspaceId,
      key: "taskCategory",
      ...valueFields(taskCategory),
      subjectTitle,
      observedAt,
      source: "intent_review",
      createdAt: now(),
      updatedAt: now(),
    });
  }

  return entries;
}

async function replaceSubjectObservations(
  ctx: any,
  subjectType: "event" | "intentSession",
  subjectId: string,
  entries: Array<Record<string, unknown>>,
) {
  const existing = await ctx.db
    .query("metricObservations")
    .withIndex("by_subjectType_subjectId", (q: any) =>
      q.eq("subjectType", subjectType).eq("subjectId", subjectId),
    )
    .collect();

  for (const observation of existing) {
    await ctx.db.delete(observation._id);
  }

  for (const entry of entries) {
    await ctx.db.insert("metricObservations", entry);
  }
}

export async function replaceMetricObservationsForEvent(
  ctx: any,
  event: Doc<"events">,
  metrics: Record<string, MetricScalar>,
) {
  await replaceSubjectObservations(
    ctx,
    "event",
    event._id,
    eventObservationEntries(event, metrics),
  );
}

export async function replaceMetricObservationsForIntentSession(
  ctx: any,
  session: Doc<"intentSessions">,
  review: StructuredReviewMetrics,
) {
  await replaceSubjectObservations(
    ctx,
    "intentSession",
    session._id,
    sessionObservationEntries(session, review),
  );
}

export async function upsertHourlyIntentionalityObservation(
  ctx: any,
  input: IntentionalityObservationInput,
) {
  const timestamp = now();
  const subjectType = "intentionalityHour";
  const subjectId = `intentionality:${input.hourStartMs}`;
  const subjectTitle = input.sourceDeviceName
    ? `Intentionality hour from ${input.sourceDeviceName}`
    : "Intentionality hour";

  const existing = await ctx.db
    .query("metricObservations")
    .withIndex("by_subjectType_subjectId", (q: any) =>
      q.eq("subjectType", subjectType).eq("subjectId", subjectId),
    )
    .collect();
  const scoreObservation = existing.find(
    (observation: Doc<"metricObservations">) =>
      observation.key === "intentionality",
  );

  for (const observation of existing) {
    if (observation._id !== scoreObservation?._id) {
      await ctx.db.delete(observation._id);
    }
  }

  const valuePatch = {
    ...valueFields(input.score),
    subjectTitle,
    observedAt: input.hourStartMs,
    source: input.source,
    updatedAt: timestamp,
  };

  if (scoreObservation) {
    await ctx.db.patch(scoreObservation._id, valuePatch);
    return await ctx.db.get(scoreObservation._id);
  }

  const observationId = await ctx.db.insert("metricObservations", {
    subjectType,
    subjectId,
    eventId: undefined,
    sessionId: undefined,
    calendarId: undefined,
    workspaceId: undefined,
    key: "intentionality",
    ...valuePatch,
    createdAt: timestamp,
  });

  return await ctx.db.get(observationId);
}
