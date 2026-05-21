import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/app_settings_table.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Gets the value for a setting key. Returns null if not found.
  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Sets a setting value, inserting or updating as needed.
  Future<void> setSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(AppSetting(
      key: key,
      value: value,
      updatedAt: DateTime.now(),
    ));
  }

  /// Streams a setting value reactively.
  Stream<String?> watchSetting(String key) {
    return (select(appSettings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }
}
