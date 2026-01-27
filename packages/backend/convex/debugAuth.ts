"use node";

import { action } from "./_generated/server";
import { components } from "./_generated/api";
import { authComponent } from "./auth";

// Debug action to check what's in the account table for the current user
export const debugAccountData = action({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.safeGetAuthUser(ctx);
    if (!user) {
      return { error: "Not authenticated" };
    }

    // Query the account table for all accounts linked to this user
    const accounts = await ctx.runQuery(components.betterAuth.adapter.findMany, {
      model: "account",
      where: [
        { field: "userId", operator: "eq", value: user._id },
      ],
    });

    // Return account data with refresh token status (not the actual token for security)
    return {
      userId: user._id,
      userEmail: user.email,
      accounts: accounts?.data?.map((acc: any) => ({
        providerId: acc.providerId,
        accountId: acc.accountId,
        hasRefreshToken: !!acc.refreshToken,
        hasAccessToken: !!acc.accessToken,
        scope: acc.scope,
        createdAt: acc.createdAt,
        updatedAt: acc.updatedAt,
      })) || [],
    };
  },
});
