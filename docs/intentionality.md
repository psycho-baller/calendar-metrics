# Intentionality Tracking

## Current Score Storage

The backend has two score paths:

- `intentSessionReviews`: one review row per work session. Numeric scores such as `focus`, `energy`, `adherence`, and `intentionality` are saved as JSON in `numericMetricsJson`; counts such as `distractions` are saved in `countMetricsJson`; booleans are saved in `booleanMetricsJson`.
- `metricObservations`: the unified analytics ledger. Calendar metrics, session review scores, and hourly intentionality entries are mirrored here as typed observations with `subjectType`, `subjectId`, `key`, `valueType`, the matching typed value field, `observedAt`, `source`, `createdAt`, and `updatedAt`.

Session review scores use `subjectType: "intentSession"` and point back to `sessionId`. Hourly intentionality scores use `subjectType: "intentionalityHour"`, `key: "intentionality"`, no session or event id, and `observedAt` set to the start of the hour.

## Shortcut Write Endpoint

Apple Shortcuts should call:

```text
POST https://<deployment>.convex.site/intent/device/intentionality/record
```

JSON body:

```json
{
  "shortcutKey": "<INTENT_SHORTCUT_KEY or INTENT_SETUP_KEY>",
  "score": 8,
  "observedAt": 1778534400000,
  "sourceDeviceName": "Rami iPhone",
  "platform": "ios"
}
```

`observedAt` is optional and may be epoch milliseconds or an ISO date string; when omitted the backend uses the receipt time. Duplicate writes for the same hour overwrite that hour's score.

## Shortcut Setup

1. Set `INTENT_SHORTCUT_KEY` in Convex environment variables. If it is not set, the endpoint accepts `INTENT_SETUP_KEY`.
2. Create a Shortcut that asks for a number between 0 and 10.
3. Add `Get Contents of URL`.
4. Use method `POST`, header `Content-Type: application/json`, and the JSON body above.
5. Create a personal automation for each hour you want covered. An `Ask for Input` step requires the device to be available for interaction, so locked or unavailable devices will not produce a score for that hour.
6. Pair the iOS Intent app from Settings with the Convex HTTP Actions URL and setup key. The app reads live data through the Convex Swift SDK.
