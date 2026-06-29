import 'package:intl/intl.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

class CsvHelper {
  /// Converts a list of TransactionWithCategoryAndAccount objects to a valid CSV string.
  static String convertToCsv(List<TransactionWithCategoryAndAccount> items) {
    final headers = [
      'Transaction ID',
      'Date',
      'Type',
      'Account',
      'Category',
      'Description',
      'Amount (TZS)',
      'Reference',
      'Sender',
      'Recipient',
      'Source',
    ];

    final buffer = StringBuffer();

    // Write CSV Headers
    buffer.writeln(headers.map(_escapeField).join(','));

    // Write Row Data
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final item in items) {
      final trans = item.transaction;
      final amountFormatted = (trans.amount / 100.0).toStringAsFixed(2);

      final row = [
        trans.id,
        dateFormat.format(trans.createdAt),
        trans.type.toUpperCase(),
        item.account?.name ?? 'Offline',
        item.category.name,
        trans.description,
        amountFormatted,
        trans.reference ?? '',
        trans.sender ?? '',
        trans.recipient ?? '',
        trans.source,
      ];

      buffer.writeln(row.map(_escapeField).join(','));
    }

    return buffer.toString();
  }

  static String _escapeField(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
