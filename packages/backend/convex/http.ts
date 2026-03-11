import { httpRouter } from "convex/server";

import { authComponent, createAuth } from "./auth";
import {
  acknowledgeFocusComplete,
  acknowledgeFocusStart,
  acknowledgeReviewPresented,
  bootstrap,
  deviceMetrics,
  health,
  pullDevice,
  pollDevice,
  submitReview,
  togglWebhook,
} from "./intentHttp";

const http = httpRouter();

authComponent.registerRoutes(http, createAuth);

http.route({
  path: "/intent/bootstrap",
  method: "POST",
  handler: bootstrap,
});

http.route({
  path: "/intent/device/poll",
  method: "POST",
  handler: pollDevice,
});

http.route({
  path: "/intent/device/metrics",
  method: "POST",
  handler: deviceMetrics,
});

http.route({
  path: "/intent/device/pull",
  method: "POST",
  handler: pullDevice,
});

http.route({
  path: "/intent/device/focus/start",
  method: "POST",
  handler: acknowledgeFocusStart,
});

http.route({
  path: "/intent/device/focus/complete",
  method: "POST",
  handler: acknowledgeFocusComplete,
});

http.route({
  path: "/intent/device/review/presented",
  method: "POST",
  handler: acknowledgeReviewPresented,
});

http.route({
  path: "/intent/device/review/submit",
  method: "POST",
  handler: submitReview,
});

http.route({
  path: "/intent/webhooks/toggl",
  method: "POST",
  handler: togglWebhook,
});

http.route({
  path: "/intent/health",
  method: "GET",
  handler: health,
});

export default http;
