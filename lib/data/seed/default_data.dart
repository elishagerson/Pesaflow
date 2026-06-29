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
      ('Food', 'restaurant', 0, 'expense'),
      ('Transport', 'directions_bus', 1, 'expense'),
      ('Utilities', 'bolt', 2, 'expense'),
      ('Entertainment', 'movie', 3, 'expense'),
      ('Health', 'local_hospital', 4, 'expense'),
      ('Shopping', 'shopping_bag', 5, 'expense'),
      ('Income', 'work', 6, 'income'),
      ('Other', 'category', 7, 'expense'),
    ];

    for (final (name, icon, order, type) in defaultCategories) {
      await categoryDao.insertCategory(
        Category(
          id: uuid.v4(),
          name: name,
          icon: icon,
          color: '#6B7280',
          type: type,
          sortOrder: order,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}
