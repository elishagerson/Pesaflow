import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';

class CsvParseResult {
  final List<Transaction> transactions;
  final List<String> errors;
  final int skippedRows;

  const CsvParseResult({
    required this.transactions,
    required this.errors,
    required this.skippedRows,
  });
}

class CsvParser {
  static const _uuid = Uuid();
  static final _dateFormats = [
    DateFormat('yyyy-MM-dd HH:mm:ss'),
    DateFormat('yyyy-MM-dd HH:mm'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd/MM/yyyy HH:mm:ss'),
    DateFormat('dd/MM/yyyy HH:mm'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('MM/dd/yyyy HH:mm:ss'),
    DateFormat('MM/dd/yyyy HH:mm'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('yyyy/MM/dd HH:mm:ss'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('dd MMM yyyy'),
    DateFormat('dd MMMM yyyy'),
  ];

  static CsvParseResult parse(
    String csvContent, {
    String? accountId,
    String? defaultCategoryId,
  }) {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const CsvParseResult(
        transactions: [],
        errors: ['File is empty'],
        skippedRows: 0,
      );
    }

    final delimiter = _detectDelimiter(lines.first);
    final headerFields = _splitCsvLine(lines.first, delimiter);
    final headerIndex = _mapHeaders(headerFields);

    if (headerIndex == null) {
      return CsvParseResult(
        transactions: [],
        errors: ['Unrecognized CSV headers. Found: ${headerFields.join(", ")}'],
        skippedRows: 0,
      );
    }

    final isPesaFlow = headerIndex.containsKey('pesaflow_id');
    final transactions = <Transaction>[];
    final errors = <String>[];
    var skipped = 0;

    for (var i = 1; i < lines.length; i++) {
      final fields = _splitCsvLine(lines[i], delimiter);
      if (fields.isEmpty || (fields.length == 1 && fields[0].trim().isEmpty)) {
        skipped++;
        continue;
      }

      try {
        final tx = _parseRow(
          fields,
          headerIndex,
          isPesaFlow,
          accountId: accountId,
          defaultCategoryId: defaultCategoryId,
        );
        if (tx != null) {
          transactions.add(tx);
        } else {
          skipped++;
        }
      } catch (e) {
        errors.add('Row ${i + 1}: $e');
      }
    }

    return CsvParseResult(
      transactions: transactions,
      errors: errors,
      skippedRows: skipped,
    );
  }

  static String _detectDelimiter(String headerLine) {
    final semicolons = ';'.allMatches(headerLine).length;
    final commas = ','.allMatches(headerLine).length;
    return semicolons > commas ? ';' : ',';
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    final fields = <String>[];
    final current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          current.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == delimiter) {
          fields.add(current.toString().trim());
          current.clear();
        } else {
          current.write(ch);
        }
      }
    }
    fields.add(current.toString().trim());
    return fields;
  }

  static Map<String, int>? _mapHeaders(List<String> headers) {
    final lower = headers.map((h) => h.toLowerCase().trim()).toList();

    // PesaFlow export headers
    if (lower.contains('transaction id') && lower.contains('amount (tzs)')) {
      final map = <String, int>{};
      for (var i = 0; i < lower.length; i++) {
        final h = lower[i];
        if (h == 'transaction id') map['pesaflow_id'] = i;
        if (h == 'date') map['date'] = i;
        if (h == 'type') map['type'] = i;
        if (h == 'account') map['account'] = i;
        if (h == 'category') map['category'] = i;
        if (h == 'description') map['description'] = i;
        if (h == 'amount (tzs)') map['amount'] = i;
        if (h == 'reference') map['reference'] = i;
        if (h == 'sender') map['sender'] = i;
        if (h == 'recipient') map['recipient'] = i;
        if (h == 'source') map['source'] = i;
      }
      return map;
    }

    // Generic format: look for date + amount + description
    final dateIdx = _findColumn(lower, [
      'date',
      'transaction date',
      'txn date',
      'posting date',
    ]);
    final amountIdx = _findColumn(lower, [
      'amount',
      'value',
      'txn amount',
      'transaction amount',
      'money',
    ]);
    final descIdx = _findColumn(lower, [
      'description',
      'details',
      'narrative',
      'remarks',
      'transaction details',
      'particulars',
    ]);

    if (dateIdx == null || amountIdx == null) {
      return null;
    }

    final map = <String, int>{'date': dateIdx, 'amount': amountIdx};

    if (descIdx != null) map['description'] = descIdx;

    final typeIdx = _findColumn(lower, [
      'type',
      'transaction type',
      'txn type',
      'debit/credit',
      'd/c',
    ]);
    if (typeIdx != null) map['type'] = typeIdx;

    final refIdx = _findColumn(lower, [
      'reference',
      'ref',
      'transaction ref',
      'txn ref',
    ]);
    if (refIdx != null) map['reference'] = refIdx;

    final senderIdx = _findColumn(lower, [
      'sender',
      'from',
      'payee',
      'beneficiary',
    ]);
    if (senderIdx != null) map['sender'] = senderIdx;

    final recipientIdx = _findColumn(lower, [
      'recipient',
      'to',
      'payer',
      'remitter',
    ]);
    if (recipientIdx != null) map['recipient'] = recipientIdx;

    return map;
  }

  static int? _findColumn(List<String> lowerHeaders, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = lowerHeaders.indexOf(candidate);
      if (idx != -1) return idx;
    }
    return null;
  }

  static Transaction? _parseRow(
    List<String> fields,
    Map<String, int> headerIndex,
    bool isPesaFlow, {
    String? accountId,
    String? defaultCategoryId,
  }) {
    if (isPesaFlow) {
      return _parsePesaFlowRow(fields, headerIndex, accountId: accountId);
    }
    return _parseGenericRow(
      fields,
      headerIndex,
      accountId: accountId,
      defaultCategoryId: defaultCategoryId,
    );
  }

  static Transaction? _parsePesaFlowRow(
    List<String> fields,
    Map<String, int> headerIndex, {
    String? accountId,
  }) {
    final id = _field(fields, headerIndex['pesaflow_id']);
    final dateStr = _field(fields, headerIndex['date']);
    final typeStr = _field(fields, headerIndex['type']).toLowerCase();
    final desc = _field(fields, headerIndex['description']);
    final amountStr = _field(fields, headerIndex['amount']);

    if (dateStr.isEmpty) throw FormatException('Missing date');
    if (amountStr.isEmpty) throw FormatException('Missing amount');

    final date = _parseDate(dateStr);
    if (date == null) throw FormatException('Invalid date: $dateStr');

    final amount = _parseAmount(amountStr);
    final reference = _field(fields, headerIndex['reference']);
    final sender = _field(fields, headerIndex['sender']);
    final recipient = _field(fields, headerIndex['recipient']);

    return Transaction(
      id: id.isNotEmpty ? id : _uuid.v4(),
      accountId: accountId,
      categoryId: '', // Will be resolved by caller
      amount: amount,
      type: _normalizeType(typeStr),
      description: desc.isNotEmpty ? desc : 'Imported transaction',
      reference: reference.isNotEmpty ? reference : null,
      sender: sender.isNotEmpty ? sender : null,
      recipient: recipient.isNotEmpty ? recipient : null,
      source: 'csv_import',
      createdAt: date,
      updatedAt: date,
    );
  }

  static Transaction? _parseGenericRow(
    List<String> fields,
    Map<String, int> headerIndex, {
    String? accountId,
    String? defaultCategoryId,
  }) {
    final dateStr = _field(fields, headerIndex['date']);
    final amountStr = _field(fields, headerIndex['amount']);
    final desc = headerIndex['description'] != null
        ? _field(fields, headerIndex['description'])
        : '';

    if (dateStr.isEmpty) throw FormatException('Missing date');
    if (amountStr.isEmpty) throw FormatException('Missing amount');

    final date = _parseDate(dateStr);
    if (date == null) throw FormatException('Invalid date: $dateStr');

    final parsedAmount = _parseAmountWithSign(amountStr);
    final type = headerIndex['type'] != null
        ? _normalizeType(_field(fields, headerIndex['type']).toLowerCase())
        : _inferType(parsedAmount.$1);

    final reference = headerIndex['reference'] != null
        ? _field(fields, headerIndex['reference'])
        : null;
    final sender = headerIndex['sender'] != null
        ? _field(fields, headerIndex['sender'])
        : null;
    final recipient = headerIndex['recipient'] != null
        ? _field(fields, headerIndex['recipient'])
        : null;

    return Transaction(
      id: _uuid.v4(),
      accountId: accountId,
      categoryId: defaultCategoryId ?? '',
      amount: parsedAmount.$2,
      type: type,
      description: desc.isNotEmpty ? desc : 'Imported transaction',
      reference: reference?.isNotEmpty == true ? reference : null,
      sender: sender?.isNotEmpty == true ? sender : null,
      recipient: recipient?.isNotEmpty == true ? recipient : null,
      source: 'csv_import',
      createdAt: date,
      updatedAt: date,
    );
  }

  static DateTime? _parseDate(String value) {
    for (final fmt in _dateFormats) {
      try {
        return fmt.parseStrict(value);
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static int _parseAmount(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[Tt]sh\.?'), '')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return 0;
    final amount = double.tryParse(cleaned) ?? 0;
    return (amount * 100).round().abs();
  }

  /// Returns (sign, absolute amount in cents).
  /// Positive = income, negative = expense.
  static (String, int) _parseAmountWithSign(String value) {
    final trimmed = value.trim();
    final isNegative =
        trimmed.startsWith('-') ||
        trimmed.startsWith('(') ||
        trimmed.toLowerCase().contains('dr');
    final cleaned = trimmed
        .replaceAll(RegExp(r'[Tt]sh\.?'), '')
        .replaceAll(RegExp(r'[()-]'), '')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return ('expense', 0);
    final amount = double.tryParse(cleaned) ?? 0;
    final cents = (amount * 100).round().abs();
    return (isNegative ? 'expense' : 'income', cents);
  }

  static String _normalizeType(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'income' ||
        lower == 'credit' ||
        lower == 'c' ||
        lower == 'deposit' ||
        lower == 'received') {
      return 'income';
    }
    if (lower == 'expense' ||
        lower == 'debit' ||
        lower == 'd' ||
        lower == 'payment' ||
        lower == 'withdrawal' ||
        lower == 'sent') {
      return 'expense';
    }
    if (lower == 'transfer') return 'transfer';
    if (lower == 'airtime') return 'airtime';
    if (lower == 'fee' || lower == 'charge') return 'fee';
    return 'expense';
  }

  static String _inferType(String sign) {
    return sign == 'income' ? 'income' : 'expense';
  }

  static String _field(List<String> fields, int? index) {
    if (index == null || index >= fields.length) return '';
    return fields[index].trim();
  }
}
