import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaletteVisibility extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void show() => state = true;
  void hide() => state = false;
}

final paletteVisibilityProvider = NotifierProvider<PaletteVisibility, bool>(
  PaletteVisibility.new,
);

class PaletteQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
  void clear() => state = '';
}

final paletteQueryProvider = NotifierProvider<PaletteQuery, String>(
  PaletteQuery.new,
);
