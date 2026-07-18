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
- `AppColorsTheme` as `ThemeExtension<AppColorsTheme>` — single source of truth for dark/light mode colors

## Progress

### Done
- **`isDark` elimination complete** — 632 ternary branching sites across 48 files → zero remaining in screen code. Only the definition getter in `context_extensions.dart` remains.
- **`AppColorsTheme` ThemeExtension** — `lib/core/theme/app_colors_theme.dart` with 11 semantic finance tokens: `incomeColor`, `expenseColor`, `transferColor`, `surfaceLow`, `surfaceHigh`, `surfaceContainer`, `bgColor`, `onBgColor`, `textMedium`, `textLow`, `scaffoldLine`. Registered in `AppTheme.fromColorScheme()`. Accessor via `context.appColors`.
- **`AppTypographyTheme` re-exported** — `app_theme.dart` now `export`s `app_typography_theme.dart` so all files importing `app_theme.dart` get the type for `extension<>()` calls
- **`ts()` helper** — Added to `context_extensions.dart`: `context.ts(13, fontWeight: FontWeight.w600)` returns `bodySmall!.copyWith()` matching the target size
- **Unified `inputDecoration()` extension** — Single method on `BuildContext` in `context_extensions.dart`: filled background, 16px radius, consistent label/hint/error styles, prefix/suffix icon padding (12px). Replaces 49 near-duplicate overrides.
- **SuccessCheckmark enhanced** — `lib/presentation/common/widgets/motion/success_checkmark.dart`: spring bounce overshoot (1.0→1.25→0.95→1.0), glow arc (`MaskFilter.blur` 16px), filled colored circle + white checkmark, ring reveal arc, `play()` method, optional `color` param
- **Skeleton shimmer theme-aware** — Fixed `_pulseBar` accessing `Theme.of(this.context)` in StatelessWidget → passes `theme` from `LayoutBuilder`'s `context` parameter
- **Empty state audit** — All 6 data-list screens already use `EmptyState` with `PesaFlowIllustration`. Dashboard `SizedBox.shrink()` is intentional hub-and-spoke.
- **Spacing audit** — 17 `kSpacingN).0` corruptions fixed across 9 files. Remaining codebase was already using `kSpacing*`.
- **`ios_list_section.dart` corruption fixed** — Restored `DefaultTheme.of(context)` → `DefaultTextStyle.merge()`
- **`const` + `Theme.of(context)` conflicts fixed** — Removed `const` from `Text`/`Row`/`Expanded`/`FittedBox` widgets using runtime `Theme.of(context)` in `analytics_screen.dart`, `savings_goal_detail_sheet.dart`, `savings_goal_detail_screen.dart`, `settings_screen.dart`, `transaction_detail_screen.dart`, `offline_payment_sheet.dart`, `payment_sheet.dart`, `recurring_transaction_form_screen.dart`
- **`_themeOption` `context` → `ctx` fix** — `settings_screen.dart` method parameter was `BuildContext ctx` but body used `Theme.of(context)` (undefined); replaced with `theme`
- **`_buildAmountField` `Theme.of(context)` → `theme`** — Top-level function in `payment_sheet.dart` had no `context` parameter; used `Theme.of(context)`, now uses `theme` parameter
- **`payment_sheet.dart` AppTypographyTheme import added** — Was missing `app_theme.dart` import for `extension<AppTypographyTheme>()`
- **`recurring_transaction_form_screen.dart` const segments fixed** — `const [ButtonSegment(...)]` with `Theme.of(context)` → non-const list with `theme.textTheme`
- **`loan_detail_screen.dart` `Theme.of(context)` → `theme` in `_buildPayoffProjection`** — Method had `theme` parameter but used `Theme.of(context)` (no `context` available)
- **All SMS parsing fixes** — Multi-message coalescing, Selcom Swahili patterns (Imethibitishwa), no defensive classifier in parsed paths, generic fallback counterparty extraction
- **Dashboard restructured** — 11→5 sections, `_SummaryNavCardRow` added, ~670 lines removed
- **GlassCard simplified** — `frosted` defaults `false`; accent strip only on interactive cards
- **Hero gradient slowed** — 10s cycle (was 6s); alpha range reduced
- **`dart analyze lib/`** — 0 issues across entire `lib/` (pdf_report_generator.dart errors also resolved)
- **SpringSheetRoute** — `lib/presentation/common/widgets/spring_sheet_route.dart`: `showSpringSheet()` via `showGeneralDialog` + `SpringSimulation` (mass 0.8, stiffness 300, damping 18) — scale 0.92→1.0, slide 60px up, fade-in. Wired into 9 call sites (IosBottomSheet, payment sheets, goal sheets, SMS category picker, mark-paid sheet).
- **AmountText balance animation fixed** — Converted `ConsumerWidget`→`ConsumerStatefulWidget`; tracks `_renderedAmount` across builds → `TweenAnimationBuilder` animates from old→new value instead of 0→new (fixes visible reset-to-zero on balance updates).
- **Transaction row highlight** — `_NewRowHighlight` in `transaction_list_screen.dart`: 2-second fade from `incomeColor` at 12% alpha → transparent on newly detected transaction IDs (cross-build diff via `_previousTransactionIds` + `_isFirstBuild`).
- **Recurring due-item pulse** — `_DueItemPulse` in `recurring_transaction_list_screen.dart`: repeating 2-second scale pulse (1.0→1.015→1.0) via `easeInOut` loop on overdue/due items.
- **Savings goal progress bar animation** — Both `LinearProgressIndicator` instances in `savings_goal_list_screen.dart` wrapped in `TweenAnimationBuilder<double>(begin: 0, end: pct, curve: easeOutCubic)` — 1s for overall, 800ms per-goal.
- **SkeletonCrossfade widget** — `lib/presentation/common/widgets/motion/skeleton_crossfade.dart`: `AnimatedSwitcher(350ms, FadeTransition)`. Awaiting wiring into screens.
- **Transaction templates** — `settings_repository.dart`: `getTransactionTemplates()`, `saveTransactionTemplate()`, `deleteTransactionTemplate()` via JSON in `app_settings` table (key: `transaction_templates`). `transaction_form_screen.dart`: "Templates" button opens picker sheet with swipe-to-delete; "Save as template" toggle in secondary details sheet saves config with name dialog after transaction save.

### In Progress
- **Typography audit** — `ts()` helper created; top-10 files still use raw `fontSize`/`fontWeight` overrides
- **Micro-interactions** — `SuccessCheckmark` enhanced but not wired into SMS approve, transaction save, or payment complete. `_NewRowHighlight`, `_DueItemPulse`, `TweenAnimationBuilder` progress bars done. Remaining: spring on remaining sheets, `TactileSpringContainer` on flat buttons.
- **Reduced motion** — Not started

### Blocked
- (none)

## Key Decisions
- **`ts()` helper over batch-replace**: Automated `TextStyle(fontSize:)` → `theme.textTheme.*` causes import scope errors and const-eval conflicts. Per-file manual replacement is safer.
- **`AppTypographyTheme` re-export**: Rather than adding imports to every file, `app_theme.dart` re-exports it so `extension<AppTypographyTheme>()` works with a single import.
- **`DefaultTextStyle.merge` over raw `TextStyle`**: For `IosListSection` with `Widget title`/`Widget subtitle`, merge correctly propagates theme styles to child widget trees.
- **`Theme.of(context)` → `theme` parameter pattern**: When methods/functions already receive `ThemeData`, use it instead of `Theme.of(context)` to avoid `context` scope issues.
- **`isDark` elimination**: 632 sites → 0 branching decisions. Only the `context.isDark` getter remains as the single source of truth.
- **Spacing audit already done**: Only 17 corruptions found and fixed; codebase was already using `kSpacing*`.
- **Flat cards over glass**: `BackdropFilter` GPU-heavy; reserve for overlays.
- **Hub-and-spoke dashboard**: Compress secondary features into nav cards; show only what needs attention.
- **No defensive classifier on parsed messages**: Trust the parser when it extracts a concrete transaction.

## Next Steps
1. **Micro-interactions** — Wire `SuccessCheckmark` into SMS approve, transaction save, payment complete. Apply `TactileSpringContainer` to remaining flat buttons. Add transaction row slide-in with brief highlight.
2. **Typography audit (top 10 files)** — Replace raw `fontSize` + `fontWeight` in `payment_sheet.dart`, `savings_goal_detail_screen.dart`, `analytics_screen.dart`, `transaction_form_screen.dart`, `transaction_detail_screen.dart`, `budget_form_screen.dart`, `loan_list_screen.dart`, `recurring_transaction_list_screen.dart`, `loan_detail_screen.dart`, `settings_screen.dart` with `theme.textTheme.*` using the new `ts()` helper.
3. **Reduced motion** — `MediaQuery.prefersReducedMotion` → disable springs, use `AnimationController(duration: 200)` fallback across all motion widgets.
4. **Icon unification** — Replace 401 filled `Icons.*` → `PesaFlowIcons.*`.
5. **One animation per action** — Audit all 253 tappable surfaces: pick spring *or* scale *or* haptic, not all three.

## Critical Context
- **`dart analyze lib/`**: **0 issues** across entire `lib/` (pdf_report_generator.dart errors also resolved).
- **`dart format lib/`** — 0 files changed latest pass (5 auto-formatted on first pass).
- **`isDark` elimination complete**: 632 sites → 0. Only `context_extensions.dart` utility getter remains.
- **`AppColorsTheme`** available via `context.appColors` on any `BuildContext`.
- **`AppTypographyTheme`** re-exported from `app_theme.dart`.
- **`ts()` helper** available via `PesaFlowContext` extension.
- **`inputDecoration()`** available via `PesaFlowContext` extension.
- **Spacing audit complete**: Only 17 corruptions fixed; codebase already uses `kSpacing*`.
- **`const` + `Theme.of(context)` pattern**: Any widget with `style: Theme.of(context).textTheme.*` must NOT be `const`.
- Dashboard reduced from 4,356 to ~1,697 lines; loan detail reduced from 2,735 to 828 lines.
- `GlassCard.frosted` defaults to `false`; accent strip only on `onTap` cards.
- `SwipeableCard` imports `package:flutter/physics.dart` and `package:flutter/services.dart`.
- No defensive `SmsClassifier` checks in `SmsProcessor._processParsed()` or `SelcomPesaParser.parse()`.

## Relevant Files
- `lib/core/utils/context_extensions.dart`: `PesaFlowContext` extension — `appColors`, `isDark`, `ts()`, `inputDecoration()`, `viewPadding`, `keyboardInset`, `bottomInset`, `topInset`
- `lib/core/theme/app_theme.dart`: Exports `app_typography_theme.dart`; registers `AppColorsTheme` and `AppTypographyTheme`
- `lib/core/theme/app_colors_theme.dart`: `AppColorsTheme` ThemeExtension — 11 semantic finance tokens
- `lib/core/theme/app_typography_theme.dart`: `AppTypographyTheme` — `monospace` + `labelMicro`
- `lib/core/utils/spacing.dart`: 18 `kSpacing*` constants (2→80)
- `lib/presentation/common/widgets/motion/success_checkmark.dart`: Enhanced with spring bounce, glow, filled circle
- `lib/presentation/common/widgets/glass_card.dart`: Dark-mode-aware shadows
- `lib/core/widgets/skeleton_loader.dart`: Theme-aware shimmer (fixed `this.context` → `LayoutBuilder context`)
- `lib/presentation/common/widgets/empty_state.dart`: Available and used by all 6 data-list screens
- `lib/presentation/common/ios/ios_list_section.dart`: Fixed `DefaultTheme` → `DefaultTextStyle.merge`
- `lib/domain/export/pdf_report_generator.dart`: 8 pre-existing errors — out of scope
- `lib/presentation/loans/widgets/payment_sheet.dart`, `lib/presentation/savings_goals/savings_goal_detail_screen.dart`, `lib/presentation/analytics/analytics_screen.dart`: Top-3 files with most remaining raw `fontSize`/`fontWeight`
