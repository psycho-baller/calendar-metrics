import { createFileRoute } from "@tanstack/react-router";

const NOTION_VERSION = "2022-06-28";

export const Route = createFileRoute("/api/waitlist")({
  server: {
    handlers: {
      POST: async ({ request }) => handleWaitlistRequest(request),
    },
  },
});

async function handleWaitlistRequest(request: Request) {
  try {
    const { email, platform = "Web" } = await request.json();

    if (!email || typeof email !== "string") {
      return jsonResponse({ error: "Email is required" }, 400);
    }

    const normalizedEmail = email.trim().toLowerCase();
    const isValidEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail);

    if (!isValidEmail) {
      return jsonResponse({ error: "Use a valid email address" }, 400);
    }

    const normalizedPlatform =
      typeof platform === "string" && platform.trim().length > 0
        ? platform.trim()
        : "Web";

    const notionApiKey = process.env.NOTION_API_KEY;
    const notionDataSourceId = process.env.NOTION_WAITLIST_DATASOURCE_ID;

    if (!notionApiKey || !notionDataSourceId) {
      console.error("Notion waitlist environment variables are not configured.");
      return jsonResponse({ error: "Server configuration error" }, 500);
    }

    const existingEntries = await notionRequest<{ results: Array<{ id: string }> }>(
      `https://api.notion.com/v1/data_sources/${notionDataSourceId}/query`,
      notionApiKey,
      {
        method: "POST",
        body: JSON.stringify({
          filter: {
            property: "Email",
            title: {
              equals: normalizedEmail,
            },
          },
          page_size: 1,
        }),
      },
    );

    if (existingEntries.results.length > 0) {
      return jsonResponse({
        success: true,
        alreadyAdded: true,
        message: "You're already on the waitlist.",
      });
    }

    const newPage = await notionRequest<{ id: string }>(
      "https://api.notion.com/v1/pages",
      notionApiKey,
      {
        method: "POST",
        body: JSON.stringify({
          parent: {
            type: "data_source_id",
            data_source_id: notionDataSourceId,
          },
          properties: {
            Email: {
              title: [
                {
                  text: {
                    content: normalizedEmail,
                  },
                },
              ],
            },
            Date: {
              date: {
                start: new Date().toISOString(),
              },
            },
            Platform: {
              multi_select: [
                {
                  name: normalizedPlatform,
                },
              ],
            },
            App: {
              multi_select: [
                {
                  name: "intent",
                },
              ],
            },
          },
        }),
      },
    );

    return jsonResponse({
      success: true,
      pageId: newPage.id,
      alreadyAdded: false,
      message: "Successfully joined the Intent waitlist.",
    });
  } catch (error) {
    console.error("Notion API error:", error);
    return jsonResponse(
      {
        error: `Failed to add email to waitlist: ${
          error instanceof Error ? error.message : "Unknown error"
        }`,
      },
      500,
    );
  }
}

async function notionRequest<T>(
  url: string,
  notionApiKey: string,
  init: RequestInit,
): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${notionApiKey}`,
      "Content-Type": "application/json",
      "Notion-Version": NOTION_VERSION,
      ...init.headers,
    },
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.message || data.error || "Notion request failed");
  }

  return data as T;
}

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
