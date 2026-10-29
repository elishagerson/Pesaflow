# Architecture

PesaFlow is a single-process Flutter app with a local SQLite database. The
Android layer exists for one reason: to receive SMS and show home-screen
widgets. Everything else is Dart.

## Layers

```
presentation/   screens, widgets, Riverpod UI state
domain/         SMS parsing and classification, budget engine, analytics, export
data/           Drift database, DAOs, repositories, seed data
services/       background SMS, notifications, reminders, backups, home widgets
core/           router, theme, formatting, small shared helpers
plugins/        vendored another_telephony plugin
```

Dependencies point inward: presentation may read domain and data; domain does
not import presentation. Repositories wrap DAOs; screens never query Drift
directly.

## Money

All amounts are stored as integer **cents** (`TZS * 100`) to avoid floating
point drift. `currency_formatter.dart` handles display and parsing, including
Kiswahili-friendly input and the `Tsh` prefix. Percentages are stored as
doubles in the range `0.0`–`1.0`.

## Database

`lib/data/database/app_database.dart` defines the schema; generated code lives
next to it as `*.g.dart` and is committed.

| Table | Purpose |
| --- | --- |
| `Accounts` | Mobile money, bank, and cash wallets. Holds the last known balance. |
| `Transactions` | Ledger entries. Type is `income`, `expense`, `transfer`, `airtime`, or `fee`. |
| `Categories` | System and user categories, with optional parent for sub-categories. |
| `Trackers` | Optional workspaces (personal, business) that scope other records. |
| `Budgets` | Per-category envelopes with period, rollover mode, and alert threshold. |
| `BudgetGroups` | Needs / wants / investments buckets derived from income. |
| `BudgetPeriods` | One row per budget period, with allocations, spend, and rollover. |
| `SavingsGoals` | Target amount, target date, colour, icon. |
| `SavingsGoalContributions` | Deposits (positive) and withdrawals (negative). |
| `Loans` | Principal, remaining balance, installments, provider, due date. |
| `RecurringTransactions` | Bills and income with a frequency and next due date. |
| `AppSettings` | Key/value store for preferences and small JSON documents. |
| `DailySnapshots` | Cached per-day totals for analytics. |
| `MonthlySnapshots` | Cached per-month totals and category breakdowns. |

Foreign keys are enforced at the Dart level rather than through SQLite
constraints. Deleting a category or account is handled by the repository so
that dependent rows stay consistent.

## SMS pipeline

1. **Receive.** `SmsBackgroundService` handles the background handler;
   `main.dart` handles the foreground listener and the notification listener.
   All three paths call `SmsProcessor.processSms(sender, body, timestamp)`.
2. **Match the provider.** `ProviderMatcher` checks the sender shortcode first,
   then scans the body for ownership phrases when the sender is a bare number.
3. **Reject marketing.** `SmsClassifier.hasPromotionalLink` drops any message
   containing a URL or download link before buffering.
4. **Coalesce.** Messages from the same provider are buffered for 2.5 seconds
   and concatenated. Carriers often split a transfer and its fee into two
   messages; parsing them together avoids a phantom duplicate.
5. **Deduplicate.** An in-memory content cache catches the same body arriving
   through several reception paths. A database reference check catches replays
   after a restart.
6. **Parse.** `ProviderRegistry` selects a parser for the provider. If it
   returns `null`, the message is classified; only a transaction-classified
   message is retried with `GenericFallbackParser`.
7. **Reconcile.** The parser's own provider wins over the initial match, because
   a body can mention another provider as the recipient.
8. **Persist.** The transaction is created, matched to an account, and the
   account balance is updated from the carrier's stated balance when present.
9. **Categorise and notify.** `AutoCategorizer` assigns a category from
   merchant keywords. Low-confidence or manual-review cases surface in
   `/sms-review`, and a local notification is posted.

### Parsers

| Provider | Parser |
| --- | --- |
| M-Pesa (Vodacom) | `MpesaTzParser` |
| Airtel Money | `AirtelTzParser` |
| Tigo Pesa / Mixx / Yas | `MixxParser` |
| Halopesa | `HalopesaParser` |
| Selcom Pesa | `SelcomPesaParser` |
| NMB Bank | `NmbBankParser` |
| CRDB Bank | `CrdbBankParser` |
| NBC Bank | `NbcBankParser` |
| Unknown | `GenericFallbackParser` |

Parsers implement `SmsParser.parse(String body, DateTime timestamp)` and return
`SmsParsed` or `null`. `amount_helper.dart` normalises the many ways a Tanzanian
SMS can write an amount.

### Classification

`SmsClassifier` scores a message across positive signals (amount, transaction
verb, reference, balance, date near amount) and negative signals (marketing
language, absence of any amount). The score is mapped through a sigmoid to a
confidence and a label: `transaction`, `promo`, or `informational`. The
classifier is only consulted when a dedicated parser fails, so a valid receipt
is never blocked by a heuristic.

## Budgets

`BudgetEngine` is pure Dart and unit-tested independently of the database.

- `computeGroupAllocations` splits monthly income into needs, wants, and
  investments using either a preset rule or custom percentages.
- `distributeAmount` uses the largest-remainder method, so the parts always sum
  exactly to the total.
- `computePeriodEnd` handles month-end clamping (31 Jan → 28/29 Feb).
- `computeStatus` reports remaining amount, percentage used, days left, and
  pacing.

Monthly budgets are anchored to the first of the month. `BudgetRepository`
closes expired periods, rolls over eligible remainders, and reopens the next
period on the day after the previous one ends. When an emergency budget closes
with unspent funds, the repository sweeps the remainder into an emergency
savings goal and posts a notification.

## Navigation

`app_router.dart` uses `go_router` with a `StatefulShellRoute.indexedStack`.
Five tabs keep their state: dashboard, transactions, budgets, analytics, and
settings. Detail and form screens are pushed on the root navigator with a
swipe-back route on iOS and a spring sheet for modal editors.

```
/                     dashboard
/transactions         ledger, filters, detail, add/edit
/budgets              envelopes, setup, group detail, detail, add/edit
/analytics            trends and reports
/settings             preferences, data, diagnostics
/sms-review           pending SMS queue
/debug/sms-parser     parser playground (debug builds)
```

Dashboard-only screens (`/loans`, `/savings-goals`, `/recurring`) are nested
under the dashboard branch so they share its navigation stack.

## Services

| Service | Responsibility |
| --- | --- |
| `SmsBackgroundService` | Android background SMS handler and isolate entry point. |
| `NotificationService` | Local notifications, channels, and tap routing. |
| `BudgetAlertService` | Threshold and over-budget notifications. |
| `LoanReminderService`, `SavingsReminderService`, `DailySummaryService` | Scheduled reminders. |
| `AutoBudgetService` | Creates or refreshes budgets from income changes. |
| `BackupService` | Writes and restores the SQLite file. |
| `HomeWidgetsRenderer` | Renders offscreen Flutter widgets to PNG for Android home widgets. |
| `LockScreenService` | Optional local-auth gate on resume. |

## State

Riverpod providers live in `presentation/state/`. Streams come from Drift and
are exposed through repository providers; writes invalidate the affected stream
providers. `ProviderScope` wraps the app in `main.dart`.

## Theming

`AppTheme` builds light and dark `ThemeData` from a seed colour and registers
two `ThemeExtension`s:

- `AppColorsTheme` — semantic finance colours, surfaces, hairlines, shadows.
- `AppTypographyTheme` — poster, numeral, eyebrow, and monospace roles.

Widgets read colours from `context.appColors` and text styles from
`theme.textTheme` or `context.ts(...)`. There is no `context.isDark` branching
in screen code; the extension resolves both modes.

## Testing

- `test/sms_parser_test.dart` and `test/mixx_parser_test.dart` cover real message
  shapes, including the corpus in `test/fixtures/sms_corpus.dart`.
- `test/budget_engine_test.dart` covers allocation, distribution, period ends,
  and zero-income cases.
- Screen tests build the real widget tree with an in-memory database.
- `test/squircle_icons_test.dart` and `test/brand_palette_test.dart` enforce
  visual invariants that are easy to regress.

Run `flutter analyze lib test` and `flutter test` before opening a PR.

## Constraints

- SMS access is Android-only. The app builds for other platforms, but parsing
  and background capture are disabled there.
- No network calls are made in the transaction path. Fonts and images are
  bundled.
- Generated files (`*.g.dart`) are committed so a fresh checkout can build
  without running code generation first.

See `CONTRIBUTING.md` for the release process and `CHANGELOG.md` for version
history.
