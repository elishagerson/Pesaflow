import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/sms_review/sms_review_screen.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

void main() {
  final now = DateTime.now();

  final testAccount = Account(
    id: 'acc1',
    name: 'M-Pesa',
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

  final testTransaction = Transaction(
    id: 'txn1',
    accountId: 'acc1',
    categoryId: 'cat1',
    amount: 2500000,
    type: 'expense',
    description: 'Sporty Bet PUSH',
    source: 'sms',
    reference: '26607196230775',
    rawSms: 'Payment Successful to Sporty Bet PUSH, Amount TSh 25,000.',
    createdAt: now,
    updatedAt: now,
  );

  final testItem = TransactionWithCategoryAndAccount(
    transaction: testTransaction,
    category: testCategory,
    account: testAccount,
  );

  Widget createTestWidget({
    List<TransactionWithCategoryAndAccount> items = const [],
  }) {
    return ProviderScope(
      overrides: [
        reviewQueueStreamProvider.overrideWith((ref) => Stream.value(items)),
        categoriesFutureProvider.overrideWith(
          (ref) => Future.value([testCategory]),
        ),
        currencyShowDecimalsProvider.overrideWith((ref) => Stream.value(false)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SmsReviewScreen(),
      ),
    );
  }

  group('SmsReviewScreen Icons & Buttons Refinement', () {
    testWidgets(
      'renders empty state with success icon when no reviews pending',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(items: []));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.text('SMS Review'), findsOneWidget);
        expect(find.text('All Clear!'), findsOneWidget);
        expect(find.byIcon(PesaFlowIcons.selectAll), findsOneWidget);
      },
    );

    testWidgets(
      'renders pending card with wallet icon, action buttons, and icons',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(items: [testItem]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Description and account name
        expect(find.text('Sporty Bet PUSH'), findsOneWidget);
        expect(find.text('M-Pesa'), findsOneWidget);

        // Account wallet icon
        expect(find.byIcon(PesaFlowIcons.wallet), findsOneWidget);

        // Action pills: Category, Approve, Reject
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('Approve'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);

        expect(find.byIcon(PesaFlowIcons.category), findsOneWidget);
        expect(find.byIcon(PesaFlowIcons.check), findsOneWidget);
        expect(find.byIcon(PesaFlowIcons.close), findsWidgets);
      },
    );

    testWidgets(
      'toggles select all and displays refined floating batch action dock',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(items: [testItem]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Tap "Select All" button in header
        await tester.tap(find.text('Select All'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Header button toggled to Deselect with deselect icon
        expect(find.text('Deselect'), findsOneWidget);
        expect(find.byIcon(PesaFlowIcons.deselect), findsOneWidget);

        // Floating batch dock is now visible with icons and item count
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Category (1)'), findsOneWidget);
        expect(find.text('Approve (1)'), findsOneWidget);

        // Tap "Cancel" on floating dock
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Selection is cleared and dock dismissed
        expect(find.text('Cancel'), findsNothing);
        expect(find.text('Select All'), findsOneWidget);
      },
    );
  });

  group('the review card is not framed', () {
    testWidgets(
      'the row is a bleed surface: no hairline, no shadow, no edge light',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(items: [testItem]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final rows = tester.widgetList<PesaSurface>(
          find.descendant(
            of: find.byType(SwipeableCard),
            matching: find.byType(PesaSurface),
          ),
        );
        expect(rows, isNotEmpty);

        for (final row in rows) {
          expect(((row.stroke ?? const Color(0x00000000)).a * 255).round(), 0);
          expect(row.shadows, isEmpty);
          expect(row.edgeLight, isFalse);
          expect(row.radius, AppTheme.radiusCard);
          expect(
            row.padding.resolve(TextDirection.ltr),
            const EdgeInsets.all(kSpacing14),
          );
        }
      },
    );

    testWidgets(
      'selecting a row keeps only the fill tint — the border does not come back',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(items: [testItem]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.tap(find.text('Sporty Bet PUSH'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final row = tester.widget<PesaSurface>(
          find.descendant(
            of: find.byType(SwipeableCard),
            matching: find.byType(PesaSurface),
          ),
        );
        expect(row.stroke?.a ?? 0, 0);
        expect(row.shadows, isEmpty);
        // Selected state is carried by the fill alone.
        final theme = Theme.of(tester.element(find.text('Sporty Bet PUSH')));
        expect(row.fill, theme.colorScheme.primary.withValues(alpha: 0.06));
      },
    );

    testWidgets('the floating dock keeps the elevation an overlay needs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(items: [testItem]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('Select All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final dock = tester.widget<PesaSurface>(
        find.ancestor(
          of: find.text('Cancel'),
          matching: find.byType(PesaSurface),
        ),
      );
      expect(dock.shadows, isNotEmpty);
      expect(dock.radius, AppTheme.radiusDialog);
      // A card, not a bleed: `.bleed` pins stroke to a transparent colour,
      // which is how the borderless variant marks itself.
      expect(dock.stroke, isNull);
      expect(dock.edgeLight, isFalse);
    });
  });
}
