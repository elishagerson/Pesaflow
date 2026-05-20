import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/category_dao.dart';
import '../database/database_providers.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final dao = ref.watch(categoryDaoProvider);
  return CategoryRepository(dao);
});

class CategoryRepository {
  final CategoryDao _categoryDao;

  CategoryRepository(this._categoryDao);

  Stream<List<Category>> watchAllCategories() => _categoryDao.watchAllCategories();

  Future<List<Category>> getAllCategories() => _categoryDao.getAllCategories();

  /// Alias used by the auto-categorizer engine.
  Future<List<Category>> getCategories() => getAllCategories();

  Future<List<Category>> getCategoriesByType(String type) => _categoryDao.getCategoriesByType(type);

  Future<Category?> getCategoryById(String id) => _categoryDao.getCategoryById(id);

  Future<int> createCategory(Category category) => _categoryDao.insertCategory(category);

  Future<bool> updateCategory(Category category) => _categoryDao.updateCategory(category);

  Future<int> deleteCategory(String id) => _categoryDao.deleteCategory(id);
}
