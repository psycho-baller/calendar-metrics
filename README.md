# calendar-metrics

This project was created with [Better-T-Stack](https://github.com/AmanVarshney01/create-better-t-stack), a modern TypeScript stack that combines React, TanStack Start, Convex, and more.

## Features

- **TypeScript** - For type safety and improved developer experience
- **TanStack Start** - SSR framework with TanStack Router
- **React Native** - Build mobile apps using React
- **Expo** - Tools for React Native development
- **TailwindCSS** - Utility-first CSS for rapid UI development
- **shadcn/ui** - Reusable UI components
- **Convex** - Reactive backend-as-a-service platform
- **Authentication** - Better-Auth
- **Turborepo** - Optimized monorepo build system

## Getting Started

First, install the dependencies:

```bash
bun install
```

## Convex Setup

This project uses Convex as a backend. You'll need to set up Convex before running the app:

```bash
bun run dev:setup
```

Follow the prompts to create a new Convex project and connect it to your application.

Copy environment variables from `packages/backend/.env.local` to `apps/*/.env`.

Then, run the development server:

```bash
bun run dev
```

Open [http://localhost:3001](http://localhost:3001) in your browser to see the web application.
Use the Expo Go app to run the mobile application.
Your app will connect to the Convex cloud backend automatically.

## Intent macOS + Toggl Setup

The repo now includes a macOS companion app at `apps/Intent` and backend HTTP routes for Toggl-driven focus sessions.

Add these variables to `packages/backend/.env.local` before running Convex:

```bash
INTENT_SETUP_KEY=choose-a-random-setup-key
INTENT_PUBLIC_BASE_URL=https://your-convex-site-host
TOGGL_API_TOKEN=your_toggl_api_token
TOGGL_WORKSPACE_ID=1234567
```

Notes:

- `INTENT_PUBLIC_BASE_URL` must be your Convex HTTP actions host, which ends in `.convex.site`. Do not use `CONVEX_URL` (`.convex.cloud`) here because the `/intent/*` routes are served from the site host.
- `TOGGL_API_TOKEN` and `TOGGL_WORKSPACE_ID` are used to create/update the Toggl webhook subscription automatically.
- The macOS app calls Raycast Focus via the `shortcuts` CLI, so Raycast Focus shortcuts must already exist on the Mac.

### Intent endpoints

These routes are exposed by Convex:

- `POST /intent/bootstrap`
- `POST /intent/device/poll`
- `POST /intent/device/focus/start`
- `POST /intent/device/focus/complete`
- `POST /intent/device/review/presented`
- `POST /intent/device/review/submit`
- `POST /intent/webhooks/toggl`
- `GET /intent/health`

## Project Structure

```
calendar-metrics/
├── apps/
│   ├── web/         # Frontend application (React + TanStack Start)
│   ├── native/      # Mobile application (React Native, Expo)
├── packages/
│   ├── backend/     # Convex backend functions and schema
```

## Available Scripts

- `bun run dev`: Start all applications in development mode
- `bun run build`: Build all applications
- `bun run dev:web`: Start only the web application
- `bun run dev:setup`: Setup and configure your Convex project
- `bun run check-types`: Check TypeScript types across all apps
- `bun run dev:native`: Start the React Native/Expo development server
