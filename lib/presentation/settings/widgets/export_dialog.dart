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
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/core/utils/spacing.dart';

enum ExportFormat { csv, pdf }

enum _DateMode { monthly, customRange }

Future<void> showExportDialog(BuildContext context, WidgetRef ref) async {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  ExportFormat format = ExportFormat.pdf;
  _DateMode dateMode = _DateMode.monthly;
  DateTime rangeStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime rangeEnd = DateTime.now();

  InputDecoration buildDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> pickDate({
    required bool isStart,
    required StateSetter setState,
  }) async {
    final now = DateTime.now();
    final initial = isStart ? rangeStart : rangeEnd;
    final firstDate = DateTime(now.year - 10);
    final lastDate = now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          rangeStart = DateTime(picked.year, picked.month, picked.day);
          if (rangeStart.isAfter(rangeEnd)) {
            rangeEnd = DateTime(
              rangeStart.year,
              rangeStart.month,
              rangeStart.day,
              23,
              59,
              59,
            );
          }
        } else {
          rangeEnd = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
          );
          if (rangeEnd.isBefore(rangeStart)) {
            rangeStart = DateTime(picked.year, picked.month, picked.day);
          }
        }
      });
    }
  }

  final dateFormat = DateFormat('MMM d, yyyy');

  await ModernDialog.show(
    context: context,
    titleIcon: PesaFlowIcons.download,
    iconColor: Theme.of(context).colorScheme.primary,
    title: const Text('Export Statement'),
    content: StatefulBuilder(
      builder: (ctx, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: kSpacing4),
            SegmentedButton<_DateMode>(
              segments: const [
                ButtonSegment(
                  value: _DateMode.monthly,
                  label: Text('Monthly'),
                  icon: Icon(PesaFlowIcons.calendar, size: 18),
                ),
                ButtonSegment(
                  value: _DateMode.customRange,
                  label: Text('Custom Range'),
                  icon: Icon(PesaFlowIcons.dateRange, size: 18),
                ),
              ],
              selected: {dateMode},
              onSelectionChanged: (sel) {
                setState(() => dateMode = sel.first);
              },
            ),
            const SizedBox(height: kSpacing12),
            if (dateMode == _DateMode.monthly) ...[
              DropdownButtonFormField<int>(
                initialValue: selectedMonth,
                decoration: buildDecoration('Month', PesaFlowIcons.calendar),
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(
                      DateFormat('MMMM').format(DateTime(2000, i + 1)),
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (val != null) setState(() => selectedMonth = val);
                },
              ),
              const SizedBox(height: kSpacing12),
              DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: buildDecoration('Year', PesaFlowIcons.dateRange),
                items: List.generate(10, (i) {
                  final year = DateTime.now().year - 5 + i;
                  return DropdownMenuItem(value: year, child: Text('$year'));
                }),
                onChanged: (val) {
                  if (val != null) setState(() => selectedYear = val);
                },
              ),
            ] else ...[
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => pickDate(isStart: true, setState: setState),
                child: InputDecorator(
                  decoration: buildDecoration(
                    'From',
                    PesaFlowIcons.calendarToday,
                  ),
                  child: Text(dateFormat.format(rangeStart)),
                ),
              ),
              const SizedBox(height: kSpacing12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => pickDate(isStart: false, setState: setState),
                child: InputDecorator(
                  decoration: buildDecoration(
                    'To',
                    PesaFlowIcons.calendarToday,
                  ),
                  child: Text(dateFormat.format(rangeEnd)),
                ),
              ),
            ],
            const SizedBox(height: kSpacing12),
            DropdownButtonFormField<ExportFormat>(
              initialValue: format,
              decoration: buildDecoration('Format', PesaFlowIcons.description),
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
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing20,
            vertical: kSpacing12,
          ),
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      ElevatedButton.icon(
        icon: const Icon(PesaFlowIcons.download, size: 18),
        label: const Text('Export'),
        onPressed: () async {
          Navigator.of(context).pop();
          final isMonthly = dateMode == _DateMode.monthly;
          await _generateAndShare(
            context,
            ref,
            year: isMonthly ? selectedYear : null,
            month: isMonthly ? selectedMonth : null,
            startDate: isMonthly ? null : rangeStart,
            endDate: isMonthly ? null : rangeEnd,
            format: format,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing24,
            vertical: kSpacing12,
          ),
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
  WidgetRef ref, {
  int? year,
  int? month,
  DateTime? startDate,
  DateTime? endDate,
  required ExportFormat format,
}) async {
  try {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating export...')));

    final bool isMonthly = year != null && month != null;
    final DateTime dateStart;
    final DateTime dateEnd;
    if (isMonthly) {
      dateStart = DateTime(year, month, 1);
      dateEnd = DateTime(year, month + 1, 0, 23, 59, 59);
    } else {
      dateStart = DateTime(startDate!.year, startDate.month, startDate.day);
      dateEnd = DateTime(endDate!.year, endDate.month, endDate.day, 23, 59, 59);
    }

    final repo = ref.read(transactionRepositoryProvider);

    final transactions = await repo
        .watchFilteredTransactions(startDate: dateStart, endDate: dateEnd)
        .firstWhere((_) => true, orElse: () => []);

    final accounts = ref.read(accountsStreamProvider).value ?? [];

    final analyticsRepo = ref.read(analyticsRepositoryProvider);
    final totals = await analyticsRepo.getDateRangeTotals(dateStart, dateEnd);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dateLabel = isMonthly
        ? DateFormat('MMM_yyyy').format(dateStart)
        : '${DateFormat('yyyyMMdd').format(dateStart)}_${DateFormat('yyyyMMdd').format(dateEnd)}';
    String filePath;
    String subject;
    String text;

    if (format == ExportFormat.csv) {
      final csvString = CsvHelper.convertToCsv(transactions);
      filePath = p.join(tempDir.path, 'pesaflow_${dateLabel}_$timestamp.csv');
      await File(filePath).writeAsString(csvString);
      subject = 'PesaFlow CSV Export - $dateLabel';
      text = 'Transaction data exported from PesaFlow.';
    } else {
      final title = isMonthly
          ? 'Monthly Statement - ${DateFormat('MMMM yyyy').format(dateStart)}'
          : 'Statement - ${DateFormat('MMM d, yyyy').format(dateStart)} to ${DateFormat('MMM d, yyyy').format(dateEnd)}';
      final pdfBytes = await generateRangePdf(
        title: title,
        startDate: dateStart,
        endDate: dateEnd,
        transactions: transactions,
        accounts: accounts,
        totals: totals,
      );
      filePath = p.join(tempDir.path, 'pesaflow_${dateLabel}_$timestamp.pdf');
      await File(filePath).writeAsBytes(pdfBytes);
      subject = 'PesaFlow Statement - $dateLabel';
      text = 'Statement generated by PesaFlow.';
    }

    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], subject: subject, text: text),
    );
  } catch (e) {
    if (context.mounted) {
      CustomToast.show(
        context,
        message: 'Export failed: $e',
        type: ToastType.error,
      );
    }
  }
}
