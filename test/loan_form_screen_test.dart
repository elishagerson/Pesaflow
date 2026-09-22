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
        expect(find.text('LOAN PRINCIPAL'), findsOneWidget);
        expect(find.text('LIVE REPAYMENT PROJECTION'), findsOneWidget);
        expect(find.text('LENDER & PURPOSE'), findsOneWidget);
        expect(find.text('CATEGORY'), findsOneWidget);
        expect(find.text('TERM & TIMELINE'), findsOneWidget);
        expect(find.text('INTEREST & FEES'), findsOneWidget);

        // Starters present
        expect(find.text('M-Pesa Songesha'), findsOneWidget);
        expect(find.text('Tigo Nivushe'), findsOneWidget);
        expect(find.text('Airtel Timiza'), findsOneWidget);

        // Submit button
        expect(find.text('Record Loan Obligation'), findsOneWidget);
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
        expect(find.text('Vodacom Songesha'), findsOneWidget);
        // Verify Toast message
        expect(find.text('Applied M-Pesa Songesha starter'), findsOneWidget);
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

    testWidgets(
      'quick term preset buttons update term days',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap 60d preset
        await tester.tap(find.text('60d'));
        await tester.pumpAndSettle();

        // Verify 60 days in term input
        expect(find.text('60'), findsOneWidget);
      },
    );

    testWidgets(
      'submitting valid form creates a loan via LoanRepository',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Autofill using CRDB Personal Credit starter
        await tester.tap(find.text('CRDB Personal Credit'));
        await tester.pumpAndSettle();

        // Scroll down to submit button
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();

        // Tap Record Loan Obligation
        await tester.tap(find.text('Record Loan Obligation'));
        await tester.pumpAndSettle();

        // Check repository was called
        expect(fakeLoanRepo.createdLoans.length, 1);
        final created = fakeLoanRepo.createdLoans.first;
        expect(created.sender, 'CRDB Bank');
        expect(created.amount, 150000000); // 1,500,000 TSh in cents
        expect(created.interestRate, 14.0);
        expect(created.status, 'active');
      },
    );
  });
}
