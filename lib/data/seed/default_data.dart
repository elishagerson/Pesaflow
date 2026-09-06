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
      ('Eating Out', 'coffee', '#795548', 9, 'expense'),
      ('Mobile Money Transfer', 'send', '#607D8B', 10, 'expense'),
      ('Bank Fees', 'credit-card', '#D32F2F', 11, 'expense'),
      ('ATM Withdrawal', 'banknote', '#4CAF50', 12, 'expense'),
      ('Savings', 'piggy-bank', '#4CAF50', 13, 'expense'),
      ('Investments', 'trending-up', '#1B5E20', 14, 'expense'),
      ('Loans', 'credit-card', '#9C27B0', 15, 'expense'),
      ('Other', 'more-horizontal', '#9E9E9E', 16, 'expense'),
      ('Emergencies', 'alert-circle', '#E11D48', 17, 'expense'),
      ('Charity & Offerings', 'charity', '#7C3AED', 18, 'expense'),
      ('Contributions & Michango', 'community', '#2563EB', 19, 'expense'),
      ('Personal Care', 'spa', '#DB2777', 20, 'expense'),
      ('Family Support', 'family', '#0D9488', 21, 'expense'),
      ('Home & Maintenance', 'handyman', '#B45309', 22, 'expense'),
      ('Insurance & Taxes', 'insurance', '#0284C7', 23, 'expense'),
      ('Subscriptions & Streaming', 'subscriptions', '#4F46E5', 24, 'expense'),
      ('Salary', 'briefcase', '#2E7D32', 25, 'income'),
      ('Business', 'store', '#008080', 26, 'income'),
      ('Other Income', 'plus-circle', '#808080', 27, 'income'),
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
