import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pesaflow/core/utils/csv_helper.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/data/repositories/analytics_repository.dart';
import 'package:pesaflow/domain/export/pdf_report_generator.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

enum ExportFormat { csv, pdf }

Future<void> showExportDialog(BuildContext context, WidgetRef ref) async {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  ExportFormat format = ExportFormat.pdf;

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final months = [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December',
          ];

          return AlertDialog(
            title: const Text('Export Monthly Statement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Month picker
                DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(months[i]),
                  )),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedMonth = val);
                  },
                ),
                const SizedBox(height: 16),
                // Year picker
                DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    prefixIcon: Icon(Icons.date_range_rounded),
                  ),
                  items: List.generate(10, (i) {
                    final year = DateTime.now().year - 5 + i;
                    return DropdownMenuItem(value: year, child: Text('$year'));
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedYear = val);
                  },
                ),
                const SizedBox(height: 16),
                // Format selector
                DropdownButtonFormField<ExportFormat>(
                  initialValue: format,
                  decoration: const InputDecoration(
                    labelText: 'Format',
                    prefixIcon: Icon(Icons.description_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: ExportFormat.pdf, child: Text('PDF')),
                    DropdownMenuItem(value: ExportFormat.csv, child: Text('CSV')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => format = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_download_rounded, size: 18),
                label: const Text('Export'),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _generateAndShare(context, ref, selectedYear, selectedMonth, format);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _generateAndShare(
  BuildContext context,
  WidgetRef ref,
  int year,
  int month,
  ExportFormat format,
) async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating export...')),
    );

    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);
    final repo = ref.read(transactionRepositoryProvider);

    final transactions = await repo
        .watchFilteredTransactions(startDate: monthStart, endDate: monthEnd)
        .first;

    final accounts = ref.read(accountsStreamProvider).value ?? [];

    final analyticsRepo = ref.read(analyticsRepositoryProvider);
    final totals = await analyticsRepo.getMonthTotals(monthStart);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final monthName = DateFormat('MMM_yyyy').format(monthStart);
    String filePath;
    String subject;
    String text;

    if (format == ExportFormat.csv) {
      final csvString = CsvHelper.convertToCsv(transactions);
      filePath = p.join(tempDir.path, 'pesaflow_${monthName}_$timestamp.csv');
      await File(filePath).writeAsString(csvString);
      subject = 'PesaFlow CSV Export - $monthName';
      text = 'Transaction data exported from PesaFlow.';
    } else {
      final pdfBytes = await generateMonthlyPdf(year, month, transactions, accounts, totals);
      filePath = p.join(tempDir.path, 'pesaflow_${monthName}_$timestamp.pdf');
      await File(filePath).writeAsBytes(pdfBytes);
      subject = 'PesaFlow Monthly Statement - $monthName';
      text = 'Monthly statement generated by PesaFlow.';
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: subject,
        text: text,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
