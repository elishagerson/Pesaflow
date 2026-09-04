import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<Category>> watchAllCategories() {
    return (select(
      categories,
    )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).watch();
  }

  Future<List<Category>> getAllCategories() {
    return (select(
      categories,
    )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
  }

  Future<List<Category>> getCategoriesByType(String type) {
    return (select(categories)
          ..where((t) => t.type.equals(type))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  Future<Category?> getCategoryById(String id) {
    return (select(
      categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCategory(Category category) =>
      into(categories).insert(category);

  Future<bool> updateCategory(Category category) =>
      update(categories).replace(category);

  Future<int> deleteCategory(String id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  Future<void> reassignAndDeleteCategory(
    String categoryId,
    String fallbackCategoryId,
  ) async {
    await attachedDatabase.transaction(() async {
      await (update(attachedDatabase.transactions)
            ..where((t) => t.categoryId.equals(categoryId)))
          .write(TransactionsCompanion(categoryId: Value(fallbackCategoryId)));
      await (delete(categories)..where((t) => t.id.equals(categoryId))).go();
    });
  }
}
