# PesaFlow

PesaFlow is an offline-first Android app for tracking money in Tanzania. It reads
mobile money and bank transaction SMS on the device, turns them into a local
ledger, and layers budgeting, savings goals, loans, and recurring bills on top.
There is no account, no cloud sync, and no network call in the transaction path.

## What it does

- **SMS capture.** Listens for incoming messages in the foreground, from the
  background handler, and from the notification listener as a fallback.
- **Provider parsing.** M-Pesa, Airtel Money, Tigo Pesa/Mixx, Halopesa, Selcom
  Pesa, NMB, CRDB, and NBC each have a dedicated parser, with a generic parser
  as a last resort.
- **Transaction classification.** Weighted signals separate real receipts from
  promotions and service messages. Messages that contain marketing links are
  dropped before parsing.
- **Deduplication.** A per-provider coalescing window merges split messages
  (transfer plus fee, for example), and reference/content checks stop the same
  message being recorded twice.
- **Local storage.** Drift/SQLite, with reactive streams for every list and
  summary. Data leaves the device only when you export it.
- **Budgets.** Envelope groups (needs/wants/investments), rollover, period
  close-out, and an emergency-budget sweep into savings.
- **Savings goals, loans, and recurring bills**, including contributions,
  payoff projections, and due reminders.
- **Analytics and reports.** Monthly trends, category breakdowns, spending
  heatmap, and PDF/CSV export.
- **Android home widgets and local notifications.**

## Requirements

| Tool | Version |
| --- | --- |
| Flutter | 3.44 or newer |
| Dart | 3.12 or newer |
| Android | 7.0 (API 24) or newer |
| Device | A physical Android phone for SMS testing |

The SMS listener does not work on an emulator or on iOS.

## Getting started

```bash
git clone git@github.com:elishagerson/Pesaflow.git
cd Pesaflow
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Generated Drift and Riverpod files are committed, so `build_runner` is only
needed after changing a table or an annotated provider.

## Checks and builds

```bash
dart analyze lib test
dart format --set-exit-if-changed lib test
flutter test
flutter build apk --release
```

The suite currently has 541 tests. Most of them cover SMS parsing, budget
arithmetic, and the main screens.

## Project layout

```
lib/
  core/            router, theme tokens, formatting and context helpers
  data/            Drift database, DAOs, repositories, seed data
  domain/          SMS parsers and classifier, budget engine, analytics, export
  presentation/    screens, widgets, and Riverpod UI state
  services/        background SMS, notifications, reminders, backups, home widgets
plugins/
  another_telephony/  vendored Android telephony plugin
test/              unit and widget tests, plus SMS corpus fixtures
```

`ARCHITECTURE.md` describes the data model and request flow in more detail.

## Releases

Version history lives in [CHANGELOG.md](CHANGELOG.md). Published builds and
release notes are listed on the
[GitHub Releases page](https://github.com/elishagerson/Pesaflow/releases).

Releases are cut from tags (`v1.2.3`). The workflow in
`.github/workflows/release.yml` builds the APK and publishes the notes.
`scripts/release.sh` bumps the version, commits, and tags once the
`CHANGELOG.md` section exists; see `CONTRIBUTING.md` for the full process.

## Privacy

PesaFlow stores everything in a local SQLite file. There is no telemetry, no
analytics SDK, and no server component. The app requests SMS and notification
access only to read transaction alerts. Backups are written to a file you
choose, and exports are generated on-device.

## Contributing

Bug reports and pull requests are welcome. Read `CONTRIBUTING.md` first; it
covers the code style, test expectations, and release process.
