# PesaFlow — Agent Context

## Goal
Refactor screens into focused widgets, polish UI to designer quality (consistent colors, typography, spacing, micro-interactions), and fix SMS parsing edge cases (multi-message coalescing, promo/transaction disambiguation).

## Constraints & Preferences
- Drift SQLite, go_router, Riverpod, Flutter 3.44.2, Dart 3.12.2
- All code passes `dart analyze` with 0 issues
- Extracted widgets derive `theme`/`isDark` from `BuildContext` not constructor parameters
- No `BackdropFilter` blur on cards by default; reserve glass effect for overlays/sheets
- Summary nav cards on dashboard replace full section expansions
- Raw `Color(0xFF…)` → `AppTheme.*` semantic colors
- Raw `fontSize` → `theme.textTheme.*`
- Raw padding/margin → `kSpacing*`
- Physics-based spring animations (`SpringSimulation`) over tween/easing for fluid feel

## Done
- **0-issue cleanup** — Fixed 21 stale constructor parameter errors (`isDark:`, `theme:`, `context:`) across `loan_detail_screen.dart`, `payment_sheet.dart`, `offline_payment_sheet.dart`
- **Emojis removed** — Verified zero emoji characters in entire codebase
- **Code conventions polished**:
  - Moved `formatLoanDate()` → `DateFormatter.shortDate()` in `core/utils/date_formatter.dart`
  - Fixed redundant ternary (`isDark ? grey[500] : grey[500]`)
  - Added `const` to `_TimelineEvent` constructor
  - Removed unused `isDark` param from `_buildLoanInfo`
  - Fixed curly brace lint in `DateFormatter.relative`
  - Fixed bracket corruption / duplicate `List.generate` block in `loan_detail_screen.dart`
- **UI polish (theme-based styling)**:
  - `transaction_tile.dart`: fully theme-driven — `theme.textTheme.*`, `AppTheme.incomeColor`/`expenseColor`, `kSpacing*`
  - `loan_info_rows.dart`: `theme.textTheme.labelMedium` + `theme.colorScheme.onSurface.withValues(alpha:)` for secondary text
  - `loan_detail_screen.dart`: 15+ raw `fontSize` → `theme.textTheme.*`; all `isDark ? Colors.white : Colors.black` → `theme.colorScheme.onSurface`; all `isDark ? Colors.grey[400/600]` → `theme.colorScheme.onSurface.withValues(alpha: 0.6)`; all `Color(0xFF10B981/E53935/FF9F0A)` → `AppTheme.incomeColor/expenseColor/tertiaryLight`
- **SMS review screen fully polished**:
  - `ConfidenceRing`: StatefulWidget with repeating `AnimationController` (2s reverse); ring pulses at `0.65 + 0.35 * pulseValue`; glow arc with `MaskFilter.blur`
  - `SwipeableCard`: `AnimatedBuilder` + `SpringSimulation` snap-back (`mass:0.6, stiffness:200, damping:18`) and fly-out (`mass:1, stiffness:300, damping:30`); drag reduces scale up to 4%; `HapticFeedback.mediumImpact()` at threshold; overlay badges use `AppTheme.*` + `theme.textTheme.titleMedium`
  - Fixed deprecated `Matrix4.translate`/`.scale` → `translateByDouble`/`scaleByDouble` with correct 4-arg signatures
  - Nav bar actions: "Select All" pill with `TactileSpringContainer` + `onSurface` utility styling; "Categorize (N)" with spring animation
  - Card action buttons: pill-shaped `TactileSpringContainer`; "Approve" gets tinted `incomeColor` background
  - Confidence badge: unified to `AppTheme.incomeColor` for both modes; padding → `kSpacing8/4`
  - Loading/error states: themed card with error icon + title + detail
  - Raw SMS container: `theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.3)`
  - All raw spacing (`fromLTRB(16,14,16,8)`, `SizedBox(height:4)`, `EdgeInsets.all(10)`, `width:40`) → `kSpacing*`
- **Multi-SMS coalescing** — Added in-memory message buffer + concatenation in `SmsProcessor` (`_messageBuffer`, `_flushBuffer`, 800ms debounce `Timer`); grouped messages from same provider joined with `\n` and parsed as combined text
- **In-memory content dedup** — Added `_recentContentKeys` set (`_ContentKey(provider, body)`) with capacity 200
- **Selcom SMS classifier fixes**:
  - Removed defensive `SmsClassifier.classify()` call from `SelcomPesaParser` Swahili fallback (was blocking real transactions with appended promo text)
  - Removed defensive `SmsClassifier.classify()` check from `SmsProcessor._processParsed()` (same reason)
  - Fixed `_extractReference` to capture Swahili `[code] Imethibitishwa` pattern
  - Fixed classifier `_hasReferencePattern` to match `[code] Imethibitishwa` (Swahili "Confirmed")
  - Fixed classifier `_hasDateTimeNearAmount` to match ISO dates (`2026-07-02` with `-`)
  - Added standalone `contains('imethibitishwa')` bonus (+2.5) in classifier (alongside `contains('confirmed')`)
- **Deduplicator sentinel detection** — Replaced hardcoded `*-REF-UNKNOWN` list with `reference.endsWith('-REF-UNKNOWN')` regex
- **Generic fallback parser improvements**:
  - New `_extractCounterparty()` method extracts sender/recipient name from `from/kutoka` (income) or `to/kwa/kwenda` (expense) — falls back to `'Unknown'`
  - Added Swahili reference labels (`Marejeleo`, `Rejeleo`, `Namba`) and `[code] Imethibitishwa` pattern to `_extractAnyReference()`
- **Provider matcher widened** — `_hasAmountPattern` regex now matches `TSH`, `TSHS`, `TZS`, and `/=`
- **GlassCard simplified**:
  - `frosted` default changed to `false` — all 70+ cards are flat by default; no `BackdropFilter` blur
  - `accentColor` strip only renders when `onTap != null` (interactive cards)
  - Accent strip height reduced from 3px to 2px; alpha lowered from 0.40-0.50 to 0.25-0.35
- **IosBottomSheet cleaned up** — Removed `LiquidGlassOverlay` (drifting animation) and `BackdropFilter` blur; solid tinted background with drag handle
- **Dashboard restructured**:
  - Removed budget rings, Savings goals section, Savings reminder, Recurring section, Loans section, SMS tracking section, Insights carousel
  - Kept: Balance hero, Action buttons, Quick actions, Monthly overview, Recent activity
  - Added `_SummaryNavCardRow`: horizontal scroll of compact 130x80px nav cards
  - Removed ~670 lines, 12+ providers, 4 unused imports
- **Hero gradient slowed** — 10s cycle; alpha: 0.12→0.18 (dark) / 0.08→0.12 (light)
- **`dart analyze lib/`** — 0 issues

## In Progress
- (none)

## Blocked
- (none)

## Key Decisions
- **Stability**: extracted widgets derive `theme`/`isDark` from `BuildContext` — no fragile constructor coupling
- **Physics-based animations**: `SpringSimulation` for natural interruptible motion; repeating `AnimationController(reverse: true)` for pulsing
- **`AnimatedBuilder` over `addListener` + `setState`**: avoids rebuilding entire widget tree on drag frames
- **Semantic color sweep**: all `Color(0xFF…)`, `isDark ? white : black`, `isDark ? grey[x] : grey[y]` → `AppTheme.*` or `theme.colorScheme.*`
- **Multi-SMS buffering over post-processing dedup**: catches root cause (split messages)
- **No defensive classifier on parsed messages**: trust the parser when it extracts a concrete transaction
- **Flat cards over glass**: `BackdropFilter` GPU-heavy; reserve for overlays
- **Hub-and-spoke dashboard**: compress secondary features into nav cards; show only what needs attention

---

## UX + UI Design Implementation Plan

### UX Layer

**1. Information Architecture Audit**
- Navigation heatmap: which screens do users visit most? What's buried 3+ taps deep?
- Bottom nav consolidation: 3-5 tabs max, clearly labeled
- Screen purpose check: every screen answers "what can I do here?" in 3 seconds

**2. Onboarding & First-Run Experience**
- Progressive onboarding: explain value before asking for SMS permissions
- Sample data: seed demo transactions so first launch isn't empty
- Tooltip system: 3-4 contextual hints on first visit to key screens

**3. Empty States (currently missing across several screens)**
- Zero transactions: illustration + "Connect your bank or add manually" CTA
- Zero budgets: illustration + "Create your first budget" CTA
- Zero SMS: illustration + "Grant SMS permissions to auto-track" CTA
- Zero loans: illustration + "Add a loan" CTA
- Pattern: image, title, description, primary action button

**4. Error Handling & Recovery**
- Error states on every async boundary (~4 screens silently show `SizedBox.shrink()`)
- Plain language errors: "Couldn't load transactions" not `Exception: E_NO_CURSOR`
- Recovery actions inline: retry button, "Go to Settings" for permission issues
- Offline banner: persistent top bar when no connection, with last-sync timestamp

**5. Feedback Systems**
- Toast consistency: unify `SnackBar` style (position, duration, action button)
- Haptic audit: confirm/destructive actions get haptic; navigation actions don't
- Loading skeleton pattern: shimmer placeholders instead of spinners on lists
- Success animation: subtle checkmark + spring on SMS approve, transaction save, payment complete

**6. Gesture Consistency**
- Swipe right → approve/complete (SMS review, notifications)
- Swipe left → delete/reject (SMS review)
- Pull to refresh → every list screen
- Long press → context menu (transactions, budgets)
- Document in `GestureConstants` class

**7. Accessibility (WCAG AA)**
- Touch targets: all icon buttons ≥48x48
- Contrast: all text passes 4.5:1 (body) / 3:1 (large)
- Screen reader labels: `Semantics` on icon-only buttons, charts, spring containers
- Reduced motion: `MediaQuery.platformBrightness` → disable springs; `AnimationController(duration: 200)` fallback
- Font scaling: test with device font size +200%

**8. Progressive Disclosure**
- Transaction form: advanced fields (split, tags, notes) behind "Show more"
- Dashboard: summary nav cards expand on tap — verify collapse state persists
- Settings: group by section, collapse advanced (backup, export, logs)
- Filter bar: collapse behind single "Filter" chip on transaction list

**9. Micro-interactions to Delight**
- Budget ring: gentle pulse when approaching limit (80%+)
- SMS card approve: card flies out with green trail (done in `SwipeableCard`)
- Transaction added: row slides in from bottom, brief highlight
- Payment complete: currency digit counter animation
- Pull to refresh: custom branded animation (not stock Material)

**10. Cognitive Load Reduction**
- Default visible actions: show top 3; hide "Export" behind overflow menu
- Consistent terminology: "Transactions" everywhere, never "Expenses"/"Payments" mixing
- Smart date defaults: this month + preset chips (7d, 30d, 90d, this year)
- Inline validation on field blur, not on submit

### UI Layer (from audit)

**11. ThemeExtension — Eliminate 614 `isDark` ternaries**
- Create `AppColorsTheme` and `AppTypographyTheme` as `ThemeExtension` classes
- Register in `MaterialApp.theme` and `darkTheme` once
- All `isDark ? A : B` → `Theme.of(context).extension<AppColorsTheme>()!.surfaceContainerHighest`
- Target: 614 sites → 0 branching decisions

**12. Spacing Audit — 850 raw values → `kSpacing*`**
- All `SizedBox(height: X)`, `EdgeInsets.all(X)`, `EdgeInsets.only/symmetric` with raw values
- Single spacing ladder: 2, 4, 8, 12, 16, 20, 24, 32, 48, 64
- Verify zero raw values remain in `lib/presentation/`

**13. Typography Audit — 355 hardcoded `fontSize` → `theme.textTheme.*`**
- Define precise type scale: 10/12/14/16/18/20/24/34/48
- Replace every raw `fontSize` with semantic token
- Remove all 205 font weight overrides (let text style define weight)

**14. Icon Unification — 401 filled + 239 outlined → all outlined**
- Replace all `Icons.*` with `PesaFlowIcons.*` equivalent
- Remove filled icon imports
- Map: `Icons.delete` → `PesaFlowIcons.delete_outline`, etc.

**15. Form Standardization — 49 custom `InputDecoration`**
- Single `inputDecoration()` extension on `BuildContext`
- One source of truth for border radius, label style, error style, prefix icon spacing

**16. State Handling — Loading/Error/Empty on every screen**
- Pattern: `asyncValue.when(data: ..., loading: ..., error: ...)`
- Error → themed error card with retry
- Loading → shimmer skeleton
- Empty → illustration + CTA (from UX #3)
- Screens to audit: onboarding, settings, analytics, budget detail, loan detail, transaction list

**17. Color Cleanup — 531 raw black/white + 238 hex literals**
- All `Colors.black`/`Colors.white` → `theme.colorScheme.onSurface`
- All hex colors → `AppTheme.*` semantic tokens (map unify duplicates first)

---

## Next Steps (ordered by impact)
1. **ThemeExtension** (#11) — eliminates 614 branching decisions, highest leverage
2. **Empty states** (#3) — biggest UX gap, screens silently show nothing
3. **Spacing audit** (#12) — 850 raw values, immediate visual rhythm improvement
4. **Typography audit** (#13) — 355 raw font sizes, enforces type scale
5. **State handling** (#16) — loading/error/empty patterns on every screen
6. **Icon unification** (#14) — consistent visual language
7. **Form standardization** (#15) — eliminate 49 near-duplicate InputDecoration
8. **Feedback systems** (#5) — toasts, haptics, skeletons, success animations
9. **Gesture consistency** (#6) — document and audit across all screens
10. **Accessibility** (#7) — touch targets, contrast, screen reader, reduced motion
11. **Onboarding & first-run** (#2) — tooltips, sample data, progressive permissions
12. **Information architecture** (#1) — navigation audit, screen purpose
13. **Progressive disclosure** (#8) — collapse advanced features
14. **Micro-interactions** (#9) — budget pulse, transaction slide-in, digit counter
15. **Cognitive load** (#10) — terminology, date presets, inline validation
16. **Error handling** (#4) — plain language, recovery actions, offline banner
17. **Color cleanup** (#17) — remaining raw black/white and hex literals
18. **Reduced motion** (#7 sub-item) — parallel with accessibility

## Relevant File Sizes (for extraction consideration)
- `dashboard_screen.dart`: ~1,697 lines (was 4,356)
- `transaction_form_screen.dart`: 1,889 lines
- `settings_screen.dart`: 1,475 lines
- `analytics_screen.dart`: 1,444 lines
- `transaction_list_screen.dart`: 1,325 lines
- `budget_list_screen.dart`: 1,049 lines

## Critical Context
- `dart analyze lib/` — 0 issues
- `dart format lib/` — 0 files changed
- `GlassCard.frosted` defaults to `false`; accent strip only on `onTap` cards
- No defensive `SmsClassifier` checks in `SmsProcessor._processParsed()` or `SelcomPesaParser.parse()`
- `SwipeableCard` imports `package:flutter/physics.dart` and `package:flutter/services.dart`

## Relevant Files
- `lib/presentation/dashboard/dashboard_screen.dart`
- `lib/presentation/dashboard/widgets/add_account_dialog.dart`
- `lib/presentation/dashboard/widgets/workspace_dialogs.dart`
- `lib/presentation/dashboard/widgets/monthly_overview_section.dart`
- `lib/presentation/loans/widgets/transaction_tile.dart`
- `lib/presentation/loans/widgets/loan_info_rows.dart`
- `lib/presentation/loans/widgets/payment_sheet.dart`
- `lib/presentation/loans/widgets/offline_payment_sheet.dart`
- `lib/presentation/loans/loan_detail_screen.dart`
- `lib/presentation/sms_review/sms_review_screen.dart`
- `lib/presentation/common/widgets/glass_card.dart`
- `lib/presentation/common/ios/ios_sheet.dart`
- `lib/presentation/common/widgets/liquid_glass.dart`
- `lib/domain/sms/sms_processor.dart`
- `lib/domain/sms/parsers/selcom_pesa_parser.dart`
- `lib/domain/sms/sms_classifier.dart`
- `lib/domain/sms/parsers/generic_fallback_parser.dart`
- `lib/domain/sms/deduplicator.dart`
- `lib/domain/sms/provider_matcher.dart`
