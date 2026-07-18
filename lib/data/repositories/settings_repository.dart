import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/daos/settings_dao.dart';
import '../database/database_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final settingsDao = ref.watch(settingsDaoProvider);
  return SettingsRepository(settingsDao);
});

class SettingsRepository {
  final SettingsDao _settingsDao;

  SettingsRepository(this._settingsDao);

  Future<bool> isOnboardingComplete() async {
    final value = await _settingsDao.getSetting('onboarding_complete');
    return value == 'true';
  }

  Future<void> markOnboardingComplete() async {
    await _settingsDao.setSetting('onboarding_complete', 'true');
  }

  Future<String> getThemeMode() async {
    return await _settingsDao.getSetting('theme') ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    await _settingsDao.setSetting('theme', mode);
  }

  Stream<String?> watchSetting(String key) => _settingsDao.watchSetting(key);

  Future<String?> getSetting(String key) => _settingsDao.getSetting(key);

  Future<void> setSetting(String key, String value) =>
      _settingsDao.setSetting(key, value);

  Future<List<Map<String, dynamic>>> getTransactionTemplates() async {
    final json = await getSetting('transaction_templates');
    if (json == null) return [];
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveTransactionTemplate(Map<String, dynamic> template) async {
    final templates = await getTransactionTemplates();
    templates.add(template);
    await setSetting('transaction_templates', jsonEncode(templates));
  }

  Future<void> deleteTransactionTemplate(String id) async {
    final templates = await getTransactionTemplates();
    templates.removeWhere((t) => t['id'] == id);
    await setSetting('transaction_templates', jsonEncode(templates));
  }

  Future<String?> getLastAccountId() async {
    return await getSetting('last_account_id');
  }

  Future<void> setLastAccountId(String id) async {
    await setSetting('last_account_id', id);
  }

  Future<String?> getLastCategoryId(String type) async {
    final key = 'last_category_id_$type';
    return await getSetting(key);
  }

  Future<void> setLastCategoryId(String type, String id) async {
    final key = 'last_category_id_$type';
    await setSetting(key, id);
  }
}
