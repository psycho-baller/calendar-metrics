import { expo } from "@better-auth/expo";
import { createClient, type GenericCtx } from "@convex-dev/better-auth";
import { convex } from "@convex-dev/better-auth/plugins";
import { betterAuth } from "better-auth";

import type { DataModel } from "./_generated/dataModel";

import { components } from "./_generated/api";
import { query } from "./_generated/server";
import authConfig from "./auth.config";

import { internal } from "./_generated/api";
import { internalMutation } from "./_generated/server";
import { v } from "convex/values";

const siteUrl = process.env.SITE_URL!;
const nativeAppUrl = process.env.NATIVE_APP_URL || "calendar-metrics://";

export const authComponent = createClient<DataModel>(components.betterAuth);

function createAuth(ctx: GenericCtx<DataModel>) {
  return betterAuth({
    baseURL: siteUrl,
    trustedOrigins: [siteUrl, nativeAppUrl, "http://localhost:3001", "http://localhost:8081"],
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
      },
    },
    plugins: [
      expo(),
      convex({
        authConfig,
        jwksRotateOnTokenGenerationError: true,
      }),
    ],
    callbacks: {
      // @ts-ignore
      async signIn(data) {
        // Capture refresh token if present
        if (data.account && data.account.refreshToken && data.user) {
          try {
            // We need to check if ctx has runMutation (it should if it's an ActionCtx/GenericCtx)
            // But better-auth adapter context might vary.
            // Safe way: create an internal mutation and call it.
            // Verify context structure or cast it.
            // @ts-ignore
            if (ctx.runMutation) {
              // @ts-ignore
              await ctx.runMutation(internal.secrets.storeSecret, {
                userId: data.user.id,
                key: "google_refresh_token",
                value: data.account.refreshToken
              });
            }
          } catch (err) {
            console.error("Failed to store refresh token:", err);
          }
        }
        return {
          user: data.user,
          session: data.session,
          account: data.account // Return the account object to valid the sign in
        };
      }
    }
  });
}

export { createAuth };



export const getCurrentUser = query({
  args: {},
  handler: async (ctx) => {
    return await authComponent.safeGetAuthUser(ctx);
  },
});
