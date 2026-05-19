# Budget & Expenses Tracker — Personal Tanzania Edition

## 1. Technology Stack

| Layer          | Choice              | Rationale                                                           |
|----------------|---------------------|----------------------------------------------------------------------|
| Framework      | **Flutter**         | Best cross-platform perf; strong local storage + background SMS access |
| State Mgmt     | **Riverpod**        | Compile-safe, testable, scalable                                     |
| Local DB       | **Drift (SQLite)**  | Type-safe, reactive streams, relational queries for budgets/analytics |
| SMS Access     | `telephony` + Android SMS Retriever API                             |
| Backup         | **SQLite file export** (manual copy or Google Drive backup)         |
| Charts         | **fl_chart**        | Highly customizable, supports all chart types needed                  |
| Currency       | **TZS** (Tanzanian Shilling) hardcoded with Kiswahili formatting    |

**No cloud, no auth, no sync.** Everything stays on your phone. Optional manual database backup.

---

## 2. System Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    Presentation Layer                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ Dashboard│ │Transact- │ │  Budget  │ │ Reports &    │ │
│  │          │ │ ions     │ │  Manager │ │ Analytics    │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │
├──────────────────────────────────────────────────────────┤
│                   Business Logic Layer                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │   SMS    │ │ Transact │ │  Budget  │ │  Analytics   │ │
│  │  Parser  │ │ Engine   │ │  Engine  │ │  Engine      │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │
├──────────────────────────────────────────────────────────┤
│                      Data Layer (100% Local)              │
│  ┌────────────────────────────────────────────────────┐   │
│  │              Drift (SQLite) Database                │   │
│  │  ┌──────────────┐ ┌──────────────┐                │   │
│  │  │ Transactions │ │ Categories   │                │   │
│  │  │ Accounts     │ │ Budgets      │                │   │
│  │  │ Rules        │ │ Snapshots    │                │   │
│  │  └──────────────┘ └──────────────┘                │   │
│  └────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────┤
│                     Platform Layer                        │
│  ┌────────────────────┐ ┌──────────────────────────────┐ │
│  │  SMS Receiver      │ │  Notification Service        │ │
│  │  (Android)         │ │  (Budget alerts, reminders)  │ │
│  └────────────────────┘ └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## 3. Core Feature Modules

### 3.1 SMS Parsing Engine

**Architecture:** Regex pipeline with Tanzania-provider matching.

```
Incoming SMS
    │
    ▼
┌─────────────────────────────┐
│  SMS Normalizer             │
│  - Strip whitespace/unicode │
│  - Lowercase                │
│  - Normalize "Tsh"/"TZS"    │
└──────────┬──────────────────┘
           ▼
┌─────────────────────────────┐
│  Provider Detector          │
│  (by sender shortcode)      │
│  ┌──────────┐ ┌──────────┐  │
│  │ M-Pesa   │ │ Airtel   │  │
│  │ Tanzania │ │ Money TZ │  │
│  └──────────┘ └──────────┘  │
│  ┌──────────┐ ┌──────────┐  │
│  │ Mixx     │ │ Bank     │  │
│  │ by Yas   │ │ SMS      │  │
│  │ (T-Pesa) │ │ (NMB/    │  │
│  │          │ │ CRDB/    │  │
│  │          │ │ NBC/etc) │  │
│  └──────────┘ └──────────┘  │
└──────────┬──────────────────┘
           ▼
┌─────────────────────────────┐
│  Regex Pattern Matcher      │
│  Each provider has patterns │
│  for:                       │
│  - Received money           │
│  - Sent money               │
│  - Airtime purchase         │
│  - Bill payment             │
│  - Transaction fee          │
│  - Bank deposit/withdrawal  │
└──────────┬──────────────────┘
           ▼
┌─────────────────────────────┐
│  Extracted Data             │
│  {                          │
│    amount: 50000,           │
│    type: "received",        │
│    sender: "John Doe",      │
│    reference: "P65AB1C2D",  │
│    provider: "M-Pesa_TZ",   │
│    new_balance: 250000,     │
│    timestamp: DateTime,     │
│    raw_sms: "..."           │
│  }                          │
└─────────────────────────────┘
```

#### Tanzania-Specific SMS Formats

**M-Pesa Tanzania (Vodacom)**
```
"Pesa zimewekwa Tsh 50,000.00 na John Doe tarehe 15/5/2026 saa 14:30. Rej: P65AB1C2D. Salio: Tsh 250,000.00"
"Umetuma Tsh 30,000.00 kwa Jane Doe tarehe 15/5/2026 saa 10:00. Rej: P65XYZ123. Salio: Tsh 220,000.00"
"Umenunua airtime Tsh 5,000.00 kwa 0712345678 tarehe 15/5/2026. Rej: A65ABC. Salio: Tsh 215,000.00"
"Kodi ya kuhudumia Tsh 500.00 tarehe 15/5/2026. Salio: Tsh 214,500.00"
```

**Airtel Money Tanzania**
```
"Umepokea Tsh 45,000.00 kutoka kwa 0712345678. Rej: AT123456. Salio: Tsh 300,000.00"
"Umetuma Tsh 20,000.00 kwa 0765432198. Rej: AT654321. Salio: Tsh 280,000.00"
"Umeweka Tsh 100,000.00 kwenye Airtel Money. Salio: Tsh 380,000.00"
```

**Mixx by Yas (formerly Tigo Pesa)**
```
"Umepokea TZS 25,000.00 kutoka kwa 0712345678. Kumbukumbu: MX789012. Salio: TZS 150,000.00"
"Umetuma TZS 15,000.00 kwa 0765432198. Kumbukumbu: MX210987. Salio: TZS 135,000.00"
"Ununuzi wa kifurushi TZS 3,000.00. Salio: TZS 132,000.00"
```

**NMB Bank SMS**
```
"Tumekutoa TZS 150,000.00 kwa POS/MERCHANT/0123456789 tarehe 15/05/2026. Salio: TZS 1,250,000.00"
"Tumeongeza TZS 500,000.00 kutoka SALARY/MONTHLY tarehe 15/05/2026. Salio: TZS 1,750,000.00"
"Fees: TZS 1,000.00 kwa ATM WITHDRAWAL. Salio: TZS 1,249,000.00"
```

**CRDB Bank SMS**
```
"CRDB: Withdrawal TZS 200,000.00 at ATM/Arusha. Available: TZS 800,000.00. Ref: CRDB123"
"CRDB: Deposit TZS 1,000,000.00 from MPESA. Available: TZS 1,800,000.00. Ref: CRDB456"
```

**NBC Bank SMS**
```
"NBC: TZS 50,000.00 debited from acct ****1234. Desc: AIRTIME. Bal: TZS 450,000.00"
"NBC: TZS 300,000.00 credited to acct ****1234. Desc: SALARY. Bal: TZS 750,000.00"
```

#### Pattern Definition (bundled with app, no internet needed)

```json
{
  "provider": "M-Pesa_TZ",
  "shortcodes": ["M-PESA", "VODACOM"],
  "currency_symbols": ["Tsh", "TZS", "tsh", "tzs"],
  "patterns": {
    "received": {
      "regex": "(?:Pesa zimewekwa|Umepokea|umepewa)\\s+Tsh?\\s*([\\d,]+(?:\\.[\\d]{2})?)\\s+(?:na|kutoka kwa|kutoka)\\s+(.+?)\\s+(?:tarehe|leo)",
      "groups": { "amount": 1, "sender": 2 }
    },
    "sent": {
      "regex": "Umetuma\\s+Tsh?\\s*([\\d,]+(?:\\.[\\d]{2})?)\\s+(?:kwa|kwenda)\\s+(.+?)\\s+(?:tarehe|leo)",
      "groups": { "amount": 1, "recipient": 2 }
    },
    "airtime": {
      "regex": "umenunua\\s+airtime\\s+Tsh?\\s*([\\d,]+(?:\\.[\\d]{2})?)",
      "groups": { "amount": 1 }
    },
    "fee": {
      "regex": "Kodi ya kuhudumia\\s+Tsh?\\s*([\\d,]+(?:\\.[\\d]{2})?)",
      "groups": { "amount": 1 }
    }
  }
}
```

**Initial bundled providers:**

| Provider | Shortcodes |
|---|---|
| **M-Pesa Tanzania** | `M-PESA`, `VODACOM` |
| **Airtel Money TZ** | `AIRTEL`, `AIRTEL MONEY` |
| **Mixx by Yas** | `MIXX`, `MIXX BY YAS`, `TIGO`, `T-PESA` |
| **NMB Bank** | `NMB` |
| **CRDB Bank** | `CRDB` |
| **NBC Bank** | `NBC` |
| **Stanbic Bank** | `STANBIC` |
| **Diamond Trust** | `DTB`, `DIAMOND` |
| **Halopesa** | `HALOPESA`, `HALO` |

#### Balance Tracking via SMS

Many mobile money SMS include the new balance (`Salio:` / `Balance:` / `Bal:`). Extract and use to auto-reconcile the account balance — no manual entry needed. If the parsed balance doesn't match the calculated balance, flag for user review (possible missed transaction).

---

### 3.2 Transaction Management

**Data Model:**

```
Transaction
  - id: UUID (PK)
  - amount: int (in TZS cents to avoid floating point issues)
  - type: enum [income, expense, transfer, airtime, fee]
  - description: string (auto-generated from SMS or manual)
  - category_id: UUID (FK → Category)
  - account_id: UUID (FK → Account)
  - source: enum [manual, sms_auto, sms_reviewed]
  - provider: string? (e.g., "M-Pesa_TZ", "NMB")
  - sender/recipient: string?
  - reference: string?
  - raw_sms: string? (only stored locally, never sent anywhere)
  - sms_timestamp: DateTime?
  - balance_after: int? (from SMS "Salio:" field)
  - created_at: DateTime
  - updated_at: DateTime

Account
  - id: UUID
  - name: string (e.g., "M-Pesa", "Airtel Money", "Mixx", "NMB", "CRDB", "Cash")
  - type: enum [mobile_money, bank, cash]
  - balance: int (in TZS cents)
  - provider: string? (links to SMS provider for auto-matching)
  - phone_number: string? (for matching incoming SMS)
  - icon: string
  - sort_order: int
  - is_archived: bool
  - created_at: DateTime

Category
  - id: UUID
  - name: string
  - name_sw: string? (Kiswahili translation for display)
  - icon: string
  - color: string (hex)
  - type: enum [income, expense, transfer]
  - parent_id: UUID? (for sub-categories)
  - is_system: bool (built-in vs user-created)
  - budget_id: UUID? (FK → Budget)
  - sort_order: int
```

**Currency handling:** Store amounts as integers in TZS cents (×100). Display formatted as `Tsh 50,000.00` or `Tsh 50,000` (configurable with/without decimals). Kiswahili formatting: `Tsh 50,000` without decimals is most natural in Tanzania.

**Auto-categorization Rules Engine:**

- **Keyword matching** on sender/description:
  | Keyword | Category |
  |---|---|
  | "Supermarket", "Shop", "Duka" | Groceries |
  | "Restaurant", "Hotel", "Mkahawa", "Food" | Food & Dining |
  | "Petrol", "Fuel", "Stesheni" | Transport / Fuel |
  | "SALARY", "Mshahara" | Income: Salary |
  | "POS", "Merchant" | Shopping |
  | "ATM" | Cash Withdrawal |
  | "AIRTIME" | Airtime |
  | "UMOJA", "WATER", "LUKU", "TANESCO" | Utilities |
  | "MPESA", "AIRTEL", "MIXX" | Mobile Money Transfer (to self) |

- **Sender-based matching:** Known merchants/individuals get auto-categorized
- **Learn-from-user:** Tracks manual recategorizations → suggests new rules
- **Confidence scoring:** >90% auto-accept, 70-90% flag for review, <70% uncategorized

---

### 3.3 Budget Management (Envelope System)

**Budget Model:**

```
Budget
  - id: UUID (PK)
  - name: string (e.g., "Vyakula", "Usafiri", "Kodi ya Nyumba")
  - name_sw: string?
  - category_id: UUID (FK → Category)
  - period: enum [weekly, biweekly, monthly, yearly]
  - amount: int (TZS cents)
  - rollover: bool
  - rollover_type: enum [all, capped, none]
  - rollover_cap: int? (max carry-forward in TZS cents)
  - start_date: DateTime
  - end_date: DateTime?
  - notification_threshold: double (% e.g. 0.8 = 80%)
  - is_active: bool
  - created_at: DateTime

BudgetPeriod
  - id: UUID (PK)
  - budget_id: UUID (FK)
  - period_start: DateTime
  - period_end: DateTime
  - allocated: int
  - spent: int
  - rolled_from: int?
  - rolled_to: int?
  - is_closed: bool
```

**Features:**
- Monthly budget with category envelopes (e.g. Food Tsh 300,000, Transport Tsh 150,000)
- Rollover with optional cap (unused Tsh 50,000 max rolls to next month)
- Deficit carry-forward: overspent deducted from next month's budget
- Yearly budgets → monthly savings target (e.g. "Kodi ya Nyumba Tsh 3,600,000/year" = Tsh 300,000/mo)
- Progress bars with "Tsh 150,000 / Tsh 300,000 iliyotumika (50%)"
- Local notification at 50%, 80%, 100%, exceeded

---

### 3.4 Analytics & Insights Engine

**Pre-computed aggregates** (updated on every transaction insert/update):

```
DailySnapshot
  - date: string (PK, "2026-05-15")
  - total_income: int
  - total_expense: int
  - by_category: JSON ({ "cat_id": amount_in_cents })
  - net_cashflow: int
  - day_of_week: int
  - is_weekend: bool

MonthlySnapshot
  - year_month: string (PK, "2026-05")
  - total_income: int
  - total_expense: int
  - net_savings: int
  - by_category: JSON
  - by_day: JSON ({ "15": amount })
  - avg_daily_spend: double
  - top_merchants: JSON
```

**Insights generated on-device:**

| Insight Type | Example (in Kiswahili or English) |
|---|---|
| Spending trend | "Umekula Tsh 50,000 zaidi kwenye Vyakula mwezi huu kuliko mwezi uliopita (+15%)" |
| Anomaly | "Unusual Tsh 500,000 expense detected — sure this is right?" |
| Budget forecast | "Kwa kasi hii, utazidi bajeti ya Vyakula ifikapo tarehe 22" |
| Savings rate | "Unaweka 15% ya mapato yako. Weka lengo la 20%" |
| Merchant frequency | "Umekwenda Quick Mart mara 12 mwezi huu (wastani Tsh 8,000/huduma)" |
| Net cashflow | "Mwezi huu pata Tsh 1,200,000, toa Tsh 950,000 = Tsh 250,000 iliyobaki (+26%)" |
| Income consistency | "Mapato yako mwezi huu: Tsh 1,200,000. Wastani wa miezi 3: Tsh 1,150,000" |

**Charts:**
| Screen | Chart Type | Data |
|---|---|---|
| Dashboard | Line chart | Net worth / account balance over time |
| Dashboard | Donut chart | Top 5 spending categories this month |
| Dashboard | Ring progress | Each budget vs spent |
| Analytics tab | Bar chart | Monthly income vs expense (12 months) |
| Analytics tab | Treemap | All categories by spending size |
| Analytics tab | Line chart | Category trend over months |
| Budget tab | Radial ring | Single budget vs remaining days |

---

### 3.5 Account Auto-Creation

When an SMS is parsed from a new provider (e.g., first M-Pesa SMS), auto-create an account for it:

```
"M-Pesa" account created with starting balance Tsh 250,000 (from SMS "Salio")
```

User can:
- Rename the account
- Set an opening balance for historical accuracy
- Archive unused accounts
- Link phone numbers to accounts for matching

Cash accounts are created manually (no SMS source).

---

## 4. Database Schema

```sql
-- Core
accounts (id, name, type, balance, provider, phone_number, icon,
          sort_order, is_archived, created_at)

categories (id, name, name_sw, icon, color, type, parent_id, is_system,
            sort_order, created_at)

transactions (id, account_id, category_id, amount, type, description,
              provider, sender, recipient, reference, raw_sms,
              sms_timestamp, balance_after, source, created_at, updated_at)

-- Budgets
budgets (id, name, name_sw, category_id, period, amount, rollover,
         rollover_type, rollover_cap, start_date, end_date,
         notification_threshold, is_active, created_at)

budget_periods (id, budget_id, period_start, period_end, allocated, spent,
                rolled_from, rolled_to, is_closed, created_at)

-- Auto-categorization
auto_category_rules (id, keyword, category_id, confidence, is_active,
                     match_type, created_at)
recategorization_log (id, transaction_id, old_category_id, new_category_id,
                      created_at)

-- Analytics
daily_snapshots (date, total_income, total_expense, by_category,
                 net_cashflow, day_of_week, is_weekend, created_at)
monthly_snapshots (year_month, total_income, total_expense, net_savings,
                   by_category, by_day, avg_daily_spend, top_merchants,
                   created_at)

-- App settings
app_settings (key, value, updated_at)
-- e.g. { "language": "sw", "currency_format": "Tsh 50,000",
--        "sms_read_permission": true, "theme": "dark",
--        "onboarding_complete": true,
--        "default_account_id": "..." }
```

---

## 5. Flutter App Screen Map

### Main Tabs (Bottom Navigation)

| # | Tab | Screen | Content |
|---|---|---|---|
| 1 | **Nyumbani** / Dashboard | `/` | Balance card (total + per account), last 5 transactions, monthly overview (income/expense donut + net change), budget progress ring, quick-add FAB |
| 2 | **Shughuli** / Transactions | `/transactions` | Infinite scroll list, filter by date/category/account, search, pull-to-refresh, FAB to add manually |
| 3 | **Bajeti** / Budgets | `/budgets` | Card grid of all budgets, each with progress bar + remaining amount + days left. Total budget vs total spent summary at top. |
| 4 | **Takwimu** / Analytics | `/analytics` | Tab view: Overview, Trends, Insights cards. Income vs expense bar chart, category treemap, spending trend line. |
| 5 | **Mipangilio** / Settings | `/settings` | Accounts list, categories editor, rules manager, language toggle, export DB, backup/restore, about |

### Secondary Screens

| Screen | Route | Content |
|---|---|---|
| Add Transaction | `/transactions/add` | Amount, type (income/expense/transfer), account, category, description, date. Auto-suggest category from description. |
| Edit Transaction | `/transactions/:id/edit` | Same form as add, pre-filled |
| Transaction Detail | `/transactions/:id` | Full info: amount, category, account, description, provider, reference, raw SMS view, date. Edit/delete actions. |
| Account Detail | `/accounts/:id` | Account balance, transaction list filtered by this account, edit name, archive |
| Budget Detail | `/budgets/:id` | Progress bar, allocated vs spent, rollover config, period list, transactions in this budget's category |
| Budget Form | `/budgets/add` or `/budgets/:id/edit` | Name, category, amount, period, rollover settings, start date |
| SMS Review Queue | `/sms-queue` | List of auto-parsed SMS awaiting review. Swipe to approve/categorize/reject. |
| Category Manager | `/settings/categories` | Grid of categories with color/icon. Edit, delete, reorder. Default categories pre-loaded. |
| Rules Manager | `/settings/rules` | List of auto-categorization rules. Add/edit/delete. Suggestion tab shows learned patterns. |
| Export / Backup | `/settings/export` | Export as CSV, backup DB file, restore from backup |
| Edit Account | `/settings/accounts/:id/edit` | Name, type, provider link, opening balance, archive |
| Onboarding | `/onboarding` | 3-4 page wizard: welcome, SMS permission, initial accounts, default categories, done |

---

## 6. SMS Processing Workflow

### Flow

```
1. App launches → check READ_SMS permission
   - If granted: register broadcast receiver
   - If not: show onboarding screen with explanation

2. On new SMS received:
   a. Check sender address against known provider shortcodes
      - "M-PESA", "VODACOM" → M-Pesa parser
      - "AIRTEL" → Airtel parser
      - "MIXX", "TIGO" → Mixx parser
      - "NMB" → NMB parser
      - "CRDB" → CRDB parser
      - etc.

   b. Run provider-specific regex pipeline
      - Try "received" pattern → type = income
      - Try "sent" pattern → type = expense
      - Try "airtime" pattern → type = expense (category: Airtime)
      - Try "fee" pattern → type = expense (category: Bank Fees)
      - Try "withdrawal", "deposit" for banks
      - If no match → silently ignore (log to debug)

   c. If matched:
      - Normalize amount (remove commas, handle "Tsh"/"TZS")
      - Convert to integer cents (×100)
      - Extract sender/recipient name or number
      - Extract reference code
      - Extract new balance (Salio/Balance/Bal)

   d. Deduplication check:
      - Match on (provider + reference) AND
      - Match on (provider + amount + sms_timestamp ±1min)
      - If duplicate → skip

   e. Auto-categorization:
      - Run keyword rules against description + sender
      - Check sender-based rules
      - Assign category with confidence %
      
   f. Account linking:
      - Find account by provider match (e.g., "M-Pesa_TZ" → "M-Pesa" account)
      - If no account exists: auto-create one
      - Verify balance_after from SMS matches calculated balance
        (If mismatch: flag "Possible missed transaction — balance off by Tsh X")

   g. Persist transaction:
      - If confidence >= 90% → auto-approve (source = sms_auto)
      - If confidence 70-90% → add to review queue (source = sms_reviewed)
      - If < 70% → add to review queue (source = sms_reviewed, marked "uncategorized")
      - Show notification:
        "Tsh 50,000 received from John ✓" (auto-approved)
        "Tsh 30,000 sent — tap to categorize" (needs review)

3. Historical scan (first run):
   - Scan last 30 days of SMS for all known providers
   - Process same pipeline (batched to avoid ANR)
   - Show progress: "Inatafuta shughuli za zamani... 45/200"

4. Review queue:
   - List of unapproved transactions
   - Tap to assign category, edit details, or reject (mark as not a transaction)
   - Rejected SMS added to ignore list to prevent re-processing
```

### Edge Cases Handled

| Edge Case | Handling |
|---|---|
| SMS arrives while app is closed | Broadcast receiver wakes app, processes silently |
| Duplicate SMS (same from provider + telco) | Dedup by reference |
| Provider sends 2 SMS for same transaction | Match on amount ± SMS timestamp within 60s |
| Balance mismatch from SMS | Flag with "Balance off by Tsh X — tap to fix" |
| Unknown sender shortcode | Ignore, log for manual pattern addition |
| Partial SMS / split message | Concatenate before processing |
| Old SMS re-scanned after duplicate already exists | Dedup by reference |
| Transaction ammendment SMS | Match reference, update original transaction |
| Float/whole number amounts | Handle both "Tsh 50,000" and "Tsh 50,000.00" |

---

## 7. Key Flutter Packages

| Package | Purpose |
|---|---|
| `flutter_riverpod` / `riverpod_annotation` | State management |
| `drift` | Local SQLite database |
| `sqlite3_flutter_libs` | SQLite native libs |
| `telephony` or `sms_advanced` or `sms_retriever` | SMS read/listen (Android) |
| `fl_chart` | Charts & graphs |
| `intl` | Date/number/currency formatting |
| `share_plus` | Export file sharing |
| `path_provider` | File paths for backup/export |
| `file_picker` | Select backup file to restore |
| `flutter_local_notifications` | Budget alerts & SMS notifications |
| `freezed` | Immutable data classes |
| `json_serializable` | JSON serialization |
| `uuid` | Generate UUIDs |
| `csv` | CSV export |
| `pdf` | PDF report generation (optional) |
| `flutter_secure_storage` | PIN/biometric lock |
| `local_auth` | Biometric authentication |
| `flex_color_scheme` | Material 3 theming |
| `animations` | Smooth page transitions |

---

## 8. Project Structure

```
lib/
├── main.dart
├── app.dart                          # App widget, theme, router (GoRouter)
├── bootstrap.dart                   # DB init, permission check, onboarding check
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── sms_providers.dart       # All provider definitions + shortcodes
│   │   ├── category_defaults.dart   # Default categories (EN + SW)
│   │   └── pattern_definitions.dart # Bundled regex patterns
│   ├── errors/
│   │   ├── app_exception.dart
│   │   └── error_handler.dart
│   ├── extensions/
│   │   ├── context_extensions.dart
│   │   ├── date_extensions.dart
│   │   └── number_extensions.dart   # Tsh formatting
│   ├── router/
│   │   └── app_router.dart          # GoRouter with shell routes
│   ├── theme/
│   │   └── app_theme.dart           # Material 3, light/dark
│   └── utils/
│       ├── currency_formatter.dart  # Tsh x,xxx formatter
│       ├── date_utils_tz.dart       # Tanzanian timezone
│       └── sms_tools.dart
│
├── data/
│   ├── database/
│   │   ├── app_database.dart        # Drift database
│   │   ├── app_database.g.dart
│   │   ├── tables/
│   │   │   ├── transactions_table.dart
│   │   │   ├── accounts_table.dart
│   │   │   ├── categories_table.dart
│   │   │   ├── budgets_table.dart
│   │   │   ├── budget_periods_table.dart
│   │   │   ├── rules_table.dart
│   │   │   ├── recategorization_log_table.dart
│   │   │   ├── daily_snapshots_table.dart
│   │   │   ├── monthly_snapshots_table.dart
│   │   │   └── settings_table.dart
│   │   └── daos/
│   │       ├── transaction_dao.dart
│   │       ├── budget_dao.dart
│   │       ├── category_dao.dart
│   │       ├── account_dao.dart
│   │       ├── analytics_dao.dart
│   │       ├── rules_dao.dart
│   │       └── settings_dao.dart
│   ├── repositories/
│   │   ├── transaction_repository.dart
│   │   ├── budget_repository.dart
│   │   ├── category_repository.dart
│   │   ├── account_repository.dart
│   │   ├── analytics_repository.dart
│   │   ├── rules_repository.dart
│   │   └── settings_repository.dart
│   └── models/
│       ├── transaction.dart
│       ├── account.dart
│       ├── category.dart
│       ├── budget.dart
│       ├── budget_period.dart
│       ├── auto_rule.dart
│       ├── daily_snapshot.dart
│       ├── monthly_snapshot.dart
│       └── sms_parsed.dart          # SMS parse result DTO
│
├── domain/
│   ├── sms/
│   │   ├── sms_listener.dart        # Broadcast receiver registration
│   │   ├── sms_parser.dart          # Main parser orchestrator
│   │   ├── sms_processor.dart       # Full pipeline: parse→dedup→categorize→save
│   │   ├── provider_matcher.dart    # Match sender to provider
│   │   ├── parsers/
│   │   │   ├── mpesa_tz_parser.dart
│   │   │   ├── airtel_tz_parser.dart
│   │   │   ├── mixx_parser.dart
│   │   │   ├── nmb_parser.dart
│   │   │   ├── crdb_parser.dart
│   │   │   ├── nbc_parser.dart
│   │   │   └── bank_base.dart       # Shared bank SMS parsing logic
│   │   ├── deduplicator.dart
│   │   └── balance_reconciler.dart  # Verify balance_after vs calculated
│   ├── categorization/
│   │   ├── auto_categorizer.dart
│   │   ├── rule_engine.dart
│   │   └── learning_engine.dart
│   ├── budget/
│   │   ├── budget_engine.dart
│   │   ├── rollover_calculator.dart
│   │   └── budget_checker.dart
│   └── analytics/
│       ├── snapshot_service.dart
│       ├── insight_generator.dart
│       └── trend_analyzer.dart
│
├── presentation/
│   ├── common/
│   │   ├── widgets/
│   │   │   ├── amount_text.dart         # Auto-formats Tsh amounts
│   │   │   ├── category_icon.dart
│   │   │   ├── category_picker_dialog.dart
│   │   │   ├── account_picker.dart
│   │   │   ├── progress_ring.dart
│   │   │   ├── budget_progress_bar.dart
│   │   │   ├── empty_state.dart
│   │   │   ├── confirm_dialog.dart
│   │   │   ├── loading_overlay.dart
│   │   │   └── error_banner.dart
│   │   └── helpers/
│   │       └── format_helpers.dart
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   ├── providers/
│   │   │   ├── dashboard_provider.dart
│   │   │   └── balance_provider.dart
│   │   └── widgets/
│   │       ├── balance_card.dart         # Total + per-account balances
│   │       ├── monthly_summary.dart      # Income/expense donut + net
│   │       ├── recent_transactions.dart  # Last 5 transactions
│   │       ├── budget_rings.dart         # Mini ring for each budget
│   │       └── quick_actions.dart        # Quick add, review queue badge
│   ├── transactions/
│   │   ├── transaction_list_screen.dart
│   │   ├── transaction_form_screen.dart
│   │   ├── transaction_detail_screen.dart
│   │   ├── providers/
│   │   │   ├── transaction_list_provider.dart
│   │   │   └── filter_provider.dart
│   │   └── widgets/
│   │       ├── transaction_tile.dart
│   │       ├── filter_bar.dart
│   │       ├── search_bar.dart
│   │       ├── type_toggle.dart          # Income / Expense / All
│   │       └── date_range_picker.dart
│   ├── budgets/
│   │   ├── budget_list_screen.dart
│   │   ├── budget_detail_screen.dart
│   │   ├── budget_form_screen.dart
│   │   ├── providers/
│   │   │   └── budget_provider.dart
│   │   └── widgets/
│   │       ├── budget_card.dart
│   │       ├── budget_progress_bar.dart
│   │       ├── budget_period_list.dart
│   │       └── rollover_config_sheet.dart
│   ├── analytics/
│   │   ├── analytics_screen.dart
│   │   ├── insight_detail_screen.dart
│   │   ├── providers/
│   │   │   ├── analytics_provider.dart
│   │   │   └── insight_provider.dart
│   │   └── widgets/
│   │       ├── overview_tab.dart
│   │       ├── trends_tab.dart
│   │       ├── insights_tab.dart
│   │       ├── income_vs_expense_chart.dart
│   │       ├── category_treemap.dart
│   │       ├── spending_trend_chart.dart
│   │       └── insight_card.dart
│   ├── sms_review/
│   │   ├── sms_review_screen.dart
│   │   ├── providers/
│   │   │   └── sms_review_provider.dart
│   │   └── widgets/
│   │       ├── review_tile.dart
│   │       └── quick_categorize_sheet.dart
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   ├── account_manager_screen.dart
│   │   ├── category_manager_screen.dart
│   │   ├── rule_manager_screen.dart
│   │   ├── export_screen.dart
│   │   ├── privacy_screen.dart
│   │   ├── providers/
│   │   │   └── settings_provider.dart
│   │   └── widgets/
│   │       ├── settings_tile.dart
│   │       ├── account_tile.dart
│   │       ├── category_editor.dart
│   │       └── rule_form.dart
│   └── onboarding/
│       ├── onboarding_screen.dart
│       ├── providers/
│       │   └── onboarding_provider.dart
│       └── pages/
│           ├── welcome_page.dart
│           ├── sms_permission_page.dart
│           ├── initial_accounts_page.dart
│           └── complete_page.dart
│
└── services/
    ├── notification_service.dart
    ├── sms_background_service.dart
    ├── export_service.dart
    ├── backup_service.dart
    └── database_migration_service.dart
```

---

## 9. Default Data

### Default Accounts (empty, auto-created on first SMS match or manual add)

Users start with no accounts. Accounts are auto-created when:
- First M-Pesa SMS is parsed → "M-Pesa" account created
- First Airtel SMS is parsed → "Airtel Money" account created
- First Mixx SMS is parsed → "Mixx by Yas" account created
- First NMB SMS is parsed → "NMB" account created
- etc.

Or user can pre-create accounts manually during onboarding.

### Default Categories (System, non-deletable)

**Income:**
| Name | Name (SW) | Icon | Color |
|---|---|---|---|
| Salary | Mshahara | `briefcase` | Green |
| Business | Biashara | `store` | Teal |
| Mobile Money Deposit | Wekaji | `phone` | Blue |
| Bank Transfer | Benki | `bank` | Indigo |
| Other Income | Mapato Mengine | `plus-circle` | Grey |

**Expenses:**
| Name | Name (SW) | Icon | Color |
|---|---|---|---|
| Food & Groceries | Vyakula na Mboga | `cart` | Orange |
| Transport | Usafiri | `bus` | Amber |
| Rent | Kodi ya Nyumba | `home` | Red |
| Utilities (Water/Electric) | Maji/Stima | `zap` | Yellow |
| Airtime & Data | Airtime na Data | `wifi` | Purple |
| Health | Afya | `heart` | Pink |
| Education | Elimu | `book` | Blue |
| Entertainment | Burudani | `film` | Violet |
| Shopping | Ununuzi | `shopping-bag` | Cyan |
| Eating Out | Kula Nje | `coffee` | Brown |
| Mobile Money Transfer | Tuma Pesa | `send` | Grey |
| Bank Fees | Ada ya Benki | `credit-card` | Red |
| ATM Withdrawal | Kutoa ATM | `banknote` | Grey |
| Insurance | Bima | `shield` | Blue |
| Savings | Akiba | `piggy-bank` | Green |
| Other | Mengineyo | `more-horizontal` | Grey |

**Transfer:**
| Name | Name (SW) | Icon | Color |
|---|---|---|---|
| Between Accounts | Kati ya Akaunti | `arrow-left-right` | Grey |

---

## 10. Implementation Phases

### Phase 1 — Foundation (Week 1-2)
- [ ] Flutter project setup with Riverpod + Drift
- [ ] Core data models & Drift tables
- [ ] Default categories + accounts seeding
- [ ] Manual transaction CRUD (add/edit/delete)
- [ ] Transaction list screen with filters
- [ ] Settings screen shell

### Phase 2 — SMS Engine (Week 3-4)
- [ ] SMS listener (broadcast receiver + permission handling)
- [ ] Parser framework with provider detection
- [ ] M-Pesa Tanzania pattern + parser
- [ ] Airtel Money Tanzania pattern + parser
- [ ] Mixx by Yas pattern + parser
- [ ] Deduplication logic
- [ ] SMS Review Queue UI
- [ ] Historical SMS scan on first install
- [ ] Auto-account creation on first matched SMS

### Phase 3 — Banks (Week 5)
- [ ] NMB SMS parser
- [ ] CRDB SMS parser
- [ ] NBC SMS parser
- [ ] Base bank parser class (shared patterns)
- [ ] Balance reconciler (compare SMS balance vs calculated)

### Phase 4 — Auto-Categorization (Week 6)
- [ ] Keyword rule engine
- [ ] Default rule set (EN + SW keywords)
- [ ] Confidence scoring
- [ ] Auto-approve vs review queue logic
- [ ] Learning engine (track recategorizations → suggest rules)
- [ ] Rule manager UI

### Phase 5 — Budget System (Week 7-8)
- [ ] Budget CRUD
- [ ] Envelope allocation + spending tracking
- [ ] Budget period auto-closing
- [ ] Rollover logic (all, capped, none)
- [ ] Budget UI with progress bars/rings
- [ ] Threshold notifications

### Phase 6 — Analytics (Week 9)
- [ ] Daily/monthly snapshot computation
- [ ] Dashboard with balance card + charts
- [ ] Analytics tab (trends, treemap, income vs expense)
- [ ] Insight generator (v1 — basic comparisons)

### Phase 7 — Polish (Week 10-11)
- [ ] Currency formatter (Tsh x,xxx or Tsh x,xxx.xx)
- [ ] Kiswahili language support
- [ ] Theme (light/dark + color picker)
- [ ] Biometric/PIN lock
- [ ] Export CSV
- [ ] Database backup/restore
- [ ] Notification improvements
- [ ] Performance optimization (indexing, pagination)
- [ ] Edge case handling

---

## 11. Design Decisions

| Decision | Why |
|---|---|
| **No cloud, no auth, no sync** | You said personal. No server costs, no privacy concerns, no internet required. |
| **Flutter over native** | One codebase; you might want iOS later. Flutter SMS plugins exist for Android. |
| **Drift over Hive** | Relational data (budgets ↔ categories ↔ transactions) — SQL joins and referential integrity matter. |
| **Regex over ML** | Tanzanian mobile money SMS formats are highly structured and predictable. Regex is faster, deterministic, and uses zero battery. |
| **Amounts as integer cents** | Avoids floating-point rounding errors. `Tsh 50,000.00` stored as `5000000`. |
| **Balance tracking from SMS Salio field** | Free auto-reconciliation. No manual balance entry needed. |
| **Patterns bundled in app** | No internet dependency. Can add new patterns via app updates. |
| **Kiswahili + English** | Default categories have both. User picks language in settings. SMS parsing handles both. |

---

## 12. Security & Privacy

- **All data stays on-device.** No server, no cloud, no telemetry.
- SMS is read and processed entirely on your phone. Raw SMS text is stored in the local DB only — never transmitted.
- Optional PIN / biometric lock via `flutter_secure_storage` + `local_auth`.
- Android `READ_SMS` permission is requested with clear justification during onboarding.
- Backup files are `.db` SQLite files — user controls where they're stored/shared.
- If you uninstall the app, all data is gone (unless you manually exported a backup).

---

## 13. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Google Play rejects SMS permission | Use `SMS_RETRIEVED_API` (no persistent permission) as primary; document `READ_SMS` for historical scan; can side-load APK |
| SMS format changes from providers | Update patterns in next app release; user can manually categorize failed parses via Review Queue |
| Balance drift over time | "Reconcile" button: user enters known balance, app calculates difference and suggests correction transaction |
| Accidental duplicate from re-scan | Dedup by (provider + reference) is unique; re-scanning same SMS = no effect |
| Battery drain | Broadcast receiver is event-driven (no polling). DB writes are batched. Processing is fast (regex, not ML). |
| Large transaction history | DB indexes on `created_at`, `account_id`, `category_id`. Cursor-based pagination. Snapshot pre-computation. |
| Phone number change / SIM swap | User updates account phone number in settings; new SMS matched to same account |

---

## 14. What's Next (Ready to Build)

The plan is scoped and ready. The build order:

1. **Scaffold the Flutter project** + Drift database + models
2. **Manual transaction CRUD** — so you can start tracking immediately
3. **SMS parsers** — starting with M-Pesa TZ, then Airtel, Mixx, banks
4. **Auto-categorization** + review queue
5. **Budgets + Analytics** on top of the data pipeline

You said you use M-Pesa, Airtel Money, Mixx by Yas, and local banks. I recommend starting Phase 1 + Phase 2 (M-Pesa only) as the first buildable milestone — you'll have a working app that auto-tracks M-Pesa within 2-3 weeks.
