import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/daos/category_dao.dart';
import '../database/database_providers.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final dao = ref.watch(categoryDaoProvider);
  return CategoryRepository(dao);
});

class CategoryRepository {
  final CategoryDao _categoryDao;

  /// Canonical category name for manual/SMS loan-payment transactions.
  static const String loanPaymentCategoryName = 'Loan Payment';

  CategoryRepository(this._categoryDao);

  Stream<List<Category>> watchAllCategories() =>
      _categoryDao.watchAllCategories();

  Future<List<Category>> getAllCategories() => _categoryDao.getAllCategories();

  /// Alias used by the auto-categorizer engine.
  Future<List<Category>> getCategories() => getAllCategories();

  Future<List<Category>> getCategoriesByType(String type) =>
      _categoryDao.getCategoriesByType(type);

  Future<Category?> getCategoryById(String id) =>
      _categoryDao.getCategoryById(id);

  Future<int> createCategory(Category category) =>
      _categoryDao.insertCategory(category);

  /// Resolves the category for a loan-payment transaction.
  ///
  /// Priority:
  /// 1. Case-insensitive match of the loan's own [loanCategory] name.
  /// 2. The shared 'Loan Payment' system category — created once if missing
  ///    (idempotent, works on existing installs).
  /// 3. First expense category as a last resort (never silently 'Food &
  ///    Groceries' unless the user truly has no other expenses).
  Future<Category> resolveLoanPaymentCategory(String? loanCategory) async {
    final categories = await getAllCategories();

    final requested = loanCategory?.trim().toLowerCase();
    if (requested != null && requested.isNotEmpty) {
      final exactMatch = categories.where(
        (c) => c.name.trim().toLowerCase() == requested,
      );
      if (exactMatch.isNotEmpty) return exactMatch.first;
    }

    final loanPaymentCat = categories.where(
      (c) =>
          c.name.trim().toLowerCase() == loanPaymentCategoryName.toLowerCase(),
    );
    if (loanPaymentCat.isNotEmpty) return loanPaymentCat.first;

    final created = Category(
      id: const Uuid().v4(),
      name: loanPaymentCategoryName,
      icon: 'credit-card',
      color: '#5E35B1',
      type: 'expense',
      isSystem: true,
      sortOrder: 90,
      createdAt: DateTime.now(),
    );
    await createCategory(created);
    return created;
  }

  Future<bool> updateCategory(Category category) =>
      _categoryDao.updateCategory(category);

  Future<int> deleteCategory(String id) => _categoryDao.deleteCategory(id);
}
