# Changelog

All notable changes are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

No unreleased changes.

## [1.0.1] - 2026-10-29

### Added

- Savings goals: quick deposit sheet, milestone starters, completed goal
  archive, and a monthly commitment summary.
- Loans: payoff simulator, quick increment and percentage chips, payment notes,
  and a receipt-style recurring payment sheet.
- Budgets: monthly budgets anchored to the 1st, emergency surplus sweep into
  savings, and a first-month income prefill in the setup wizard.
- Recurring bills: popular bill starters, live schedule preview, and annual
  impact summary.
- Notification center grouping carrier SMS, bills, budgets, savings, and loans.
- Command palette with keyboard navigation and transaction search.
- Saved transaction templates.
- Squircle icon system and semantic colour tokens shared across light and dark
  themes.
- Reduced-motion support and centralized motion tokens.
- Android home widgets and daily summary notifications.

### Changed

- Dashboard rebuilt around a balance hero and a four-card financial hub.
- SMS review, transactions, settings, and analytics moved to flat, hairline
  surfaces; glass blur is reserved for overlays.
- Amounts and balances use tabular figures, with count-up animation limited to
  summary surfaces.
- Sheet, dialog, and tab transitions use spring-based motion.

### Fixed

- Month-end budget periods clamp correctly (31 Jan → 28/29 Feb).
- Fees are extracted when the label has no colon (`Charges TSh 500`).
- Split carrier messages are coalesced instead of producing duplicate
  transactions.
- Promotional SMS with links are rejected before parsing.
- NMB Swahili credit messages and Mixx/Yas bill payments are parsed.
- Swipe-back navigation and sheet drag-to-dismiss no longer freeze.
- Balance animation no longer resets to zero when a value updates.

## [1.0.0] - 2026-07-04

First tagged release.

- Local Drift/SQLite ledger with accounts, categories, and trackers.
- SMS parsing for M-Pesa, Airtel Money, Tigo Pesa, Halopesa, Selcom Pesa, NMB,
  CRDB, and NBC, with a generic fallback.
- Envelope budgets, analytics, CSV/PDF export, database backup, local
  notifications, and Android home widgets.
- Offline-only operation with no account or cloud sync.

[Unreleased]: https://github.com/elishagerson/Pesaflow/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/elishagerson/Pesaflow/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/elishagerson/Pesaflow/releases/tag/v1.0.0
