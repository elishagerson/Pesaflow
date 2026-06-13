import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

Future<Uint8List> generateMonthlyPdf(
  int year,
  int month,
  List<TransactionWithCategoryAndAccount> transactions,
  List<Account> accounts,
  Map<String, int> totals,
) async {
  final pdf = pw.Document();
  final monthName = DateFormat('MMMM').format(DateTime(year, month));
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final income = totals['income'] ?? 0;
  final expense = totals['expense'] ?? 0;
  final netSavings = income - expense;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'PesaFlow Monthly Statement - $monthName $year',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1A1A2E),
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Header(
          level: 1,
          child: pw.Text('Summary', style: pw.TextStyle(fontSize: 16)),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Income:     TSh ${(income / 100).toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFF2E7D32),
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Expense:    TSh ${(expense / 100).toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFFC62828),
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Net Savings: TSh ${(netSavings / 100).toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    color: netSavings >= 0
                        ? PdfColor.fromInt(0xFF2E7D32)
                        : PdfColor.fromInt(0xFFC62828),
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Header(
          level: 1,
          child: pw.Text('Account Balances', style: pw.TextStyle(fontSize: 16)),
        ),
        pw.SizedBox(height: 8),
        ...accounts.map((acc) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(
            '${acc.name}: TSh ${(acc.balance / 100).toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 11),
          ),
        )),
        pw.SizedBox(height: 20),
        pw.Header(
          level: 1,
          child: pw.Text('Transactions', style: pw.TextStyle(fontSize: 16)),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1A1A2E),
          ),
          cellStyle: pw.TextStyle(fontSize: 9),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerRight,
          },
          headers: ['Date', 'Description', 'Category', 'Amount'],
          data: transactions.map((t) {
            final trans = t.transaction;
            final prefix = trans.type == 'income' ? '+' : '-';
            return [
              dateFormat.format(trans.createdAt),
              trans.description.isNotEmpty ? trans.description : t.category.name,
              t.category.name,
              '$prefix TSh ${(trans.amount / 100).toStringAsFixed(2)}',
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Header(
          level: 1,
          child: pw.Text('Notes', style: pw.TextStyle(fontSize: 16)),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'This statement was generated automatically by PesaFlow. '
          'All amounts are in Tanzanian Shillings (TSh).',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
        ),
      ],
    ),
  );

  return pdf.save();
}
