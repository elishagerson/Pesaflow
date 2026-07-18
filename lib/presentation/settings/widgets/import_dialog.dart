import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/csv_parser.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';

Future<void> showImportCsvDialog(BuildContext context, WidgetRef ref) async {
  final theme = Theme.of(context);
  final accounts = ref.read(accountsStreamProvider).value ?? [];
  final categories =
      await ref.read(categoryRepositoryProvider).getAllCategories();
  String? selectedAccountId;
  String defaultCategoryId = categories.isNotEmpty ? categories.first.id : '';

  if (!context.mounted) return;

  await ModernDialog.show(
    context: context,
    titleIcon: PesaFlowIcons.file,
    iconColor: theme.colorScheme.primary,
    title: const Text('Import CSV'),
    content: StatefulBuilder(
      builder: (ctx, setState) {
        return _ImportCsvBody(
          accounts: accounts,
          categories: categories,
          selectedAccountId: selectedAccountId,
          defaultCategoryId: defaultCategoryId,
          onAccountChanged: (id) => setState(() => selectedAccountId = id),
          onCategoryChanged: (id) => setState(() => defaultCategoryId = id),
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _ImportCsvBody extends StatefulWidget {
  final List<Account> accounts;
  final List<Category> categories;
  final String? selectedAccountId;
  final String defaultCategoryId;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String> onCategoryChanged;

  const _ImportCsvBody({
    required this.accounts,
    required this.categories,
    required this.selectedAccountId,
    required this.defaultCategoryId,
    required this.onAccountChanged,
    required this.onCategoryChanged,
  });

  @override
  State<_ImportCsvBody> createState() => _ImportCsvBodyState();
}

class _ImportCsvBodyState extends State<_ImportCsvBody> {
  _ImportStage _stage = _ImportStage.pickFile;
  CsvParseResult? _parseResult;
  String? _fileName;
  bool _importing = false;
  int _importedCount = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (_stage) {
          _ImportStage.pickFile => _buildFilePicker(theme),
          _ImportStage.preview => _buildPreview(theme),
          _ImportStage.importing => _buildImporting(theme),
          _ImportStage.done => _buildDone(theme),
        },
      ],
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
        // File info
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
                      style: context.ts(12, color: context.appColors.textMedium),
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
                  style: context.ts(12, fontWeight: FontWeight.bold, color: theme.colorScheme.error),
                ),
                const SizedBox(height: kSpacing4),
                ...result.errors.take(3).map(
                      (e) => Text(
                        e,
                        style: context.ts(11, color: theme.colorScheme.error),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                if (result.errors.length > 3)
                  Text(
                    '...and ${result.errors.length - 3} more',
                    style: context.ts(11, color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
        ],

        if (result.transactions.isEmpty) ...[
          const SizedBox(height: kSpacing12),
          Text(
            'No valid transactions found in this file.',
            style: context.ts(14, color: context.appColors.textMedium),
          ),
        ],

        // Account selector
        if (widget.accounts.isNotEmpty) ...[
          const SizedBox(height: kSpacing16),
          DropdownButtonFormField<String>(
            value: widget.selectedAccountId,
            decoration: InputDecoration(
              labelText: 'Assign to Account',
              prefixIcon: const Icon(PesaFlowIcons.wallet, size: 20),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
            onChanged: widget.onAccountChanged,
          ),
        ],

        // Default category selector
        if (widget.categories.isNotEmpty) ...[
          const SizedBox(height: kSpacing12),
          DropdownButtonFormField<String>(
            value: widget.defaultCategoryId,
            decoration: InputDecoration(
              labelText: 'Default Category',
              prefixIcon: const Icon(Icons.category_rounded, size: 20),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
              if (id != null) widget.onCategoryChanged(id);
            },
          ),
        ],

        // Preview table
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
                            style: context.ts(10, color: context.appColors.textLow),
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
              label: Text('Import ${result.transactions.length} Transactions'),
              onPressed: () => _startImport(),
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

  Widget _buildImporting(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: kSpacing16),
        const CircularProgressIndicator(),
        const SizedBox(height: kSpacing16),
        Text(
          'Importing $_importedCount of ${_parseResult!.transactions.length}...',
          style: context.ts(14),
        ),
      ],
    );
  }

  Widget _buildDone(ThemeData theme) {
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
          'Import Complete',
          style: context.ts(18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: kSpacing4),
        Text(
          '$_importedCount transactions imported successfully.',
          style: context.ts(14, color: context.appColors.textMedium),
        ),
        const SizedBox(height: kSpacing16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: kSpacing12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

      final content = await File(result.files.single.path!).readAsString();
      final parseResult = CsvParser.parse(content);

      setState(() {
        _fileName = result.files.single.name;
        _parseResult = parseResult;
        _stage = _ImportStage.preview;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to read file: $e');
    }
  }

  Future<void> _startImport() async {
    if (_parseResult == null || _parseResult!.transactions.isEmpty) return;

    setState(() {
      _stage = _ImportStage.importing;
      _importedCount = 0;
    });

    final context = this.context;
    final repo = context.findAncestorStateOfType<State>() != null
        ? null
        : null;

    // Use the build context to access providers via a ConsumerWidget-like approach.
    // Since we're inside a StatefulBuilder inside ModernDialog, we need to
    // access providers through the nearest ConsumerWidget ancestor.
    // We'll pass a callback instead.
    final transactions = _parseResult!.transactions;
    var imported = 0;

    try {
      // We need to resolve category IDs for PesaFlow imports.
      // For generic imports, assign the selected default category.
      final resolved = transactions.map((tx) {
        if (tx.categoryId.isNotEmpty) return tx;
        return Transaction(
          id: tx.id,
          accountId: tx.accountId,
          categoryId: widget.defaultCategoryId.isNotEmpty
              ? widget.defaultCategoryId
              : tx.categoryId,
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

      // Signal the parent via a route-level approach.
      // We pop with the data and let the caller handle the actual insert.
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(
          _ImportPayload(
            transactions: resolved,
            accountId: widget.selectedAccountId,
          ),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Import failed: $e';
          _stage = _ImportStage.preview;
        });
      }
    }
  }
}

class _ImportPayload {
  final List<Transaction> transactions;
  final String? accountId;

  const _ImportPayload({required this.transactions, this.accountId});
}

enum _ImportStage { pickFile, preview, importing, done }

/// Top-level function to handle the full import flow including DB writes.
/// Called after the dialog pops with an [_ImportPayload].
Future<void> executeImport(
  BuildContext context,
  WidgetRef ref, {
  required List<Transaction> transactions,
  String? accountId,
}) async {
  final repo = ref.read(transactionRepositoryProvider);
  var imported = 0;

  for (final tx in transactions) {
    try {
      // Resolve account ID if not set on transaction
      final resolvedTx = tx.accountId == null && accountId != null
          ? Transaction(
              id: tx.id,
              accountId: accountId,
              categoryId: tx.categoryId,
              amount: tx.amount,
              type: tx.type,
              description: tx.description,
              reference: tx.reference,
              sender: tx.sender,
              recipient: tx.recipient,
              source: tx.source,
              createdAt: tx.createdAt,
              updatedAt: tx.updatedAt,
            )
          : tx;

      await repo.createTransactionNoBalanceAdjustment(resolvedTx);
      imported++;
    } catch (_) {
      // Skip duplicates or invalid rows silently
    }
  }

  if (context.mounted) {
    CustomToast.show(
      context,
      message: 'Imported $imported transactions',
      type: ToastType.success,
    );
  }
}
