import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/add_category_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/squircle_border.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  final String? initialType;
  final String? prefillDescription;
  final int? prefillAmountCents;
  final String? prefillCategoryId;
  final String? prefillAccountId;
  final String? prefillReference;

  const TransactionFormScreen({
    super.key,
    this.transactionId,
    this.initialType,
    this.prefillDescription,
    this.prefillAmountCents,
    this.prefillCategoryId,
    this.prefillAccountId,
    this.prefillReference,
  });

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  String _transactionType = 'Expense';
  String? _selectedAccountId;
  String? _selectedDestinationAccountId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String? _amountError;

  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController();

  static final Map<String, String?> _lastCategoryByType = {};

  bool _isEditMode = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _saveAsTemplate = false;
  Transaction? _existingTransaction;

  bool get _isDirty {
    if (_isSaving) return false;
    return _amountController.text.isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _referenceController.text.trim().isNotEmpty;
  }

  final List<String> _expenseSuggestions = [
    'Lunch', 'Transport / Taxi', 'Airtime Bundle', 'Electricity Luku', 'Groceries', 'Rent', 'Water Bill',
  ];
  final List<String> _incomeSuggestions = [
    'Salary Paycheck', 'Business Sale', 'Freelance gig', 'Allowance', 'Dividends / Interest',
  ];
  final List<String> _transferSuggestions = [
    'To Savings Vault', 'To Bank Account', 'To Mobile Wallet', 'Card Payment / Settlement',
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.transactionId != null;
    if (_isEditMode) {
      _loadExistingTransaction();
    } else {
      if (widget.initialType != null) {
        final type = widget.initialType!.trim().toLowerCase();
        if (type == 'expense') {
          _transactionType = 'Expense';
        } else if (type == 'income') {
          _transactionType = 'Income';
        } else if (type == 'transfer') {
          _transactionType = 'Transfer';
        }
      }
      if (widget.prefillCategoryId != null) {
        _selectedCategoryId = widget.prefillCategoryId;
      } else {
        _selectedCategoryId = _lastCategoryByType[_transactionType];
      }
      if (widget.prefillAccountId != null) {
        _selectedAccountId = widget.prefillAccountId;
      }
      if (widget.prefillDescription != null && widget.prefillDescription!.isNotEmpty) {
        _descriptionController.text = widget.prefillDescription!;
      }
      if (widget.prefillReference != null && widget.prefillReference!.isNotEmpty) {
        _referenceController.text = widget.prefillReference!;
      }
      if (widget.prefillAmountCents != null && widget.prefillAmountCents! > 0) {
        final double baseValue = widget.prefillAmountCents! / 100.0;
        _amountController.text = baseValue % 1 == 0 ? baseValue.toInt().toString() : baseValue.toString();
      }

      _loadLastUsedValues();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _referenceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadLastUsedValues() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final lastAccountId = await settingsRepo.getLastAccountId();
    final lastCategoryId = await settingsRepo.getLastCategoryId(_transactionType.toLowerCase());
    if (!mounted) return;
    setState(() {
      if (_selectedAccountId == null && lastAccountId != null) {
        _selectedAccountId = lastAccountId;
      }
      if (_selectedCategoryId == null && lastCategoryId != null) {
        _selectedCategoryId = lastCategoryId;
      }
    });
  }

  Future<void> _loadExistingTransaction() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final match = await repo.getTransactionById(widget.transactionId!);
      if (!mounted) return;
      if (match == null) throw StateError('Transaction not found');

      _existingTransaction = match.transaction;

      final double baseValue = match.transaction.amount / 100.0;
      _amountController.text = baseValue % 1 == 0 ? baseValue.toInt().toString() : baseValue.toString();

      _descriptionController.text = match.transaction.description;
      _referenceController.text = match.transaction.reference ?? '';
      _selectedAccountId = match.transaction.accountId;
      _selectedCategoryId = match.transaction.categoryId;
      _transactionType = match.transaction.type[0].toUpperCase() + match.transaction.type.substring(1).toLowerCase();
      _selectedDate = match.transaction.createdAt;

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, message: 'Failed to load transaction', type: ToastType.error);
    }
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;

    final cents = CurrencyFormatter.parseToCents(_amountController.text);
    if (cents <= 0) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    if (_selectedAccountId == null) {
      CustomToast.show(context, message: 'Please select a source account.', type: ToastType.error);
      return;
    }
    if (_transactionType == 'Transfer' && _selectedDestinationAccountId == null) {
      CustomToast.show(context, message: 'Please select a destination account.', type: ToastType.error);
      return;
    }
    if (_transactionType == 'Transfer' && _selectedDestinationAccountId == _selectedAccountId) {
      CustomToast.show(context, message: 'Source and destination accounts must be different.', type: ToastType.error);
      return;
    }
    if (_selectedCategoryId == null) {
      CustomToast.show(context, message: 'Please select a category.', type: ToastType.error);
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    final existingTransaction = _isEditMode ? _existingTransaction : null;
    final trackerId = ref.read(activeTrackerIdProvider);

    final newTransaction = Transaction(
      id: existingTransaction?.id ?? const Uuid().v4(),
      accountId: _selectedAccountId!,
      destinationAccountId: _transactionType == 'Transfer' ? _selectedDestinationAccountId : null,
      categoryId: _selectedCategoryId!,
      trackerId: existingTransaction?.trackerId ?? trackerId,
      amount: cents,
      type: _transactionType.toLowerCase(),
      description: _descriptionController.text.trim(),
      reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      source: 'manual',
      createdAt: _selectedDate,
      updatedAt: DateTime.now(),
    );

    setState(() => _isSaving = true);

    try {
      if (existingTransaction != null) {
        await repo.deleteTransaction(existingTransaction.id);
      }
      await repo.createTransaction(newTransaction);

      if (_saveAsTemplate && !_isEditMode) {
        _showSaveTemplateDialog(cents);
      }

      final settingsRepo = ref.read(settingsRepositoryProvider);
      if (_selectedAccountId != null && _selectedAccountId!.isNotEmpty) {
        settingsRepo.setLastAccountId(_selectedAccountId!);
      }
      if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
        settingsRepo.setLastCategoryId(_transactionType.toLowerCase(), _selectedCategoryId!);
      }

      HapticFeedback.mediumImpact();

      ref.invalidate(accountsStreamProvider);
      ref.invalidate(recentTransactionsStreamProvider);
      ref.invalidate(filteredTransactionsStreamProvider);
      ref.invalidate(netWorthProvider);

      if (mounted) {
        CustomToast.show(context, message: 'Transaction saved!', type: ToastType.success);
        context.pop();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, message: 'Failed to save transaction: $e', type: ToastType.error);
    }
  }

  void _showAccountPickerSheet(BuildContext context, List<Account> accounts) {
    showSpringSheet(
      context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final onSurface = theme.colorScheme.onSurface;
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.75,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: LiquidGlassOverlay(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const SizedBox(height: kSpacing10),
                    Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.17,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: kSpacing16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing20,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PesaFlowIcons.wallet,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: kSpacing12),
                          Text(
                            'Select Source Account',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: kSpacing12),
                    Expanded(
                      child: RawScrollbar(
                        controller: scrollController,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing20,
                          ),
                          itemCount: accounts.length,
                          itemBuilder: (listCtx, index) {
                            final account = accounts[index];
                            final isSelected = account.id == _selectedAccountId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: kSpacing8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _selectedAccountId = account.id,
                                  );
                                  Navigator.pop(ctx);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.all(kSpacing16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.08,
                                          )
                                        : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.4)
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.07),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          kSpacing8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                                    .withValues(alpha: 0.15)
                                              : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? PesaFlowIcons.success
                                              : PesaFlowIcons.wallet,
                                          size: 20,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.55),
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              account.name,
                                              style: context.ts(
                                                15,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : onSurface.withValues(
                                                        alpha: 0.87,
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(height: kSpacing2),
                                            Text(
                                              'Balance: ${CurrencyFormatter.formatCents(account.balance)}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: onSurface.withValues(
                                                      alpha: 0.38,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(
                                            kSpacing4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            PesaFlowIcons.check,
                                            size: 16,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _showDestinationAccountPickerSheet(
    BuildContext context,
    List<Account> accounts,
  ) {
    showSpringSheet(
      context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final onSurface = theme.colorScheme.onSurface;
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.75,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: LiquidGlassOverlay(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const SizedBox(height: kSpacing10),
                    Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.17,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: kSpacing16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing20,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PesaFlowIcons.arrowForward,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: kSpacing12),
                          Text(
                            'Select Destination Account',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: kSpacing12),
                    Expanded(
                      child: RawScrollbar(
                        controller: scrollController,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing20,
                          ),
                          itemCount: accounts.length,
                          itemBuilder: (listCtx, index) {
                            final account = accounts[index];
                            final isSelected =
                                account.id == _selectedDestinationAccountId;
                            final isSource = account.id == _selectedAccountId;
                            final isDisabled = isSource;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: kSpacing8),
                              child: GestureDetector(
                                onTap: isDisabled
                                    ? null
                                    : () {
                                        setState(
                                          () => _selectedDestinationAccountId =
                                              account.id,
                                        );
                                        Navigator.pop(ctx);
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.all(kSpacing16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.08,
                                          )
                                        : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDisabled
                                          ? Colors.grey.withValues(alpha: 0.15)
                                          : isSelected
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.4)
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.07),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          kSpacing8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDisabled
                                              ? Colors.grey.withValues(
                                                  alpha: 0.1,
                                                )
                                              : isSelected
                                              ? theme.colorScheme.primary
                                                    .withValues(alpha: 0.15)
                                              : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isDisabled
                                              ? PesaFlowIcons.block
                                              : isSelected
                                              ? PesaFlowIcons.success
                                              : PesaFlowIcons.arrowForward,
                                          size: 20,
                                          color: isDisabled
                                              ? Colors.grey
                                              : isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.55),
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  account.name,
                                                  style: context.ts(
                                                    15,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: isDisabled
                                                        ? theme
                                                              .colorScheme
                                                              .onSurfaceVariant
                                                        : isSelected
                                                        ? theme
                                                              .colorScheme
                                                              .primary
                                                        : onSurface.withValues(
                                                            alpha: 0.87,
                                                          ),
                                                  ),
                                                ),
                                                if (isDisabled) ...[
                                                  const SizedBox(
                                                    width: kSpacing6,
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'source',
                                                      style: context.ts(
                                                        10,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: kSpacing2),
                                            Text(
                                              'Balance: ${CurrencyFormatter.formatCents(account.balance)}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: onSurface.withValues(
                                                      alpha: 0.38,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(
                                            kSpacing4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            PesaFlowIcons.check,
                                            size: 16,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _showSaveTemplateDialog(int amountCents) {
    final nameController = TextEditingController();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Save as Template',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: context.inputDecoration(
            hintText: 'e.g. Daily lunch 5000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: context.ts(14, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final template = {
                'id': const Uuid().v4(),
                'name': name,
                'type': _transactionType.toLowerCase(),
                'amountCents': amountCents,
                'description': _descriptionController.text.trim(),
                'categoryId': _selectedCategoryId,
                'accountId': _selectedAccountId,
              };
              Navigator.pop(ctx);
              await ref
                  .read(settingsRepositoryProvider)
                  .saveTransactionTemplate(template);
              if (mounted) {
                CustomToast.show(
                  context,
                  message: 'Template saved!',
                  type: ToastType.success,
                );
              }
            },
            child: Text(
              'Save',
              style: context.ts(
                14,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      final type = template['type'] as String? ?? 'expense';
      _transactionType = type[0].toUpperCase() + type.substring(1);
      _selectedCategoryId = template['categoryId'] as String?;
      _selectedAccountId = template['accountId'] as String?;
      _descriptionController.text = template['description'] as String? ?? '';
      final cents = template['amountCents'] as int? ?? 0;
      if (cents > 0) {
        final double baseValue = cents / 100.0;
        _amountController.text = baseValue % 1 == 0
            ? baseValue.toInt().toString()
            : baseValue.toString();
      }
    });
  }
  
  void _showTemplatePickerSheet(BuildContext context) {
    showSpringSheet(
      context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final onSurface = theme.colorScheme.onSurface;
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.75,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: LiquidGlassOverlay(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const SizedBox(height: kSpacing10),
                    Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: onSurface.withValues(alpha: 0.17),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: kSpacing16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing20,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PesaFlowIcons.bookmark,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: kSpacing12),
                          Text(
                            'Templates',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: kSpacing12),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: ref
                            .read(settingsRepositoryProvider)
                            .getTransactionTemplates(),
                        builder: (context, snapshot) {
                          final templates = snapshot.data ?? [];
                          if (templates.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(kSpacing32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PesaFlowIcons.bookmark,
                                      size: 48,
                                      color: onSurface.withValues(alpha: 0.2),
                                    ),
                                    const SizedBox(height: kSpacing12),
                                    Text(
                                      'No templates yet',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: kSpacing4),
                                    Text(
                                      'Save a transaction as a template\nfor quick reuse later.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: onSurface.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return RawScrollbar(
                            controller: scrollController,
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: kSpacing20,
                              ),
                              itemCount: templates.length,
                              itemBuilder: (listCtx, index) {
                                final t = templates[index];
                                final type = t['type'] as String? ?? 'expense';
                                final amount = t['amountCents'] as int? ?? 0;
                                final name = t['name'] as String? ?? 'Untitled';
                                final typeIcon = type == 'income'
                                    ? PesaFlowIcons.income
                                    : type == 'transfer'
                                    ? PesaFlowIcons.transfer
                                    : PesaFlowIcons.expense;
                                final typeColor = type == 'income'
                                    ? context.appColors.incomeColor
                                    : type == 'transfer'
                                    ? AppTheme.transferColorDark
                                    : context.appColors.expenseColor;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: kSpacing8,
                                  ),
                                  child: Dismissible(
                                    key: ValueKey(t['id']),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(
                                        right: kSpacing20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.appColors.expenseColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        PesaFlowIcons.delete,
                                        color: context.appColors.expenseColor,
                                      ),
                                    ),
                                    onDismissed: (_) async {
                                      final templateData = t;
                                      UndoDelete.show(
                                        context: context,
                                        entityName: 'Template',
                                        onUndo: () async {
                                          await ref
                                              .read(settingsRepositoryProvider)
                                              .saveTransactionTemplate(
                                                templateData,
                                              );
                                        },
                                        onDelete: () async {
                                          await ref
                                              .read(settingsRepositoryProvider)
                                              .deleteTransactionTemplate(
                                                templateData['id'] as String,
                                              );
                                        },
                                      );
                                    },
                                    child: GestureDetector(
                                      onTap: () {
                                        _applyTemplate(t);
                                        Navigator.pop(ctx);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          kSpacing16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: onSurface.withValues(
                                              alpha: 0.07,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(
                                                kSpacing8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: typeColor.withValues(
                                                  alpha: 0.12,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                typeIcon,
                                                size: 18,
                                                color: typeColor,
                                              ),
                                            ),
                                            const SizedBox(width: kSpacing12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: context.ts(
                                                      15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (t['description'] !=
                                                          null &&
                                                      (t['description']
                                                              as String)
                                                          .isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: kSpacing2,
                                                          ),
                                                      child: Text(
                                                        t['description']
                                                            as String,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: onSurface
                                                                  .withValues(
                                                                    alpha: 0.4,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              CurrencyFormatter.formatCents(
                                                amount,
                                              ),
                                              style: context.ts(
                                                14,
                                                fontWeight: FontWeight.bold,
                                                color: typeColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySelector(List<dynamic> categories, ThemeData theme) {
    final filteredCategories = categories.where((cat) {
      return cat.type.toLowerCase() == _transactionType.toLowerCase();
    }).toList();
    
    if (_selectedCategoryId == null && filteredCategories.isNotEmpty) {
      _selectedCategoryId = filteredCategories.first.id;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: kSpacing4,
            bottom: kSpacing10,
            top: kSpacing8,
          ),
          child: Text(
            'CATEGORY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: filteredCategories.length + 1,
            itemBuilder: (context, index) {
              if (index == filteredCategories.length) {
                return Padding(
                  padding: const EdgeInsets.only(right: kSpacing12),
                  child: TactileSpringContainer(
                    onTap: () async {
                      final newCat = await showAddCategoryDialog(
                        context,
                        ref,
                        initialType: _transactionType,
                      );
                      if (newCat != null) {
                        _lastCategoryByType[_transactionType] = newCat.id;
                        setState(() {
                          _selectedCategoryId = newCat.id;
                        });
                      }
                    },
                    child: Container(
                      width: 76,
                      decoration: ShapeDecoration(
                        color: Colors.transparent,
                        shape: SquircleBorder(
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                            width: 1.5,
                          ),
                          borderRadius: 14.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PesaFlowIcons.add,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(height: kSpacing6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: kSpacing4),
                            child: Text(
                              'Custom',
                              style: context.ts(
                                10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            
              final cat = filteredCategories[index];
              final isSelected = cat.id == _selectedCategoryId;
              final color = hexToColor(cat.color);

              return Padding(
                padding: const EdgeInsets.only(right: kSpacing12),
                child: TactileSpringContainer(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _lastCategoryByType[_transactionType] = cat.id;
                      _selectedCategoryId = cat.id;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    decoration: ShapeDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.03),
                      shape: SquircleBorder(
                        side: BorderSide(
                          color: isSelected ? color : theme.colorScheme.outlineVariant,
                          width: isSelected ? 1.5 : 0.8,
                        ),
                        borderRadius: 14.0,
                      ),
                      shadows: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          getCategoryIcon(cat.icon),
                          color: isSelected ? color : theme.colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(height: kSpacing6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: kSpacing4),
                          child: Text(
                            cat.name,
                            style: context.ts(
                              10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: kSpacing12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    final activeAccount = accounts.firstWhere(
      (acc) => acc.id == _selectedAccountId,
      orElse: () => accounts.isNotEmpty
          ? accounts.first
          : Account(
              id: '',
              name: 'No Account',
              type: 'cash',
              icon: 'wallet',
              balance: 0,
              createdAt: DateTime.now(),
              sortOrder: 0,
              isArchived: false,
            ),
    );

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await ModernDialog.show<bool>(
          context: context,
          title: const Text('Discard Changes?'),
          titleIcon: PesaFlowIcons.warning,
          iconColor: Colors.orange,
          content: const Text(
            'You have unsaved changes. Are you sure you want to go back?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.expenseColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : accounts.isEmpty
            ? EmptyState(
                icon: PesaFlowIcons.warning,
                title: 'No Accounts Available',
                subtitle: 'You must create at least one Account before recording manual transactions.',
                illustration: PesaFlowIllustration.emptyTransactions(),
                action: TactileSpringContainer(
                  onTap: () => context.go('/'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'Go to Dashboard',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            : SafeArea(
                child: Column(
                  children: [
                    IosNavBar(
                      title: _isEditMode ? 'Edit Transaction' : 'New Transaction',
                      largeTitle: false,
                      actions: !_isEditMode 
                          ? [
                              IconButton(
                                icon: Icon(PesaFlowIcons.bookmark, color: theme.colorScheme.primary),
                                onPressed: () => _showTemplatePickerSheet(context),
                              ),
                            ]
                          : null,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(kSpacing16),
                        child: Form(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TRANSACTION DETAILS',
                                style: theme.textTheme.bodySmall!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: onSurface.withValues(alpha: 0.45),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: kSpacing8),
                              StaggeredFadeSlide(
                                index: 0,
                                child: GlassCard(
                                  padding: const EdgeInsets.all(kSpacing16),
                                  borderRadius: AppTheme.radiusCard,
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: CupertinoSlidingSegmentedControl<String>(
                                          groupValue: _transactionType,
                                          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                          thumbColor: theme.colorScheme.surface,
                                          children: {
                                            'Expense': Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: kSpacing10, vertical: kSpacing8),
                                              child: Text(
                                                'Expense',
                                                style: theme.textTheme.labelMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: _transactionType == 'Expense'
                                                      ? context.appColors.expenseColor
                                                      : theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            'Income': Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: kSpacing10, vertical: kSpacing8),
                                              child: Text(
                                                'Income',
                                                style: theme.textTheme.labelMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: _transactionType == 'Income'
                                                      ? context.appColors.incomeColor
                                                      : theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            'Transfer': Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: kSpacing10, vertical: kSpacing8),
                                              child: Text(
                                                'Transfer',
                                                style: theme.textTheme.labelMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: _transactionType == 'Transfer'
                                                      ? context.appColors.transferColor
                                                      : theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          },
                                          onValueChanged: (v) {
                                            if (v != null) {
                                              setState(() {
                                                _transactionType = v;
                                                _selectedCategoryId = _lastCategoryByType[v];
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: kSpacing16),
                                      
                                      categoriesAsync.when(
                                        data: (cats) => _buildCategorySelector(cats, theme),
                                        loading: () => const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 20),
                                          child: Center(child: CircularProgressIndicator()),
                                        ),
                                        error: (e, _) => Text('Error loading categories'),
                                      ),
                                      
                                      TextFormField(
                                        controller: _amountController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        style: theme.textTheme.titleMedium!.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: context.inputDecoration(
                                          labelText: 'Amount (Tsh)',
                                          hintText: 'e.g. 10000',
                                          prefixIcon: Icon(PesaFlowIcons.cash, size: 18),
                                        ).copyWith(errorText: _amountError),
                                        onChanged: (_) => setState(() => _amountError = null),
                                      ),
                                      const SizedBox(height: kSpacing12),
                                      TextFormField(
                                        controller: _descriptionController,
                                        textCapitalization: TextCapitalization.sentences,
                                        style: theme.textTheme.titleMedium!.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: context.inputDecoration(
                                          labelText: 'Description',
                                          hintText: 'e.g. Lunch',
                                          prefixIcon: Icon(PesaFlowIcons.label, size: 18),
                                        ),
                                      ),
                                      const SizedBox(height: kSpacing8),
                                      
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: (_transactionType == 'Expense'
                                                  ? _expenseSuggestions
                                                  : (_transactionType == 'Income'
                                                      ? _incomeSuggestions
                                                      : _transferSuggestions))
                                              .map((suggestion) {
                                            return Padding(
                                              padding: const EdgeInsets.only(right: kSpacing6),
                                              child: ActionChip(
                                                label: Text(
                                                  suggestion,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: onSurface.withValues(alpha: 0.87),
                                                  ),
                                                ),
                                                backgroundColor: onSurface.withValues(alpha: 0.05),
                                                side: BorderSide(color: onSurface.withValues(alpha: 0.08)),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _descriptionController.text = suggestion;
                                                  });
                                                },
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: kSpacing20),
                              
                              Text(
                                'ACCOUNTS & TIMING',
                                style: theme.textTheme.bodySmall!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: onSurface.withValues(alpha: 0.45),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: kSpacing8),
                              StaggeredFadeSlide(
                                index: 1,
                                child: GlassCard(
                                  padding: const EdgeInsets.all(kSpacing16),
                                  borderRadius: AppTheme.radiusCard,
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () => _showAccountPickerSheet(context, accounts),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: onSurface.withValues(alpha: 0.1)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(PesaFlowIcons.wallet, size: 20, color: theme.colorScheme.primary),
                                              const SizedBox(width: kSpacing12),
                                              Expanded(
                                                child: Text(
                                                  _transactionType == 'Transfer' ? 'From: ${activeAccount.name}' : 'Account: ${activeAccount.name}',
                                                  style: theme.textTheme.titleSmall,
                                                ),
                                              ),
                                              Icon(PesaFlowIcons.chevronDown, size: 20, color: onSurface.withValues(alpha: 0.5)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_transactionType == 'Transfer') ...[
                                        const SizedBox(height: kSpacing12),
                                        InkWell(
                                          onTap: () => _showDestinationAccountPickerSheet(context, accounts),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: onSurface.withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(PesaFlowIcons.wallet, size: 20, color: context.appColors.transferColor),
                                                const SizedBox(width: kSpacing12),
                                                Expanded(
                                                  child: Text(
                                                    _selectedDestinationAccountId != null
                                                        ? 'To: ${accounts.firstWhere((a) => a.id == _selectedDestinationAccountId, orElse: () => Account(id: '', name: 'Unknown', type: '', balance: 0, icon: '', sortOrder: 0, isArchived: false, createdAt: DateTime.now())).name}'
                                                        : 'To: Select Destination',
                                                    style: theme.textTheme.titleSmall,
                                                  ),
                                                ),
                                                Icon(PesaFlowIcons.chevronDown, size: 20, color: onSurface.withValues(alpha: 0.5)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: kSpacing16),
                                      ModernDateSelector(
                                        labelText: 'Transaction Date',
                                        value: _selectedDate,
                                        prefixIcon: PesaFlowIcons.calendar,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2101),
                                        onChanged: (d) => setState(() => _selectedDate = d),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: kSpacing20),
                              
                              Text(
                                'OPTIONAL',
                                style: theme.textTheme.bodySmall!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: onSurface.withValues(alpha: 0.45),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: kSpacing8),
                              StaggeredFadeSlide(
                                index: 2,
                                child: GlassCard(
                                  padding: const EdgeInsets.all(kSpacing16),
                                  borderRadius: AppTheme.radiusCard,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _referenceController,
                                        textCapitalization: TextCapitalization.characters,
                                        style: theme.textTheme.titleMedium!.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: context.inputDecoration(
                                          labelText: 'Carrier Reference',
                                          hintText: 'e.g. PP230489A1',
                                          prefixIcon: Icon(PesaFlowIcons.upcoming, size: 18),
                                        ),
                                      ),
                                      if (!_isEditMode) ...[
                                        const SizedBox(height: kSpacing16),
                                        SwitchListTile(
                                          title: Text('Save as template', style: theme.textTheme.titleSmall),
                                          subtitle: Text('Quickly reuse this transaction later', style: theme.textTheme.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.6))),
                                          value: _saveAsTemplate,
                                          activeTrackColor: theme.colorScheme.primary,
                                          contentPadding: EdgeInsets.zero,
                                          onChanged: (val) => setState(() => _saveAsTemplate = val),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: kSpacing32),
                              
                              StaggeredFadeSlide(
                                index: 3,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: kSpacing48,
                                  child: TactileSpringContainer(
                                    onTap: _isSaving ? null : _saveTransaction,
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.colorScheme.primary,
                                            theme.colorScheme.primary.withValues(alpha: 0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(100),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: kSpacing20,
                                              width: kSpacing20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _isEditMode ? 'Update Transaction' : 'Record Transaction',
                                              style: theme.textTheme.titleMedium!.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: kSpacing32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
