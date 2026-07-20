# Akshara Unified Web Platform

A web-native recreation of the Akshara school ERP (Flutter). Same product, same
design language — adapted to desktop web conventions (sidebar, header, wide grids).

> **Independent track.** This workspace never modifies the Flutter app (`lib/`) or
> backend (`supabase/`). It talks to the same REST edge function.

## Stack

React 18 · TypeScript · Vite · Tailwind CSS · framer-motion · TanStack Query · React Router.
Design tokens are ported 1:1 from `lib/theme/*` (see `src/index.css` + `tailwind.config.ts`).

## Run

```bash
cd web
npm install
npm run dev        # http://localhost:5173
npm run build      # typecheck + production build
npm run test       # vitest
```

## Data policy (owner-locked)

The web platform holds **no fabricated business data**. Every page:

1. calls a **live API** where one exists (`VITE_DATA_MODE=live` + `VITE_API_BASE_URL`), or
2. renders **Loading / Empty / Error / "Awaiting backend"** states via `AsyncBoundary`
   against a **typed contract** (`src/lib/contracts/*`).

A single shared **Demo School** dataset (used by both Flutter and Web) is produced
later as a separate phase. See `PARITY_TRACKER.md` for build status.

## Structure

```
src/
  theme/         M15 tokens + light/dark ThemeProvider
  components/
    ui/          design-system primitives (Button, Card, DataTable, …)
    charts/      themed Recharts wrappers
    shell/       AppShell, Sidebar, Topbar, CommandPalette, RoleSwitcher
    system/      AsyncBoundary, ModuleScaffold
  lib/
    api/         client, config, useModuleQuery (no-fake-data hook)
    auth/        role model + auth context
    contracts/   typed API response shapes (no data)
    utils/       formatting, cn
  routes/        navConfig (IA + RBAC) + router (guards)
  pages/         one folder per module
```

## Adding a page

1. Add the typed contract to `src/lib/contracts/<module>.ts`.
2. Build the page under `src/pages/<module>/`, fetching via `useModuleQuery` +
   `apiFetch`, wrapped in `<AsyncBoundary>` (renders states, never mock data).
3. Register the real element in `src/routes/router.tsx` (`REAL_PAGES`).
4. Add a test; run `npm run build && npm run test`.
