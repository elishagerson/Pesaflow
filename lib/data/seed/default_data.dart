import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';

class DefaultSeeder {
  final AppDatabase db;
  const DefaultSeeder(this.db);

  Future<void> seedIfNeeded() async {
    final accountDao = AccountDao(db);
    final categoryDao = CategoryDao(db);

    final accounts = await accountDao.getAllAccounts();
    if (accounts.isNotEmpty) return;

    const uuid = Uuid();
    await accountDao.insertAccount(
      Account(
        id: uuid.v4(),
        name: 'Cash',
        type: 'cash',
        balance: 0,
        icon: 'wallet',
        sortOrder: 0,
        isArchived: false,
        createdAt: DateTime.now(),
      ),
    );

    final categories = await categoryDao.getAllCategories();
    if (categories.isNotEmpty) return;

    final defaultCategories = [
      ('Food & Groceries', 'cart', '#FF9800', 0, 'expense'),
      ('Transport', 'bus', '#FFC107', 1, 'expense'),
      ('Rent', 'home', '#F44336', 2, 'expense'),
      ('Utilities', 'zap', '#E91E63', 3, 'expense'),
      ('Airtime & Data', 'phone', '#9C27B0', 4, 'expense'),
      ('Health', 'heart', '#E91E63', 5, 'expense'),
      ('Education', 'book', '#2196F3', 6, 'expense'),
      ('Entertainment', 'film', '#673AB7', 7, 'expense'),
      ('Shopping', 'shopping-bag', '#00BCD4', 8, 'expense'),
      ('Family Support', 'family', '#0D9488', 9, 'expense'),
      ('Contributions & Michango', 'community', '#2563EB', 10, 'expense'),
      ('Charity & Offerings', 'charity', '#7C3AED', 11, 'expense'),
      ('Personal Care', 'spa', '#DB2777', 12, 'expense'),
      ('Mobile Money Transfer', 'send', '#607D8B', 13, 'expense'),
      ('Bank Fees', 'credit-card', '#D32F2F', 14, 'expense'),
      ('Savings', 'piggy-bank', '#4CAF50', 15, 'expense'),
      ('Investments', 'trending-up', '#1B5E20', 16, 'expense'),
      ('Loans', 'credit-card', '#9C27B0', 17, 'expense'),
      ('Other', 'more-horizontal', '#9E9E9E', 18, 'expense'),
      ('Salary', 'briefcase', '#2E7D32', 19, 'income'),
      ('Business', 'store', '#008080', 20, 'income'),
      ('Other Income', 'plus-circle', '#808080', 21, 'income'),
    ];

    for (final (name, icon, color, order, type) in defaultCategories) {
      await categoryDao.insertCategory(
        Category(
          id: uuid.v4(),
          name: name,
          icon: icon,
          color: color,
          type: type,
          sortOrder: order,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}
