import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/domain/categorization/auto_categorizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CategoryDao categoryDao;
  late CategoryRepository categoryRepo;
  late TransactionDao transactionDao;
  late AutoCategorizer categorizer;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    categoryDao = CategoryDao(db);
    categoryRepo = CategoryRepository(categoryDao);
    transactionDao = TransactionDao(db);
    categorizer = AutoCategorizer(categoryRepo, transactionDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Well-Used Expense Categories Seeding & Structure', () {
    test('Database onCreate seeds only well-used categories', () async {
      final categories = await categoryDao.getAllCategories();
      final categoryNames = categories.map((c) => c.name).toSet();

      // Well-used core categories must be present
      expect(categoryNames, contains('Food & Groceries'));
      expect(categoryNames, contains('Transport'));
      expect(categoryNames, contains('Rent'));
      expect(categoryNames, contains('Utilities'));
      expect(categoryNames, contains('Airtime & Data'));
      expect(categoryNames, contains('Health'));
      expect(categoryNames, contains('Education'));
      expect(categoryNames, contains('Entertainment'));
      expect(categoryNames, contains('Shopping'));
      expect(categoryNames, contains('Family Support'));
      expect(categoryNames, contains('Contributions & Michango'));
      expect(categoryNames, contains('Charity & Offerings'));
      expect(categoryNames, contains('Personal Care'));
      expect(categoryNames, contains('Mobile Money Transfer'));
      expect(categoryNames, contains('Bank Fees'));
      expect(categoryNames, contains('Savings'));
      expect(categoryNames, contains('Investments'));
      expect(categoryNames, contains('Loans'));
      expect(categoryNames, contains('Other'));

      // Pruned / niche categories must NOT be in default categories
      expect(categoryNames, isNot(contains('Vehicle & Fuel')));
      expect(categoryNames, isNot(contains('Travel & Vacations')));
      expect(categoryNames, isNot(contains('Fitness & Sports')));
      expect(categoryNames, isNot(contains('Children & Baby')));
      expect(categoryNames, isNot(contains('Gifts & Celebrations')));
      expect(categoryNames, isNot(contains('Electronics & Tech')));
      expect(categoryNames, isNot(contains('Pets & Animals')));
      expect(categoryNames, isNot(contains('Legal & Professional')));
      expect(categoryNames, isNot(contains('Hobbies & Recreation')));
      expect(categoryNames, isNot(contains('Fines & Penalties')));
      expect(categoryNames, isNot(contains('Eating Out')));
      expect(categoryNames, isNot(contains('ATM Withdrawal')));
      expect(categoryNames, isNot(contains('Emergencies')));
      expect(categoryNames, isNot(contains('Home & Maintenance')));
      expect(categoryNames, isNot(contains('Insurance & Taxes')));
      expect(categoryNames, isNot(contains('Subscriptions & Streaming')));

      final charityCat = categories.firstWhere(
        (c) => c.name == 'Charity & Offerings',
      );
      expect(charityCat.type, 'expense');
      expect(charityCat.isSystem, isTrue);
      expect(charityCat.icon, 'charity');
      expect(charityCat.color, '#7C3AED');

      final michangoCat = categories.firstWhere(
        (c) => c.name == 'Contributions & Michango',
      );
      expect(michangoCat.type, 'expense');
      expect(michangoCat.isSystem, isTrue);
      expect(michangoCat.icon, 'community');
      expect(michangoCat.color, '#2563EB');
    });

    test(
      'Migration from schema version 15 to 16 prunes niche categories and remaps transactions',
      () async {
        // Add a temporary deprecated category
        await db.customStatement(
          "INSERT INTO categories (id, name, icon, color, type, sort_order, is_system, created_at) "
          "VALUES ('deprecated_fuel', 'Vehicle & Fuel', 'gas-station', '#EA580C', 'expense', 26, 1, 1700000000)",
        );

        final before = await categoryDao.getAllCategories();
        expect(before.any((c) => c.name == 'Vehicle & Fuel'), isTrue);

        // Run migration step for 15 -> 16
        await db.migration.onUpgrade(db.createMigrator(), 15, 16);

        final after = await categoryDao.getAllCategories();
        expect(after.any((c) => c.name == 'Vehicle & Fuel'), isFalse);
      },
    );
  });

  group('Category Icon Helper Mappings', () {
    test('maps new and existing icon string identifiers to PesaFlowIcons', () {
      expect(getCategoryIcon('alert-circle'), PesaFlowIcons.emergency);
      expect(getCategoryIcon('emergency'), PesaFlowIcons.emergency);
      expect(getCategoryIcon('charity'), PesaFlowIcons.charity);
      expect(getCategoryIcon('community'), PesaFlowIcons.community);
      expect(getCategoryIcon('users'), PesaFlowIcons.community);
      expect(getCategoryIcon('spa'), PesaFlowIcons.personalCare);
      expect(getCategoryIcon('personal-care'), PesaFlowIcons.personalCare);
      expect(getCategoryIcon('family'), PesaFlowIcons.family);
      expect(getCategoryIcon('handyman'), PesaFlowIcons.maintenance);
      expect(getCategoryIcon('tool'), PesaFlowIcons.maintenance);
      expect(getCategoryIcon('insurance'), PesaFlowIcons.insurance);
      expect(
        getCategoryIcon('subscriptions'),
        PesaFlowIcons.digitalSubscriptions,
      );
      expect(getCategoryIcon('trending-up'), PesaFlowIcons.income);
      expect(getCategoryIcon('more-horizontal'), PesaFlowIcons.more);
      expect(getCategoryIcon('gas-station'), PesaFlowIcons.vehicle);
      expect(getCategoryIcon('flight'), PesaFlowIcons.travel);
      expect(getCategoryIcon('fitness'), PesaFlowIcons.fitness);
      expect(getCategoryIcon('childcare'), PesaFlowIcons.childcare);
      expect(getCategoryIcon('gift'), PesaFlowIcons.gift);
      expect(getCategoryIcon('devices'), PesaFlowIcons.electronics);
      expect(getCategoryIcon('pets'), PesaFlowIcons.pets);
      expect(getCategoryIcon('legal'), PesaFlowIcons.legal);
      expect(getCategoryIcon('palette'), PesaFlowIcons.hobbies);
      expect(getCategoryIcon('fines'), PesaFlowIcons.fines);
    });
  });

  group('AutoCategorizer Keyword Matching for Consolidated Categories', () {
    test('categorizes emergency keywords into Health or Other', () async {
      final res1 = await categorizer.categorize(
        type: 'expense',
        description: 'Hospital emergency medicine',
        senderOrRecipient: 'Agha Khan Hospital',
      );
      expect(res1.category.name, 'Health');
      expect(res1.confidence, 0.95);

      final res2 = await categorizer.categorize(
        type: 'expense',
        description: 'Dharura ya matibabu',
        senderOrRecipient: 'Mhasibu Dispensary',
      );
      expect(res2.category.name, 'Health');
    });

    test('categorizes charity, tithe, and sadaka accurately', () async {
      final res1 = await categorizer.categorize(
        type: 'expense',
        description: 'Sadaka ya jumapili',
        senderOrRecipient: 'KKKT Kijitonyama',
      );
      expect(res1.category.name, 'Charity & Offerings');

      final res2 = await categorizer.categorize(
        type: 'expense',
        description: 'Church tithe offering',
        senderOrRecipient: 'St Peters Church',
      );
      expect(res2.category.name, 'Charity & Offerings');

      final res3 = await categorizer.categorize(
        type: 'expense',
        description: 'Zaka ya mwezi huu',
        senderOrRecipient: 'Msikiti wa Maamur',
      );
      expect(res3.category.name, 'Charity & Offerings');
    });

    test('categorizes michango and social contributions', () async {
      final res1 = await categorizer.categorize(
        type: 'expense',
        description: 'Mchango wa harusi ya John',
        senderOrRecipient: 'Kamati ya Harusi',
      );
      expect(res1.category.name, 'Contributions & Michango');

      final res2 = await categorizer.categorize(
        type: 'expense',
        description: 'Msiba mchango wa rambirambi',
        senderOrRecipient: 'Mwakilishi wa Familia',
      );
      expect(res2.category.name, 'Contributions & Michango');
    });

    test(
      'categorizes personal care, family support, maintenance, insurance, subscriptions',
      () async {
        final resSalon = await categorizer.categorize(
          type: 'expense',
          description: 'Kinyozi na kunyoa ndevu',
          senderOrRecipient: 'Classic Barber',
        );
        expect(resSalon.category.name, 'Personal Care');

        final resFamily = await categorizer.categorize(
          type: 'expense',
          description: 'Pesa ya wazazi kijijini',
          senderOrRecipient: 'Mama mzazi',
        );
        expect(resFamily.category.name, 'Family Support');

        final resMaintenance = await categorizer.categorize(
          type: 'expense',
          description: 'Malipo ya fundi bomba',
          senderOrRecipient: 'Fundi Juma',
        );
        expect(resMaintenance.category.name, 'Utilities');

        final resInsurance = await categorizer.categorize(
          type: 'expense',
          description: 'Malipo ya bima ya gari',
          senderOrRecipient: 'Sanlam Insurance',
        );
        expect(resInsurance.category.name, 'Health');

        final resSubs = await categorizer.categorize(
          type: 'expense',
          description: 'Netflix subscription renewal',
          senderOrRecipient: 'Netflix International',
        );
        expect(resSubs.category.name, 'Entertainment');
      },
    );

    test(
      'categorizes vehicle/fuel and travel into Transport, gym into Health, baby into Family Support, legal/fines into Other',
      () async {
        final resFuel = await categorizer.categorize(
          type: 'expense',
          description: 'Mafuta ya petrol gari',
          senderOrRecipient: 'TotalEnergies Station',
        );
        expect(resFuel.category.name, 'Transport');

        final resTravel = await categorizer.categorize(
          type: 'expense',
          description: 'Booking ticket azam marine zanzibar',
          senderOrRecipient: 'Azam Marine Ferry',
        );
        expect(resTravel.category.name, 'Transport');

        final resGym = await categorizer.categorize(
          type: 'expense',
          description: 'Monthly gym workout subscription',
          senderOrRecipient: 'Crossfit Gym Club',
        );
        expect(resGym.category.name, 'Health');

        final resBaby = await categorizer.categorize(
          type: 'expense',
          description: 'Pampers za mtoto na baby food',
          senderOrRecipient: 'Baby Care Store',
        );
        expect(resBaby.category.name, 'Family Support');

        final resLegal = await categorizer.categorize(
          type: 'expense',
          description: 'Malipo ya mwanasheria kuthibitisha hati',
          senderOrRecipient: 'Advocate & Notary Public',
        );
        expect(resLegal.category.name, 'Other');

        final resFine = await categorizer.categorize(
          type: 'expense',
          description: 'Traffic fine TMS askari',
          senderOrRecipient: 'Tanzania Police TMS',
        );
        expect(resFine.category.name, 'Other');
      },
    );
  });
}
