import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/presentation/loans/loan_form_screen.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class MockActiveTrackerIdNotifier extends ActiveTrackerIdNotifier {
  @override
  String build() => 'test-tracker-id';
}

class FakeLoanRepository extends Fake implements LoanRepository {
  final List<Loan> createdLoans = [];

  @override
  Future<int> createLoan(Loan loan) async {
    createdLoans.add(loan);
    return 1;
  }

  @override
  Future<Loan?> getLoanById(String id) async => null;
}

void main() {
  late FakeLoanRepository fakeLoanRepo;

  setUp(() {
    fakeLoanRepo = FakeLoanRepository();
  });

  Widget createTestWidget({String? loanId}) {
    return ProviderScope(
      overrides: [
        loanRepositoryProvider.overrideWithValue(fakeLoanRepo),
        activeTrackerIdProvider.overrideWith(
          () => MockActiveTrackerIdNotifier(),
        ),
        currencyShowDecimalsProvider.overrideWith((ref) => Stream.value(false)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: LoanFormScreen(loanId: loanId),
      ),
    );
  }

  group('LoanFormScreen Executive Redesign', () {
    testWidgets(
      'renders elevated loan form with starters carousel, hero input, and live projection',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Section headers & titles
        expect(find.text('QUICK STARTERS'), findsOneWidget);
        expect(find.text('PRINCIPAL AMOUNT'), findsOneWidget);
        expect(find.text('LIVE LOAN PROJECTION'), findsOneWidget);
        expect(find.text('LENDER & PURPOSE'), findsOneWidget);
        expect(find.text('CATEGORY & REPAYMENT SCHEDULE'), findsOneWidget);
        expect(find.text('INTEREST & FEES'), findsOneWidget);

        // Starters present
        expect(find.text('M-Pesa Songesha'), findsOneWidget);
        expect(find.text('Tigo Nivushe'), findsOneWidget);
        expect(find.text('Airtel Timiza'), findsOneWidget);

        // Submit button visible after scrolling or verify lender & starters
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(find.text('Record Loan'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a starter card autofills lender, category, amount, interest rate, and term',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap M-Pesa Songesha starter
        await tester.tap(find.text('M-Pesa Songesha'));
        await tester.pumpAndSettle();

        // Verify autofilled amount (50,000)
        expect(find.text('50000'), findsOneWidget);
        // Verify lender name autofilled
        expect(find.text('Vodacom M-Pesa'), findsOneWidget);
        // Verify purpose autofilled
        expect(find.text('M-Pesa Songesha'), findsWidgets);
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

        // Tap +50K
        await tester.tap(find.text('+50K'));
        await tester.pumpAndSettle();
        expect(find.text('50000'), findsOneWidget);

        // Tap +100K -> total 150000
        await tester.tap(find.text('+100K'));
        await tester.pumpAndSettle();
        expect(find.text('150000'), findsOneWidget);

        // Tap Clear
        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();
        expect(find.text('150000'), findsNothing);
      },
    );

    testWidgets('quick term preset buttons update term days', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Scroll down to see term presets
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();

      // Tap 60 Days preset
      await tester.tap(find.text('60 Days'));
      await tester.pumpAndSettle();

      // Verify term reflects 60 days
      expect(find.text('Due in 60 days'), findsOneWidget);
    });

    testWidgets('submitting valid form creates a loan via LoanRepository', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Autofill using M-Pesa Songesha starter
      await tester.tap(find.text('M-Pesa Songesha'));
      await tester.pumpAndSettle();

      // Scroll down to submit button
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();

      // Tap Record Loan
      await tester.tap(find.text('Record Loan'));
      await tester.pumpAndSettle();

      // Check repository was called
      expect(fakeLoanRepo.createdLoans.length, 1);
      final created = fakeLoanRepo.createdLoans.first;
      expect(created.sender, 'Vodacom M-Pesa');
      expect(created.amount, 5000000); // 50,000 TSh in cents
      expect(created.interestRate, 5.0);
      expect(created.status, 'active');
    });
  });
}
