import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";

export const env = createEnv({
  clientPrefix: "VITE_",
  client: {
    // VITE_CONVEX_URL: z.url(),
    // VITE_CONVEX_SITE_URL: z.url(),
  },
  runtimeEnv: {
    // VITE_CONVEX_URL:
    //   (import.meta as any).env?.VITE_CONVEX_URL ??
    //   (typeof process !== "undefined" ? process.env.VITE_CONVEX_URL : undefined),
    // VITE_CONVEX_SITE_URL:
    //   (import.meta as any).env?.VITE_CONVEX_SITE_URL ??
    //   (typeof process !== "undefined" ? process.env.VITE_CONVEX_SITE_URL : undefined),
  },
  emptyStringAsUndefined: true,
});
