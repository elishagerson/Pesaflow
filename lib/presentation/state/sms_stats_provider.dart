import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:pesaflow/data/database/database_providers.dart';

final _smsTableRefreshProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .tableUpdates(TableUpdateQuery.onTable(db.transactions))
      .map((_) => DateTime.now().microsecondsSinceEpoch);
});

final todaySmsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(_smsTableRefreshProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final rows =
      await (db.select(db.transactions)
            ..where((t) => t.createdAt.isBiggerOrEqual(Constant(startOfDay)))
            ..where((t) => t.createdAt.isSmallerOrEqual(Constant(endOfDay))))
          .get();

  return rows.where((t) => t.source.startsWith('sms')).length;
});
