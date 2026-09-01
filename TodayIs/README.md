# TodayIs

A tiny offline iOS app: every day it surfaces one or more "national day" observances,
shows today's front and center, lets you browse other dates, and fires a daily local
notification. No backend, no accounts. All data ships in `Resources/observances.json`.

## Adding these files to an Xcode project

1. Create a new Xcode project → **App** → SwiftUI, name it `TodayIs`, min iOS 17
   (uses `ContentUnavailableView`, `onChange(of:_:)` two-param form, `@Observable`-free
   `ObservableObject`). Delete the generated `ContentView.swift` and `TodayIsApp.swift`.
2. Drag the `App`, `Models`, `Notifications`, `Views`, `Resources` folders into the
   project navigator. Check **Copy items if needed** and **Create groups**.
3. Confirm `observances.json` appears in **Target → Build Phases → Copy Bundle Resources**.
4. Notifications: no special capability is required for *local* notifications, but add a
   usage rationale if you later add provisional auth. First launch will prompt when the
   user enables the toggle in Settings.
5. Build & run. Enable "Send a daily notification" in the Settings tab to schedule.

## File map

| File | Role |
|------|------|
| `App/TodayIsApp.swift` | `@main`, injects env objects, re-arms notifications on `.active` |
| `Models/Observance.swift` | `Observance`, `ObservanceCategory`, `FixedDate`, `FloatingRule`, decoding, date resolution |
| `Models/ObservanceCatalog.swift` | Loads JSON, resolves dates per year, `observances(on:category:)`, `days(from:through:)`, `upcoming(...)` |
| `Models/AppSettings.swift` | `@AppStorage`-backed prefs: notification on/off, time, featured category, 18+ unlock |
| `Notifications/NotificationManager.swift` | Auth request + rolling 14-day pre-scheduled `UNCalendarNotificationTrigger`s |
| `Views/RootView.swift` | `TabView`: Today / Browse / Settings |
| `Views/TodayView.swift` | Primary card + "Also today" list, category picker |
| `Views/BrowseView.swift` | Date-anchored grouped list, `PRIMARY` badge, jump-to-date |
| `Views/ObservanceDetailView.swift` | Full blurb, tags, source link |
| `Views/SettingsView.swift` | Notification controls, 18+ gate with confirm alert, debug tools |
| `Views/CategoryPicker.swift` | Segmented picker limited to unlocked categories |

## JSON schema (`schemaVersion: 1`)

```jsonc
{
  "schemaVersion": 1,
  "observances": [
    {
      "id": "national-dance-day",      // stable unique slug; used in notification userInfo
      "title": "National Dance Day",
      "blurb": "Short 1-sentence description shown on the card and in the push body.",
      "category": "general",           // "general" | "funny" | "adult"
      "tags": ["arts", "fitness"],     // optional, free-form; shown as chips
      "priority": 55,                  // optional (default 50). Higher = chosen as the day's PRIMARY
      "source": "https://...",         // optional; shown as a link in detail view

      // Provide EXACTLY ONE of `date` or `rule`:
      "date": { "month": 7, "day": 4 },              // fixed calendar date
      "rule": { "month": 9, "weekday": 7, "ordinal": 3 } // 3rd Saturday of September
    }
  ]
}
```

### `rule` semantics

- `weekday`: `1 = Sunday … 7 = Saturday` (matches `Foundation.Calendar`).
- `ordinal`: `1…5` = the Nth occurrence in the month; `-1` = the **last** occurrence.
- Resolved lazily per year and cached (`ObservanceCatalog.resolved(forYear:)`).

### Multiple observances on one day

All observances that resolve to the same calendar date **and** the same category are
grouped into a `DayObservances`. `primary` = highest `priority` (ties broken
alphabetically by title). The rest are `others`. The daily notification always features
`primary` for the user's chosen `notifyCategory` and appends "(+N more observances today)".

## How notifications work (no server)

`UNCalendarNotificationTrigger` can't vary its body per day when repeating, so instead:

1. On every launch and every foreground (`scenePhase == .active`), `NotificationManager.reschedule`
   removes our pending requests (`todayis.daily.*`) and schedules the next **14 days**,
   one non-repeating request each, with that day's resolved primary observance baked into
   the content.
2. As long as the user opens the app at least once every ~2 weeks, the pipeline stays full.
3. Identifiers are `todayis.daily.<dayOffset>` so re-arming is idempotent.

If you want longer resilience without opening the app, add a `BGAppRefreshTask` that calls
`reschedule` — schema and logic don't change.

## Tests

Two ways to run `TodayIsTests/DatasetCoverageTests.swift` (macOS only — no Swift toolchain on Windows):

**A. Command line, no Xcode project needed.** From the repo root:

```sh
swift test
```

`Package.swift` compiles only the Foundation-only `TodayIs/Models/` layer as `TodayIsCore`
plus the tests, with `observances.json` bundled as a SwiftPM resource. Fastest feedback loop
for dataset work.

**B. Inside the Xcode app project.** Add the file to a `TodayIsTests` unit-test target,
change the import to `@testable import TodayIs`, and give `Resources/observances.json`
Target Membership in that test target too.

What the tests check:

- **Integrity:** unique ids, exactly one of `date`/`rule`, fixed dates are real calendar
  dates, `rule` fields in range, every entry resolves for the current year.
- **Resolver correctness:** floating rules checked against known 2026 dates (Thanksgiving,
  Mother's/Father's Day, last-Monday, last-Friday).
- **`testGeneralCoverageReport`** — informational; prints the covered/total count and any
  days of the current year with no `general` observance.
- **`testEveryDayHasAGeneralObservance`** — strict gate: fails if any calendar day lacks a
  `general` observance. Enforced (no longer skipped).

## Dataset status

~417 entries (378 `general`, 23 `funny`, 16 `adult`). Every calendar day, including
Feb 29, has at least one fixed-date `general` observance, so the General tab is never
empty. Floating US holidays (MLK Day, Memorial Day, Thanksgiving, etc.) are `rule`-based
entries with high `priority` so they win their day.

**Before shipping:**

- **Verify dates and origin facts.** Blurbs state real-sounding origins and dates; these
  are best-effort and should be cross-checked against a canonical source. Fix `month`/`day`
  or convert to a `rule` as needed.
- **Tune `priority`** for busy days (major holidays 80–90, notable 50–65, minor food days
  30–45).
- **Keep `id` stable.** It's the notification key and any future favoriting will rely on it.
- **Tone:** `general` is fact-first with an occasional dry aside on minor days; somber days
  (Veterans Day, Memorial Day, Patriot Day, MLK, Juneteenth) stay plain. `funny`/`adult`
  lead with a fact and keep humor mild.

## Not in v1 (by design)

No accounts, no monetization, no remote data, no favoriting/history persistence beyond
`@AppStorage` settings. Hooks are left where those would slot in (`userInfo.observanceID`,
stable slugs, `ObservableObject` stores).
