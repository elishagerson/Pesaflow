# 📱 PesaFlow
### *Automated Offline-First Tanzanian Mobile Money & Bank Tracker*

PesaFlow is an ultra-premium, privacy-first mobile application designed to seamlessly track your incomes, expenses, and savings pacing. Tailored specifically for the East African financial ecosystem, PesaFlow automatically listens, parses, and logs transaction alerts from Tanzanian carrier wallets and major banks in real-time, completely offline.

---

## 🌟 Key Features

*   🤖 **Automatic SMS Parsing:** Background listeners capture incoming transactions and extract amounts, service fees, reference codes, and recipients in milliseconds.
*   🏦 **Multi-Provider Support:** Supports up to 5+ simultaneous carriers and banks concurrently:
    *   **Mobile Money:** Vodacom M-Pesa, Tigo Pesa, Airtel Money, Halopesa, and Selcom Pesa.
    *   **Commercial Banks:** CRDB Bank, NMB Bank, and NBC Bank.
*   🛡️ **100% Offline & Private:** Built on a secure local sqlite database (**Drift**). No cloud synchronization, no third-party APIs, and no data leaves your mobile device.
*   ⚖️ **Smart Balance Reconciliation:** Reconciles wallet account balances using the exact post-transaction ending balance (`Salio`) stated by the carrier, automatically accounting for government levies, service fees, and VAT.
*   📊 **Dynamic Budgeting Engine:** Calculates roll-over carryforwards, warning thresholds, and dynamic overall spent-to-income percentages.
*   🎨 **Sleek Noir Aesthetics:** A premium, dark-mode aesthetic with vibrant Apple-inspired neon cyan and white brand accents.
*   🔤 **Gorgeous Typography:** Unified around Google Fonts' **"Outfit"** — a geometric display-friendly typeface matching the aesthetic of premium iOS interfaces.

---

## 🚀 Architecture & Core Pipelines

### 1. SMS Automated Ingestion Pipeline
```
 [ Incoming SMS ] ──> [ Background Isolate Listener ]
                             │
                             ▼
                    [ Provider Matching ] (Shortcode Check)
                             │
                             ▼
                    [ RegEx Parser Engine ] (M-Pesa, Airtel, Selcom, Banks...)
                             │
                             ▼
                 [ Transaction Deduplication ] (Reference Checks)
                             │
                             ▼
                  [ Auto-Categorization ] (NLP Pattern Classifier)
                             │
                             ▼
                  [ Database Persist (Drift) ]
                             │
                             ▼
              [ Wallet Balance Reconciliation ] (Updates exact ending Salio)
                             │
                             ▼
                  [ Native System Alert ]
```

*   **Deduplication:** A secure deduplication hashing engine prevents multi-parsing or double-entry logs.
*   **Balance Reconciliation:** Wallet balances are locked directly to the carrier's calculated `balanceAfter` to handle VAT and separate service tax levies automatically.

### 2. Tech Stack
*   **Framework:** Flutter (Dart)
*   **State Management:** Flutter Riverpod (Reactive dependency injection & streams)
*   **Database:** Drift (SQLite wrapper for reactive streams and type-safe schema generations)
*   **Automation:** Native Android Telephony listener (Background Message Interception)

---

## 🛠️ Developer Setup & Commands

### Prerequisites
*   Flutter SDK (v3.19.0+ recommended)
*   Android SDK (with cmdline-tools & platform tools installed)
*   Physical Android Device (for testing background Telephony APIs)

### Installation
1.  Clone the repository:
    ```bash
    git clone https://github.com/elishagerson/Pesaflow.git
    cd Pesaflow
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run code generators (Drift database models, Riverpod providers):
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

### Running the App
*   **Development Server:**
    ```bash
    flutter run
    ```
*   **Build Release APK:**
    ```bash
    flutter build apk --release
    ```

### Running Test Suite
Execute the comprehensive suite of 62+ regex, budget threshold, and CSV helper unit/widget tests:
```bash
flutter test
```

---

## 🎨 Branding & Design System
*   **Font Family:** Google Fonts **Outfit** (Display) / JetBrains Mono (Numeric Metrics)
*   **Launcher Icon:** Refined **3D squircle (rounded square)** featuring the official **"pesaflow"** geometric typography wordmark with vibrant neon-cyan and stark white contrast, optimized to look native in Pixel UI drawers.
