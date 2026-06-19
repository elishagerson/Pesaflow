import 'package:go_router/go_router.dart';

extension GoRouterStateParams on GoRouterState {
  /// Returns the required path parameter [key].
  /// Throws [ArgumentError] if the parameter is missing or empty.
  String param(String key) {
    final value = pathParameters[key];
    if (value == null || value.isEmpty) {
      throw ArgumentError('Missing required path parameter: $key');
    }
    return value;
  }

  /// Returns the optional path parameter [key], or null.
  String? optParam(String key) => pathParameters[key];
}
