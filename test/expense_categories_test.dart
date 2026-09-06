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

  group('New Expense Categories Seeding & Structure', () {
    test('Database onCreate seeds all new expense categories', () async {
      final categories = await categoryDao.getAllCategories();
      final categoryNames = categories.map((c) => c.name).toSet();

      expect(categoryNames, contains('Emergencies'));
      expect(categoryNames, contains('Charity & Offerings'));
      expect(categoryNames, contains('Contributions & Michango'));
      expect(categoryNames, contains('Personal Care'));
      expect(categoryNames, contains('Family Support'));
      expect(categoryNames, contains('Home & Maintenance'));
      expect(categoryNames, contains('Insurance & Taxes'));
      expect(categoryNames, contains('Subscriptions & Streaming'));
      expect(categoryNames, contains('Vehicle & Fuel'));
      expect(categoryNames, contains('Travel & Vacations'));
      expect(categoryNames, contains('Fitness & Sports'));
      expect(categoryNames, contains('Children & Baby'));
      expect(categoryNames, contains('Gifts & Celebrations'));
      expect(categoryNames, contains('Electronics & Tech'));
      expect(categoryNames, contains('Pets & Animals'));
      expect(categoryNames, contains('Legal & Professional'));
      expect(categoryNames, contains('Hobbies & Recreation'));
      expect(categoryNames, contains('Fines & Penalties'));

      final emergencyCat =
          categories.firstWhere((c) => c.name == 'Emergencies');
      expect(emergencyCat.type, 'expense');
      expect(emergencyCat.isSystem, isTrue);
      expect(emergencyCat.icon, 'alert-circle');
      expect(emergencyCat.color, '#E11D48');

      final charityCat =
          categories.firstWhere((c) => c.name == 'Charity & Offerings');
      expect(charityCat.type, 'expense');
      expect(charityCat.isSystem, isTrue);
      expect(charityCat.icon, 'charity');
      expect(charityCat.color, '#7C3AED');

      final michangoCat =
          categories.firstWhere((c) => c.name == 'Contributions & Michango');
      expect(michangoCat.type, 'expense');
      expect(michangoCat.isSystem, isTrue);
      expect(michangoCat.icon, 'community');
      expect(michangoCat.color, '#2563EB');

      final fuelCat =
          categories.firstWhere((c) => c.name == 'Vehicle & Fuel');
      expect(fuelCat.type, 'expense');
      expect(fuelCat.isSystem, isTrue);
      expect(fuelCat.icon, 'gas-station');
      expect(fuelCat.color, '#EA580C');
    });

    test('Migration from schema version 14 to 15 seeds missing categories for existing users', () async {
      // Delete Vehicle & Fuel and Travel & Vacations to simulate pre-v15 database
      await db.customStatement("DELETE FROM categories WHERE name = 'Vehicle & Fuel'");
      await db.customStatement("DELETE FROM categories WHERE name = 'Travel & Vacations'");

      final before = await categoryDao.getAllCategories();
      expect(before.any((c) => c.name == 'Vehicle & Fuel'), isFalse);
      expect(before.any((c) => c.name == 'Travel & Vacations'), isFalse);

      // Run migration step for 14 -> 15
      await db.migration.onUpgrade(db.createMigrator(), 14, 15);

      final after = await categoryDao.getAllCategories();
      expect(after.any((c) => c.name == 'Vehicle & Fuel'), isTrue);
      expect(after.any((c) => c.name == 'Travel & Vacations'), isTrue);

      // Ensure no duplicate categories are added if run again
      await db.migration.onUpgrade(db.createMigrator(), 14, 15);
      final afterRerun = await categoryDao.getAllCategories();
      expect(
        afterRerun.where((c) => c.name == 'Vehicle & Fuel').length,
        1,
      );
    });
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
      expect(getCategoryIcon('subscriptions'), PesaFlowIcons.digitalSubscriptions);
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

  group('AutoCategorizer Keyword Matching for New Categories', () {
    test('categorizes emergency keywords accurately', () async {
      final res1 = await categorizer.categorize(
        type: 'expense',
        description: 'Hospital emergency medicine',
        senderOrRecipient: 'Agha Khan Hospital',
      );
      expect(res1.category.name, 'Emergencies');
      expect(res1.confidence, 0.95);

      final res2 = await categorizer.categorize(
        type: 'expense',
        description: 'Dharura ya matibabu',
        senderOrRecipient: 'Mhasibu Dispensary',
      );
      expect(res2.category.name, 'Emergencies');
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

    test('categorizes personal care, family support, maintenance, insurance, subscriptions', () async {
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
      expect(resMaintenance.category.name, 'Home & Maintenance');

      final resInsurance = await categorizer.categorize(
        type: 'expense',
        description: 'Malipo ya bima ya gari',
        senderOrRecipient: 'Sanlam Insurance',
      );
      expect(resInsurance.category.name, 'Insurance & Taxes');

      final resSubs = await categorizer.categorize(
        type: 'expense',
        description: 'Netflix subscription renewal',
        senderOrRecipient: 'Netflix International',
      );
      expect(resSubs.category.name, 'Subscriptions & Streaming');
    });

    test('categorizes lifestyle, vehicle, travel, fitness, childcare, legal, fines', () async {
      final resFuel = await categorizer.categorize(
        type: 'expense',
        description: 'Mafuta ya petrol gari',
        senderOrRecipient: 'TotalEnergies Station',
      );
      expect(resFuel.category.name, 'Vehicle & Fuel');

      final resTravel = await categorizer.categorize(
        type: 'expense',
        description: 'Booking ticket azam marine zanzibar',
        senderOrRecipient: 'Azam Marine Ferry',
      );
      expect(resTravel.category.name, 'Travel & Vacations');

      final resGym = await categorizer.categorize(
        type: 'expense',
        description: 'Monthly gym workout subscription',
        senderOrRecipient: 'Crossfit Gym Club',
      );
      expect(resGym.category.name, 'Fitness & Sports');

      final resBaby = await categorizer.categorize(
        type: 'expense',
        description: 'Pampers za mtoto na baby food',
        senderOrRecipient: 'Baby Care Store',
      );
      expect(resBaby.category.name, 'Children & Baby');

      final resLegal = await categorizer.categorize(
        type: 'expense',
        description: 'Malipo ya mwanasheria kuthibitisha hati',
        senderOrRecipient: 'Advocate & Notary Public',
      );
      expect(resLegal.category.name, 'Legal & Professional');

      final resFine = await categorizer.categorize(
        type: 'expense',
        description: 'Traffic fine TMS askari',
        senderOrRecipient: 'Tanzania Police TMS',
      );
      expect(resFine.category.name, 'Fines & Penalties');
    });
  });
}
