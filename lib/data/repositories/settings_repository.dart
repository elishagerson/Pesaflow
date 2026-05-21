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

  Future<void> setSetting(String key, String value) => _settingsDao.setSetting(key, value);
}
