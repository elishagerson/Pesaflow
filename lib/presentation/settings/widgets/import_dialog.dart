import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/csv_parser.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/data/database/app_database.dart';

class CsvImportResult {
  final List<Transaction> transactions;
  final String? accountId;
  final String defaultCategoryId;

  const CsvImportResult({
    required this.transactions,
    this.accountId,
    required this.defaultCategoryId,
  });
}

Future<CsvImportResult?> showImportCsvDialog(
  BuildContext context, {
  required List<Account> accounts,
  required List<Category> categories,
}) {
  return showModalBottomSheet<CsvImportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ImportCsvSheet(accounts: accounts, categories: categories),
  );
}

class _ImportCsvSheet extends StatefulWidget {
  final List<Account> accounts;
  final List<Category> categories;

  const _ImportCsvSheet({required this.accounts, required this.categories});

  @override
  State<_ImportCsvSheet> createState() => _ImportCsvSheetState();
}

enum _Stage { pickFile, preview, done }

class _ImportCsvSheetState extends State<_ImportCsvSheet> {
  _Stage _stage = _Stage.pickFile;
  CsvParseResult? _parseResult;
  String? _fileName;
  String? _error;
  String? _selectedAccountId;
  String? _defaultCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _defaultCategoryId = widget.categories.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: kSpacing12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(kSpacing20),
            child: Row(
              children: [
                Icon(PesaFlowIcons.file, color: theme.colorScheme.primary),
                const SizedBox(width: kSpacing8),
                Text(
                  'Import CSV',
                  style: context.ts(20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kSpacing20),
              child: switch (_stage) {
                _Stage.pickFile => _buildFilePicker(theme),
                _Stage.preview => _buildPreview(theme),
                _Stage.done => _buildDone(theme),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePicker(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(kSpacing32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  PesaFlowIcons.file,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: kSpacing12),
                Text(
                  'Select CSV File',
                  style: context.ts(16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: kSpacing4),
                Text(
                  'Supports PesaFlow exports, M-Pesa,\nand bank statement CSVs',
                  textAlign: TextAlign.center,
                  style: context.ts(12, color: context.appColors.textMedium),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: kSpacing12),
          Container(
            padding: const EdgeInsets.all(kSpacing12),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: kSpacing8),
                Expanded(
                  child: Text(
                    _error!,
                    style: context.ts(12, color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final result = _parseResult!;
    final previewCount = result.transactions.length.clamp(0, 5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(kSpacing12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(PesaFlowIcons.file, color: theme.colorScheme.primary),
              const SizedBox(width: kSpacing8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName ?? 'CSV File',
                      style: context.ts(14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${result.transactions.length} transactions found'
                      '${result.skippedRows > 0 ? ' (${result.skippedRows} skipped)' : ''}',
                      style: context.ts(
                        12,
                        color: context.appColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: kSpacing8),
          Container(
            padding: const EdgeInsets.all(kSpacing10),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.errors.length} parse error(s):',
                  style: context.ts(
                    12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: kSpacing4),
                ...result.errors.take(3).map(
                  (e) => Text(
                    e,
                    style: context.ts(12, color: theme.colorScheme.error),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (result.errors.length > 3)
                  Text(
                    '...and ${result.errors.length - 3} more',
                    style: context.ts(12, color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
        ],

        if (result.transactions.isEmpty) ...[
          const SizedBox(height: kSpacing12),
          Center(
            child: Text(
              'No valid transactions found in this file.',
              style: context.ts(14, color: context.appColors.textMedium),
            ),
          ),
          const SizedBox(height: kSpacing12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _stage = _Stage.pickFile;
                _parseResult = null;
                _error = null;
              }),
              child: const Text('Try Another File'),
            ),
          ),
        ],

        // Account selector
        if (widget.accounts.isNotEmpty && result.transactions.isNotEmpty) ...[
          const SizedBox(height: kSpacing16),
          DropdownButtonFormField<String>(
            value: _selectedAccountId,
            decoration: InputDecoration(
              labelText: 'Assign to Account',
              prefixIcon: const Icon(PesaFlowIcons.wallet, size: 20),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('No account (offline)'),
              ),
              ...widget.accounts.map(
                (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
              ),
            ],
            onChanged: (id) => setState(() => _selectedAccountId = id),
          ),
        ],

        // Default category selector
        if (widget.categories.isNotEmpty && result.transactions.isNotEmpty) ...[
          const SizedBox(height: kSpacing12),
          DropdownButtonFormField<String>(
            value: _defaultCategoryId,
            decoration: InputDecoration(
              labelText: 'Default Category',
              prefixIcon: const Icon(Icons.category_rounded, size: 20),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: widget.categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (id) {
              if (id != null) setState(() => _defaultCategoryId = id);
            },
          ),
        ],

        // Preview rows
        if (previewCount > 0) ...[
          const SizedBox(height: kSpacing16),
          Text(
            'Preview (first $previewCount):',
            style: context.ts(12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: kSpacing8),
          ...List.generate(previewCount, (i) {
            final tx = result.transactions[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: kSpacing4),
              child: Container(
                padding: const EdgeInsets.all(kSpacing8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      tx.type == 'income'
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 16,
                      color: tx.type == 'income'
                          ? context.appColors.incomeColor
                          : context.appColors.expenseColor,
                    ),
                    const SizedBox(width: kSpacing8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description,
                            style: context.ts(12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            tx.createdAt.toString().substring(0, 10),
                            style: context.ts(
                              10,
                              color: context.appColors.textLow,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Tsh ${(tx.amount / 100).toStringAsFixed(0)}',
                      style: context.ts(12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        // Import button
        if (result.transactions.isNotEmpty) ...[
          const SizedBox(height: kSpacing16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.file_download_rounded, size: 18),
              label: Text(
                'Import ${result.transactions.length} Transactions',
              ),
              onPressed: _confirmImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: kSpacing12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDone(ThemeData theme) {
    final count = _parseResult?.transactions.length ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: kSpacing12),
        Icon(
          PesaFlowIcons.success,
          size: 48,
          color: context.appColors.incomeColor,
        ),
        const SizedBox(height: kSpacing12),
        Text(
          'Ready to Import',
          style: context.ts(18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: kSpacing4),
        Text(
          '$count transactions will be imported.',
          style: context.ts(14, color: context.appColors.textMedium),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

      final content = await File(result.files.single.path!).readAsString();
      final parseResult = CsvParser.parse(content);

      setState(() {
        _fileName = result.files.single.name;
        _parseResult = parseResult;
        _stage = _Stage.preview;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to read file: $e');
    }
  }

  void _confirmImport() {
    if (_parseResult == null || _parseResult!.transactions.isEmpty) return;

    // Resolve category IDs for all transactions
    final resolved = _parseResult!.transactions.map((tx) {
      final catId = tx.categoryId.isNotEmpty
          ? tx.categoryId
          : (_defaultCategoryId ?? '');
      if (catId == tx.categoryId && tx.accountId != null) return tx;
      return Transaction(
        id: tx.id,
        accountId: tx.accountId,
        categoryId: catId,
        amount: tx.amount,
        type: tx.type,
        description: tx.description,
        reference: tx.reference,
        sender: tx.sender,
        recipient: tx.recipient,
        source: tx.source,
        createdAt: tx.createdAt,
        updatedAt: tx.updatedAt,
      );
    }).toList();

    Navigator.of(context).pop(
      CsvImportResult(
        transactions: resolved,
        accountId: _selectedAccountId,
        defaultCategoryId: _defaultCategoryId ?? '',
      ),
    );
  }
}
