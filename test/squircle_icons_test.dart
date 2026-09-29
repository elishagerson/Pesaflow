import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';

const _roundAllowed = <String>{
  'lib/presentation/common/widgets/premium_fab.dart',
  'lib/presentation/common/widgets/modern_numpad.dart',
  'lib/presentation/common/widgets/amount_slider.dart',
  'lib/presentation/dashboard/widgets/monthly_overview_section.dart',
  'lib/presentation/transactions/transaction_detail_screen.dart',
};

void main() {
  group('icon badges are squircles', () {
    test('nothing draws a circular badge outside the round keep list', () {
      final violations = <String>[];
      final files =
          Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final circularShape = RegExp(r'shape:\s*BoxShape\.circle');
      final circularAvatar = RegExp(r'\b(CircleAvatar|CircleBorder)\s*\(');
      for (final file in files) {
        final source = file.readAsStringSync();
        for (final match in circularShape.allMatches(source)) {
          if (_roundAllowed.contains(file.path)) continue;
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          violations.add('${file.path}:$line');
        }
        for (final match in circularAvatar.allMatches(source)) {
          if (_roundAllowed.contains(file.path)) continue;
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          violations.add('${file.path}:$line (${match.group(1)})');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Convert these circular containers to '
            'BorderRadius.circular(AppTheme.squircleRadius(side)): '
            '${violations.join(', ')}',
      );
    });

    test('squircleRadius never reaches half the side, so never a circle', () {
      for (final side in <double>[6, 8, 14, 22, 28, 36, 40, 56, 80, 120]) {
        final radius = AppTheme.squircleRadius(side);
        expect(radius, greaterThanOrEqualTo(1.0), reason: 'side $side');
        expect(
          radius,
          lessThan(side / 2),
          reason: 'side $side must stay a squircle, not a circle',
        );
      }
      expect(AppTheme.squircleRadius(40), closeTo(11.2, 0.0001));
      expect(AppTheme.squircleRadius(500), AppTheme.radiusButton);
    });
  });
}
