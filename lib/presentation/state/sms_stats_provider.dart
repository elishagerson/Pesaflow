import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:pesaflow/data/database/database_providers.dart';

final todaySmsCountProvider = FutureProvider<int>((ref) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final transactions = await (db.select(db.transactions)
    ..where((t) => t.createdAt.isBiggerOrEqual(Constant(startOfDay)))
    ..where((t) => t.createdAt.isSmallerOrEqual(Constant(endOfDay)))
  ).get();

  return transactions.where((t) => t.source.startsWith('sms')).length;
});
