import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/utils/settings_keys.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';

class ActiveTrackerIdNotifier extends Notifier<String> {
  late final SettingsRepository _settingsRepo;

  @override
  String build() {
    _settingsRepo = ref.watch(settingsRepositoryProvider);
    Future.microtask(_init);
    return 'default_personal';
  }

  Future<void> _init() async {
    final saved = await _settingsRepo.getSetting(SettingsKey.activeTrackerId);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setTrackerId(String id) async {
    state = id;
    await _settingsRepo.setSetting(SettingsKey.activeTrackerId, id);
  }
}

final activeTrackerIdProvider = NotifierProvider<ActiveTrackerIdNotifier, String>(() {
  return ActiveTrackerIdNotifier();
});
