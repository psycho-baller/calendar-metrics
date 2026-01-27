import { internalQuery } from "./_generated/server";

export const listSecrets = internalQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db.query("userSecrets").collect();
  },
});
