import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
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
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';

enum ExportFormat { csv, pdf }

Future<void> showExportDialog(BuildContext context, WidgetRef ref) async {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  ExportFormat format = ExportFormat.pdf;

  await ModernDialog.show(
    context: context,
    titleIcon: Icons.file_download_rounded,
    iconColor: const Color(0xFF0F4C5C),
    title: const Text('Export Monthly Statement'),
    content: StatefulBuilder(
      builder: (ctx, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: selectedMonth,
              decoration: InputDecoration(
                labelText: 'Month',
                prefixIcon: const Icon(PesaFlowIcons.calendar, size: 20),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(DateFormat('MMMM').format(DateTime(2000, i + 1))),
                ),
              ),
              onChanged: (val) {
                if (val != null) setState(() => selectedMonth = val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: selectedYear,
              decoration: InputDecoration(
                labelText: 'Year',
                prefixIcon: const Icon(Icons.date_range_rounded, size: 20),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: List.generate(10, (i) {
                final year = DateTime.now().year - 5 + i;
                return DropdownMenuItem(value: year, child: Text('$year'));
              }),
              onChanged: (val) {
                if (val != null) setState(() => selectedYear = val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExportFormat>(
              initialValue: format,
              decoration: InputDecoration(
                labelText: 'Format',
                prefixIcon: const Icon(Icons.description_rounded, size: 20),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: ExportFormat.pdf,
                  child: Text('PDF - Professional report'),
                ),
                DropdownMenuItem(
                  value: ExportFormat.csv,
                  child: Text('CSV - Spreadsheet data'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => format = val);
              },
            ),
          ],
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey[600],
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      ElevatedButton.icon(
        icon: const Icon(Icons.file_download_rounded, size: 18),
        label: const Text('Export'),
        onPressed: () async {
          Navigator.of(context).pop();
          await _generateAndShare(
            context,
            ref,
            selectedYear,
            selectedMonth,
            format,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F4C5C),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ],
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating export...')));

    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);
    final repo = ref.read(transactionRepositoryProvider);

    final transactions = await repo
        .watchFilteredTransactions(startDate: monthStart, endDate: monthEnd)
        .firstWhere((_) => true, orElse: () => []);

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
      final pdfBytes = await generateMonthlyPdf(
        year,
        month,
        transactions,
        accounts,
        totals,
      );
      filePath = p.join(tempDir.path, 'pesaflow_${monthName}_$timestamp.pdf');
      await File(filePath).writeAsBytes(pdfBytes);
      subject = 'PesaFlow Monthly Statement - $monthName';
      text = 'Monthly statement generated by PesaFlow.';
    }

    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], subject: subject, text: text),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
