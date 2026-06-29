import 'package:flutter_riverpod/flutter_riverpod.dart';

final paletteVisibilityProvider = StateProvider<bool>((ref) => false);

final paletteQueryProvider = StateProvider<String>((ref) => '');
