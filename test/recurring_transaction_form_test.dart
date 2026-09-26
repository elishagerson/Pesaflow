import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/recurring_transaction_repository.dart';
import 'package:pesaflow/presentation/recurring/recurring_transaction_form_screen.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class MockActiveTrackerIdNotifier extends ActiveTrackerIdNotifier {
  @override
  String build() => 'test-tracker-id';
}

class FakeRecurringTransactionRepository extends Fake
    implements RecurringTransactionRepository {
  final List<RecurringTransaction> created = [];
  final List<RecurringTransaction> updated = [];

  @override
  Future<int> createRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    created.add(transaction);
    return 1;
  }

  @override
  Future<bool> updateRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    updated.add(transaction);
    return true;
  }

  @override
  Future<RecurringTransaction?> getById(String id) async => null;
}

void main() {
  late FakeRecurringTransactionRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeRecurringTransactionRepository();
  });

  final testAccounts = [
    Account(
      id: 'acc-1',
      name: 'M-Pesa Wallet',
      type: 'mobile_money',
      balance: 15000000,
      isArchived: false,
      sortOrder: 0,
      icon: 'card',
      createdAt: DateTime.now(),
    ),
  ];

  final testCategories = [
    Category(
      id: 'cat-util',
      name: 'Utilities',
      icon: 'category',
      color: '#F59E0B',
      type: 'expense',
      isSystem: true,
      sortOrder: 0,
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'cat-rent',
      name: 'Housing',
      icon: 'home',
      color: '#10B981',
      type: 'expense',
      isSystem: true,
      sortOrder: 1,
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'cat-sal',
      name: 'Salary',
      icon: 'income',
      color: '#059669',
      type: 'income',
      isSystem: true,
      sortOrder: 2,
      createdAt: DateTime.now(),
    ),
  ];

  Widget createTestWidget({String? recurringId}) {
    return ProviderScope(
      overrides: [
        recurringTransactionRepositoryProvider.overrideWithValue(fakeRepo),
        activeTrackerIdProvider.overrideWith(
          () => MockActiveTrackerIdNotifier(),
        ),
        accountsStreamProvider.overrideWith(
          (ref) => Stream.value(testAccounts),
        ),
        categoriesFutureProvider.overrideWith(
          (ref) => Future.value(testCategories),
        ),
        currencyShowDecimalsProvider.overrideWith((ref) => Stream.value(false)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: RecurringTransactionFormScreen(recurringId: recurringId),
      ),
    );
  }

  group('RecurringTransactionFormScreen Executive Redesign', () {
    testWidgets(
      'renders elevated recurring form with starters, hero input, and projection',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Section headers
        expect(find.text('QUICK STARTERS'), findsOneWidget);
        expect(find.text('RECURRING AMOUNT'), findsOneWidget);
        expect(find.text('FLOW TYPE'), findsOneWidget);
        expect(find.text('DETAILS & IDENTIFICATION'), findsOneWidget);
        expect(find.text('ACCOUNT & CATEGORY'), findsOneWidget);
        expect(find.text('CADENCE & SCHEDULE'), findsOneWidget);

        // Starters present in viewport
        expect(find.text('LUKU Electricity'), findsOneWidget);
        expect(find.text('DAWASA Water'), findsOneWidget);

        // Submit button
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(find.text('Create Recurring Flow'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a starter card autofills description, amount, keywords, and updates projection',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap LUKU Electricity starter
        await tester.tap(find.text('LUKU Electricity'));
        await tester.pumpAndSettle();

        // Verify amount
        expect(find.text('50000'), findsOneWidget);
        // Description field
        expect(find.text('LUKU Electricity'), findsWidgets);
        // Projected monthly impact (Tsh 50,000)
        expect(find.text('Tsh 50,000'), findsWidgets);
      },
    );

    testWidgets(
      'quick increment chips add amounts and clear button resets amount',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap +25K
        await tester.tap(find.text('+25K'));
        await tester.pumpAndSettle();
        expect(find.text('25000'), findsOneWidget);

        // Tap +50K -> total 75000
        await tester.tap(find.text('+50K'));
        await tester.pumpAndSettle();
        expect(find.text('75000'), findsOneWidget);

        // Tap Clear (close icon button on amount field)
        await tester.tap(find.byIcon(PesaFlowIcons.close));
        await tester.pumpAndSettle();
        expect(find.text('75000'), findsNothing);
      },
    );

    testWidgets(
      'frequency chips update cadence and annual commitment projection',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter 50000 in amount
        await tester.enterText(find.byType(TextFormField).first, '50000');
        await tester.pumpAndSettle();

        // Scroll down to cadence card
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -450),
        );
        await tester.pumpAndSettle();

        // Tap Weekly
        await tester.tap(find.text('Weekly'));
        await tester.pumpAndSettle();

        // Scroll back up to check annual projection
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, 450),
        );
        await tester.pumpAndSettle();

        // 50,000 * 52 = 2,600,000
        expect(find.text('Tsh 2,600,000'), findsOneWidget);
      },
    );

    testWidgets(
      'submitting valid form creates a recurring flow via repository',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap LUKU Electricity starter
        await tester.tap(find.text('LUKU Electricity'));
        await tester.pumpAndSettle();

        // Scroll down to submit button
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -800),
        );
        await tester.pumpAndSettle();

        // Tap Create Recurring Flow
        await tester.tap(find.text('Create Recurring Flow'));
        await tester.pumpAndSettle();

        // Verify created in repository
        expect(fakeRepo.created.length, 1);
        final created = fakeRepo.created.first;
        expect(created.amount, 5000000); // 50,000 TSh in cents
        expect(created.type, 'expense');
        expect(created.frequency, 'monthly');
        expect(created.status, 'active');
        expect(created.accountId, 'acc-1');
      },
    );
  });
}
