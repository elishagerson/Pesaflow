# UI/UX Design Brief — Budget & Expenses Tracker (Tanzania)

## Design Language: Material 3 × Apple HIG

Blend **Material Design 3** (dynamic color, elevation, motion) with **Apple Human Interface Guidelines** (clarity, deference, generous whitespace, minimal chrome). The result should feel clean, warm, and trustworthy — like a finance app made by Apple, but with Material's smart theming.

---

## Brand & Tone

| Attribute | Direction |
|---|---|
| Personality | Trustworthy, calm, empowering, local |
| Colors | Material 3 dynamic color (Monet) with warm accent. Default: emerald green + deep navy. User can pick from 6 curated palettes. |
| Typography | System font (SF Pro on iOS, Roboto on Android) at standard sizes. Monospace for all amounts. |
| Shape | Rounded corners: 12px cards, 16px dialogs, 8px inputs, 28px FABs. Apple-style squircle for icons/avatars. |
| Motion | Smooth, slow (300ms). Fade + slide for screens. Scale + spring for interactions. No unnecessary animation. |
| Darkness | Full light + dark mode. Dark mode: deep charcoal backgrounds, not pure black. Elevated surfaces slightly lighter. |

---

## Screens & Layout Requirements

### 1. Dashboard (Nyumbani)

**Layout (top to bottom):**

| Section | Component | Notes |
|---|---|---|
| App bar | Minimal. Logo/icon left. Bell icon right (for notifications/review queue badge). Translucent material blur. |
| Balance card | **Prominent card** floating with shadow. Total net worth at top: "Tsh 1,450,000". Below: mini row of account balances as pills (M-Pesa Tsh 250k, CRDB Tsh 800k, Cash Tsh 400k). Tap a pill to see that account's transactions. Card background: gradient from accent to darker shade. |
| Quick actions | Horizontal scroll row of circular icon buttons: "Add Income", "Add Expense", "Transfer", "Review Queue (badge)". SF Symbol / Material icons. |
| Monthly overview | **Card**: Left = donut chart (income green / expense red). Right = income amount, expense amount, net change. "Mwezi huu" header. |
| Budget progress | Horizontal scroll of **mini ring cards**. Each ring shows spent/allocated with category icon + remaining amount. Tap opens budget detail. Max 4 visible, "View All" link. |
| Recent transactions | List of last 5 items with: category icon, description, account pill, amount (green/red). "Tazama Zote" link at bottom. |

**Design notes:**
- Balance card is the hero — should dominate initial viewport
- Cards have subtle border (1px, low opacity) for definition on both themes
- No excessive shadows — use Material 3 elevation with Apple's soft shadows

---

### 2. Transactions (Shughuli)

**Layout:**

| Section | Component | Notes |
|---|---|---|
| App bar | Title "Shughuli". Right: search icon, filter icon (active dot when filter set). |
| Filter bar | Collapsible row below app bar. Chips: "All" | "Income" | "Expense". Date range picker button. Category dropdown. Account dropdown. Active filters shown as removable chips. |
| List | **Infinite scroll** with section headers by date ("Leo", "Jana", "15 Mei 2026"). Each item: leading category icon (colored circle), title (description), subtitle (account name + reference), trailing amount in Tsh (green or red). |
| FAB | Bottom right: "+" button. Material 3 FAB extended with label "Add" on first open, collapses to icon on scroll. |

**Design notes:**
- Pull-to-refresh triggers historical SMS re-scan
- Swipe left on item → delete with haptic confirmation
- Long press → drag to reorder (for pinned items)
- Empty state: illustration + "No transactions yet. Add one or wait for SMS."

**Filter bottom sheet:**
- Apple-style bottom sheet with handle bar
- Sections: Type (Income/Expense/All), Date Range (presets + custom), Category (grid of icons), Account (list with checkmarks)
- "Reset" link top right, "Apply" button bottom
- Active filter count shown in app bar filter icon badge

---

### 3. Transaction Form (Add / Edit)

**Layout:**

| Section | Component | Notes |
|---|---|---|
| Header | "Add Transaction" or "Edit". Apple-style large title. Cancel/Save in nav bar. |
| Amount input | **Large, centered, monospace**. Placeholder "Tsh 0". No leading currency symbol (shown outside field). Auto-format with commas as user types. |
| Type toggle | Segmented control: Income | Expense | Transfer. Apple segmented style (capsule). Changes color theme (green/red/blue). |
| Account | Picker row. Leading icon, account name, chevron. Bottom sheet picker with balance shown. |
| Category | Grid of category circles in a scrollable row. Tap to select, or "More" for full grid. Selected category has ring highlight. |
| Description | Text field. Below: auto-suggestion chips based on keywords ("Supermarket", "SALARY", "Airtime"). |
| Date | Inline date picker or "Today" button. Minimal — tap to show Apple-style wheel or calendar popover. |
| Reference (optional) | Small text field, collapsed by default. |
| Save | Full-width button at bottom. Accent color. Disabled if no amount/account/category. |

**Design notes:**
- Amount input should feel like a calculator — big, bold, immediate
- Category selection should be visual (icons + colors), not dropdown text
- Keyboard type = numeric with decimal point for amount field
- Haptics on save

---

### 4. Transaction Detail

**Layout:**

| Section | Component | Notes |
|---|---|---|
| Hero | Large amount: "Tsh 50,000" with type badge (Income/Expense). Full-bleed background in category color at 15% opacity. |
| Info rows | Stacked list: Category (icon + name), Account (icon + name + balance), Description, Reference, Provider, SMS timestamp, Source (SMS auto / Manual). Key-value style. |
| Raw SMS | Expandable section "SMS asili" showing the original message in a code-style box. Monospace, subtle background. |
| Actions | "Edit" and "Delete" buttons. Apple-style action list. Delete requires confirmation with haptic. |

---

### 5. Budgets (Bajeti)

**Layout:**

| Section | Component | Notes |
|---|---|---|
| App bar | "Bajeti". Right: "+" to add budget. |
| Summary bar | Top card: "Total Budget Tsh 1,200,000 · Spent Tsh 780,000 (65%) · Remaining Tsh 420,000". Progress bar across full width beneath. |
| Budget grid | Cards in 2-column grid. Each card: category icon+color, name, "Tsh 150,000 / Tsh 300,000", progress ring (color fills as spent increases, turns red at 100%). |
| Over-budget items | Cards with red tint, shake animation on first exceed, "Exceeded by Tsh 25,000" message. |

**Design notes:**
- Progress rings should animate on appear (spring from 0 to actual %)
- Card tap → budget detail screen
- Pull-to-refresh recalculates budget periods

**Budget Detail:**
- Large ring at top with percentage
- Below: Allocated, Spent, Remaining in three columns
- Period selector (current / previous months) as segmented control
- Transaction list for this budget's category in current period
- Rollover toggle in settings area at bottom

**Budget Form:**
- Name, category picker (only expense categories), amount, period (weekly/biweekly/monthly/yearly), start date
- Rollover section with toggle + optional cap
- Notification threshold slider (50% — 100%)

---

### 6. Analytics (Takwimu)

**Layout:**

| Section | Component | Notes |
|---|---|---|
| App bar | "Takwimu" |
| Tab bar | Underline tabs: "Overview" | "Trends" | "Insights". Apple-style tab bar. |
| **Overview tab:** | Income vs expense bar chart (current month). Category donut (tap slice to see amount). Net cashflow card. |
| **Trends tab:** | 12-month bar chart (income green bars + expense red bars stacked/grouped). Line chart overlay for net. Category picker to filter trend line for specific category. |
| **Insights tab:** | Cards in vertical scroll. Each card: icon, title, description, action link. Examples on cards. Cards have subtle background color per type. |

**Design notes:**
- Charts should be fl_chart with custom styling: rounded bar tops, soft gradients, grid lines at 25% opacity
- Tap on chart elements shows tooltip with exact value
- Empty state: "Data inaonekana baada ya shughuli 10+" (Data appears after 10+ transactions)
- Insights cards should feel like Apple Health highlights — tappable for detail

---

### 7. SMS Review Queue

**Layout:**

| Section | Component | Notes |
|---|---|---|
| App bar | "Review Queue" with count badge. |
| Instructions | Subtle banner: "Swipe right to approve · Swipe left to reject · Tap to categorize" |
| Cards | Stack of cards (Tinder-style or list). Each card: SMS preview at top, parsed amount + provider, category suggestion (with confidence %), action buttons: "Approve" (green), "Change Category" (blue), "Reject" (grey). |
| Empty state | "Hakuna shughuli za kukagua" with checkmark illustration. |

**Design notes:**
- Swipe gestures should feel tactile with haptic feedback
- "Change Category" opens category picker bottom sheet
- Approved transactions fade and move to transaction list
- Batch approve button in header

---

### 8. Settings (Mipangilio)

**Layout:**
Apple-style grouped table view (InsetGroupedTable on iOS, SectionedCard on Android).

| Section | Items |
|---|---|
| **Accounts** | List of accounts with balance. Tap to edit. "Add Account" row. |
| **Categories** | Grid of all categories. Tap to edit icon/color/name. "Reset to Defaults" at bottom. |
| **Auto Rules** | List of keyword rules. Active toggle. "Add Rule". "Suggestions" tab shows learned patterns. |
| **Language** | Toggle: English / Kiswahili |
| **Currency** | TZS only (locked). Show format toggle: "Tsh 50,000" vs "Tsh 50,000.00" |
| **Theme** | Light / Dark / System. Accent color picker (6 presets). |
| **Security** | Toggle: App lock (PIN / Biometric). |
| **Data** | Export CSV (date range). Backup DB (share file). Restore from backup. |
| **About** | App name, version, "Tengenezwa Tanzania" (Made in Tanzania). |

**Design notes:**
- Each section has header text (subtle, all caps)
- Toggles use Material 3 switch style (Apple would use, pill-shaped)

---

### 9. Onboarding

**Layout:**
3-4 page pager with dot indicators. Apple-style "page control" dots. "Ruka" (Skip) link top right.

| Page | Content |
|---|---|
| **1 — Karibu** | App icon/logo centered. Title: "Fuatilia Pesa Zako" (Track Your Money). Subtitle: "Automatic expense tracking from your SMS — private, offline, no cloud." Two buttons: "Anza" (Start) / "Tayari Nina Akaunti" (I already have data — restore). |
| **2 — Ruhusa ya SMS** | Illustration of SMS being read. Title: "Ruhusu Kusoma SMS" (Allow SMS Reading). Explanation: "We read transaction SMS from M-Pesa, Airtel, Mixx, and your bank — automatically. Your messages never leave your phone." "Washa" (Enable) button triggers permission dialog. |
| **3 — Akaunti Zako** | "Select your mobile money and banks:" Grid of provider icons with checkboxes: M-Pesa, Airtel Money, Mixx by Yas, NMB, CRDB, NBC, Halopesa, Other. Below: "Cash" toggle. "Add starting balances" option. "Next" button. |
| **4 — Tayari** | "You're ready!" summary. "We'll scan your last 30 days of SMS for past transactions." "Anza Kutumia" (Start Using) button. |

**Design notes:**
- Full-bleed pages with illustration at top, content at bottom (Apple setup wizard style)
- Smooth crossfade between pages
- Skip button hidden on permission page (must grant or explain why not)

---

### 10. Empty, Error & Loading States

| State | Design |
|---|---|
| Empty list | Centered illustration + title + subtitle + action button. Soft, not alarming. |
| Error | Inline banner at top: red/orange background, icon, message, "Retry" button |
| Loading | Skeleton shimmer cards (not spinners). Fade in content when loaded. |
| No internet | Not applicable (app is offline). |
| SMS permission denied | Persistent banner on dashboard: "SMS reading disabled — add transactions manually." Tap to re-enable. |

---

## Design Tokens (Color System)

### Light Mode

| Token | Value |
|---|---|
| Surface | #FFFBFE |
| Surface Container | #F3EDF7 |
| Surface Dim | #DED8E1 |
| Primary (accent) | Emerald #006B4F or user choice |
| On Primary | #FFFFFF |
| Income | #2E7D32 (green 700) |
| Expense | #C62828 (red 800) |
| Transfer | #1565C0 (blue 800) |
| Outline | #CAC4D0 |
| Outline Variant | #E7E0EC |

### Dark Mode

| Token | Value |
|---|---|
| Surface | #1C1B1F |
| Surface Container | #211F26 |
| Surface Dim | #141218 |
| Primary | #4CD9A8 (lighter for dark) |
| On Primary | #003828 |
| Income | #66BB6A |
| Expense | #EF5350 |
| Transfer | #42A5F5 |
| Outline | #938F99 |
| Outline Variant | #43474E |

---

## Typography

| Style | Size | Weight | Usage |
|---|---|---|---|
| Large Title | 34px | Bold | Screen titles |
| Title 1 | 28px | Bold | Card hero amounts |
| Title 2 | 22px | Semibold | Section headers |
| Title 3 | 20px | Semibold | Card titles |
| Headline | 17px | Semibold | Transaction descriptions |
| Body | 17px | Regular | Body text |
| Callout | 16px | Regular | Budget amounts |
| Subhead | 15px | Regular | Subtitles |
| Footnote | 13px | Regular | Captions, timestamps |
| Caption 1 | 12px | Regular | Chips, badges |
| Caption 2 | 11px | Regular | Small labels |
| **Amount (Monospace)** | same as context | Semibold | All Tsh values |

Amounts must always be in monospace: SF Mono on iOS, JetBrains Mono / Roboto Mono on Android. This keeps numbers aligned and scannable.

---

## Interaction Patterns

| Action | Pattern |
|---|---|
| Tap card | Elevate + spring scale (0.98 → 1.0) on release |
| Swipe to delete | Red background reveals behind card, haptic on threshold |
| Swipe to approve (review) | Green background, haptic, card flies off right |
| Pull to refresh | Material 3 refresh indicator with brand color |
| Long press | Haptic pop, context menu appears (Apple style) |
| FAB scroll behavior | Extended with label; on scroll down collapses to icon + elevation |
| Bottom sheet | Apple-style grab handle, 50% / 90% snap positions, blur background |
| Page transition | Fade + slide (iOS 13+ card style for push, fade for tabs) |
| Number input | Spring animation on digit entry, comma auto-insertion |
| Toggle | Material 3 switch — pill shape with smooth thumb animation |
| Haptic | Light impact on selection, medium on destructive actions, notification on success |

---

## Device & Platform

| Aspect | Requirement |
|---|---|
| Minimum width | 360dp (small phones) |
| Layout | Single column. No tablet adaptation in v1. |
| Gestures | Full edge-to-edge swipe back (iOS), back button (Android). Both respected. |
| Notch / Dynamic Island | Safe area respected. Content avoids notch. |
| Bottom nav | 5 tabs max. Labels visible. Active state = filled icon + brand color. Inactive = outline icon + grey. |
| Keyboard | Numeric with decimal for amounts. Dismiss on tap outside. |

---

## Deliverables from Designer

For each screen/component:

1. **Figma file** with components, variants (light/dark), and auto-layout
2. **Prototype link** with all flows connected (tap targets, transitions)
3. **Design token file** (JSON) — colors, spacing, type scale, elevation
4. **Component library** in Figma (reusable: cards, buttons, inputs, chips, charts)
5. **Motion spec** — duration, easing curves for each animation type
6. **Icon set** — SF Symbols / Material icons consistent across the app

**Key flows to prototype:**
1. Onboarding → Dashboard (first run, no data)
2. SMS arrives → notification → review queue → approve
3. Manual add transaction flow
4. Create budget → see it on dashboard ring
5. Analytics tabs browsing
6. Settings → Export backup

---

## Out of Scope (v1)

- Tablet / foldable layouts
- Landscape mode (portrait-only v1)
- Widgets (iOS widget / Android homescreen widget)
- Wear OS / Apple Watch
- Animations beyond fade/slide/spring (no particle effects, no parallax)
- Custom illustrations (use system icons and simple shapes initially)
