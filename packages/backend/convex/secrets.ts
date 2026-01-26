import { internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";

export const storeSecret = internalMutation({
  args: { userId: v.string(), key: v.string(), value: v.string() },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("userSecrets")
      .withIndex("by_userId_key", (q) => q.eq("userId", args.userId).eq("key", args.key))
      .first();
    if (existing) {
      await ctx.db.patch(existing._id, { value: args.value });
    } else {
      await ctx.db.insert("userSecrets", { userId: args.userId, key: args.key, value: args.value });
    }
  }
});

export const getSecret = internalQuery({
  args: { userId: v.string(), key: v.string() },
  handler: async (ctx, args) => {
    const secret = await ctx.db
      .query("userSecrets")
      .withIndex("by_userId_key", (q) => q.eq("userId", args.userId).eq("key", args.key))
      .first();
    return secret?.value;
  }
});
