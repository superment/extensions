# Days 2 — Raycast Extension

Countdown to all-day events from Google Calendar.

## Project Summary

A Raycast extension that connects to Google Calendar via OAuth, fetches all-day events, and displays countdowns showing how many days/weeks/months until each event. Built from scratch as a first Raycast extension.

## Architecture

```
src/
├── days2.tsx              # Main command — list view with hero, upcoming, past sections
├── manage-calendars.tsx   # Calendar selection command — toggle which calendars to show
├── background-refresh.tsx # No-view command (1h interval) — updates subtitle in Raycast root search
├── oauth.ts               # Google OAuthService setup (iOS client type, bundle ID: com.raycast)
├── google-calendar.ts     # Google Calendar API v3 calls (authenticated fetch wrapper)
├── storage.ts             # LocalStorage helpers for calendar selection persistence
├── types.ts               # TypeScript interfaces (GoogleCalendar, AllDayEvent, DisplayMode)
└── utils.ts               # Date calculations, formatting, display mode cycling
```

## Commands

| Command | Mode | Description |
|---------|------|-------------|
| `days2` | view | Main list — hero event + upcoming + past (when searching) |
| `manage-calendars` | view | Toggle calendar selection with Select/Deselect All |
| `background-refresh` | no-view (1h) | Updates nearest event subtitle in Raycast root search |

## Key Design Decisions

### OAuth
- Uses `OAuthService.google()` from `@raycast/utils` with `RedirectMethod.AppURI`
- Requires iOS-type OAuth Client ID with bundle ID `com.raycast`
- Client ID stored in extension preferences
- Scope: `calendar.readonly`

### Display Modes
- Toggle cycles: **days → weeks → months → days** (no "date" mode in toggle)
- Date is always shown as secondary text on every item (hero and upcoming)
- Per-event override via `useState<Record<string, DisplayMode>>`
- Default mode configurable in preferences

### UI Layout
- **Hero (Next Event)**: date in secondary text + countdown in bold tag (PrimaryText)
- **Upcoming items**: date in secondary text + countdown in secondary text (not bold)
- **Past events**: only shown when search text is non-empty
- Calendar dropdown filter with `storeValue={true}`

### Background Refresh
- Subtitle format: `Event Name – 12 days` (en dash, no "in" prefix)
- Shows "Today" for same-day events
- Silently catches errors (keeps last known subtitle)

## Tech Stack

- `@raycast/api` ^1.104.8
- `@raycast/utils` ^2.2.3 (OAuth, `useCachedPromise`, `withAccessToken`)
- TypeScript 5.7+
- No external fetch library (Raycast runtime has global `fetch`)

## Build & Lint

```bash
npm run dev          # ray develop (hot reload)
npm run build        # ray build
npm run lint         # ray lint (ESLint + Prettier)
npm run fix-lint     # ray lint --fix
```

## Google Cloud Setup

1. Create project, enable Google Calendar API
2. OAuth consent screen: External, scope `calendar.readonly`, add yourself as test user
3. Create OAuth Client ID: **iOS** type, bundle ID: **`com.raycast`**
4. Enter Client ID in Raycast extension preferences

## Conventions

- Author: `datboi`
- ESLint config: `@raycast` preset
- All commands wrapped with `withAccessToken(google)(...)`
- All-day events filtered by `event.start.date !== undefined`
- Recurring events expanded with `singleEvents: true`
- `Promise.allSettled` for parallel multi-calendar fetching
- Minimum 1 calendar must stay selected (enforced in storage)

## Git

- Remote: `https://github.com/superment/days2-raycast.git`
- Branch: `main`
- Commit style: imperative mood, concise summary + bullet details
