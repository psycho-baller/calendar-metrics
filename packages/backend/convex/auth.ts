import { expo } from "@better-auth/expo";
import { createClient, type GenericCtx } from "@convex-dev/better-auth";
import { convex } from "@convex-dev/better-auth/plugins";
import { betterAuth } from "better-auth";

import type { DataModel } from "./_generated/dataModel";

import { components } from "./_generated/api";
import { query } from "./_generated/server";
import authConfig from "./auth.config";

const siteUrl = process.env.SITE_URL!;
const nativeAppUrl = process.env.NATIVE_APP_URL || "intent://";

export const authComponent = createClient<DataModel>(components.betterAuth);

function createAuth(ctx: GenericCtx<DataModel>) {
  return betterAuth({
    baseURL: siteUrl,
    trustedOrigins: [siteUrl, nativeAppUrl, "http://localhost:8081"],
    database: authComponent.adapter(ctx),
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: false,
    },
    socialProviders: {
      google: {
        clientId: process.env.GOOGLE_CLIENT_ID!,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
        scope: ["https://www.googleapis.com/auth/calendar.readonly"],
        accessType: "offline",
        prompt: "consent", // Force refresh token
      },
    },
    plugins: [
      expo(),
      convex({
        authConfig,
        jwksRotateOnTokenGenerationError: true,
      }),
    ],
    // Note: Better Auth automatically stores the refresh token in its 'account' table
    // No custom signIn callback needed - we query it directly from the component
  });
}

export { createAuth };



export const getCurrentUser = query({
  args: {},
  handler: async (ctx) => {
    return await authComponent.safeGetAuthUser(ctx);
  },
});
