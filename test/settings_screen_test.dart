import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/settings/settings_screen.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class MockActiveTrackerIdNotifier extends ActiveTrackerIdNotifier {
  @override
  String build() => 'trk1';
}

class MockThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.dark;
}

void main() {
  final now = DateTime.now();

  final testAccount = Account(
    id: 'acc1',
    name: 'M-Pesa Wallet',
    type: 'mobile_money',
    balance: 5000000,
    icon: 'wallet',
    isArchived: false,
    sortOrder: 1,
    createdAt: now,
  );

  final testCategory = Category(
    id: 'cat1',
    name: 'Dining & Food',
    color: '#FF5722',
    icon: 'restaurant',
    type: 'expense',
    isSystem: true,
    sortOrder: 1,
    createdAt: now,
  );

  final testTracker = Tracker(
    id: 'trk1',
    name: 'Executive Vault',
    icon: 'home',
    color: '#4CAF50',
    isArchived: false,
    createdAt: now,
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        accountsStreamProvider.overrideWith((ref) => Stream.value([testAccount])),
        categoriesFutureProvider.overrideWith((ref) => Future.value([testCategory])),
        totalTransactionsCountProvider.overrideWith((ref) => Stream.value(128)),
        allTrackersStreamProvider.overrideWith((ref) => Stream.value([testTracker])),
        activeTrackerIdProvider.overrideWith(() => MockActiveTrackerIdNotifier()),
        appLockEnabledProvider.overrideWith((ref) => Stream.value(false)),
        lockScreenBalanceEnabledProvider.overrideWith((ref) => Stream.value(true)),
        currencyShowDecimalsProvider.overrideWith((ref) => Stream.value(true)),
        smsAutoDeduplicationProvider.overrideWith((ref) => Stream.value(true)),
        autoBudgetEnabledProvider.overrideWith((ref) => Stream.value(false)),
        themeModeProvider.overrideWith(() => MockThemeModeNotifier()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen Redesign', () {
    testWidgets('renders title, executive snapshot card, and offline badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Title in IosLargeTitleHeader (large + collapsed)
      expect(find.text('Settings'), findsAtLeastNWidgets(1));

      // Executive overview card with active workspace and offline status
      expect(find.text('Executive Vault'), findsOneWidget);
      expect(find.text('Active Offline Workspace'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);

      // 3-Metric Summary Strip
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
    });

    testWidgets('renders all consolidated executive section headers', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ORGANIZATION & STRUCTURE'), findsOneWidget);
      expect(find.text('AUTOMATION & BUDGETING'), findsOneWidget);
      expect(find.text('PREFERENCES & SECURITY'), findsOneWidget);
      expect(find.text('DATA & STORAGE'), findsOneWidget);
    });

    testWidgets('renders key organization and security rows without duplicates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Organization rows
      expect(find.text('Manage Workspaces'), findsOneWidget);
      expect(find.text('Accounts Manager'), findsOneWidget);
      expect(find.text('Categories Manager'), findsOneWidget);
      expect(find.text('Recurring & Bills'), findsOneWidget);

      // Automation & preferences rows
      expect(find.text('Auto-Budget on Income'), findsOneWidget);
      expect(find.text('SMS Auto-Deduplication'), findsOneWidget);
      expect(find.text('App Theme'), findsOneWidget);
      expect(find.text('Show Decimals'), findsOneWidget);
      expect(find.text('Biometric App Lock'), findsOneWidget);
      expect(find.text('Offline Privacy Guarantee'), findsOneWidget);

      // Data rows
      expect(find.text('Export Monthly Statement'), findsOneWidget);
      expect(find.text('Backup Database'), findsOneWidget);
      expect(find.text('Restore Database'), findsOneWidget);

      // Hardcoded footer is removed
      expect(find.text('PesaFlow v1.0.0'), findsNothing);
      expect(
        find.text('100% Offline & Private • Built for Tanzania 🇹🇿'),
        findsNothing,
      );
    });
  });
}
