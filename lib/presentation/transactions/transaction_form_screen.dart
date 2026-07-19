import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/responsive.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/state/spending_pattern_provider.dart';
import 'package:pesaflow/presentation/common/widgets/squircle_border.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/add_category_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';

import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/calculator_numpad.dart';

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
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  String _amountStr = '0'; // Current keypad entered digits
  String _transactionType = 'Expense'; // Default
  String? _selectedAccountId;
  String? _selectedDestinationAccountId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String? _amountError;

  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();

  static final Map<String, String?> _lastCategoryByType = {};

  bool _isEditMode = false;
  bool _isLoading = false;
  bool _showAdvanced = false;
  bool _saveAsTemplate = false;
  Transaction? _existingTransaction;

  final List<String> _expenseSuggestions = [
    'Lunch',
    'Transport / Taxi',
    'Airtime Bundle',
    'Electricity Luku',
    'Groceries',
    'Rent',
    'Water Bill',
  ];
  final List<String> _incomeSuggestions = [
    'Salary Paycheck',
    'Business Sale',
    'Freelance gig',
    'Allowance',
    'Dividends / Interest',
  ];
  final List<String> _transferSuggestions = [
    'To Savings Vault',
    'To Bank Account',
    'To Mobile Wallet',
    'Card Payment / Settlement',
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
      if (widget.prefillDescription != null &&
          widget.prefillDescription!.isNotEmpty) {
        _descriptionController.text = widget.prefillDescription!;
      }
      if (widget.prefillReference != null &&
          widget.prefillReference!.isNotEmpty) {
        _referenceController.text = widget.prefillReference!;
      }
      if (widget.prefillAmountCents != null && widget.prefillAmountCents! > 0) {
        final double baseValue = widget.prefillAmountCents! / 100.0;
        _amountStr = baseValue % 1 == 0
            ? baseValue.toInt().toString()
            : baseValue.toString();
      }

      _loadLastUsedValues();
    }
  }

  Future<void> _loadLastUsedValues() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final lastAccountId = await settingsRepo.getLastAccountId();
    final lastCategoryId = await settingsRepo.getLastCategoryId(
      _transactionType.toLowerCase(),
    );
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
      _amountStr = baseValue % 1 == 0
          ? baseValue.toInt().toString()
          : baseValue.toString();

      _descriptionController.text = match.transaction.description;
      _referenceController.text = match.transaction.reference ?? '';
      _selectedAccountId = match.transaction.accountId;
      _selectedCategoryId = match.transaction.categoryId;
      _transactionType =
          match.transaction.type[0].toUpperCase() +
          match.transaction.type.substring(1).toLowerCase();
      _selectedDate = match.transaction.createdAt;

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load transaction: $e')));
    }
  }

  void _keypadPress(String value) {
    if (value == '<') {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _amountError = null;
      if (value == '<') {
        // Backspace
        if (_amountStr.length > 1) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        } else {
          _amountStr = '0';
        }
      } else if (value == '.') {
        if (!_amountStr.contains('.')) {
          _amountStr += '.';
        }
      } else {
        // Numbers
        if (_amountStr == '0') {
          _amountStr = value;
        } else {
          // Limit length to keep display elegant
          if (_amountStr.length < 12) {
            _amountStr += value;
          }
        }
      }
    });
  }

  String _exprStringForDisplay(String expr) {
    final operators = RegExp(r'([\+\-\*\/])');
    final parts = expr.split(operators);
    final matches = operators.allMatches(expr).map((m) => m.group(0)!).toList();
    
    final formattedParts = parts.map((part) {
      final doubleValue = double.tryParse(part);
      if (doubleValue != null) {
        return NumberFormat('#,###.##').format(doubleValue);
      }
      return part;
    }).toList();
    
    final result = StringBuffer();
    for (int i = 0; i < formattedParts.length; i++) {
      result.write(formattedParts[i]);
      if (i < matches.length) {
        result.write(' ${matches[i]} ');
      }
    }
    return result.toString();
  }

  double _getAmountCents() {
    String val = _amountStr;
    if (_amountStr.contains(RegExp(r'[\+\-\*\/]'))) {
      try {
        final double? evaluated = _parseAndEval(_amountStr);
        if (evaluated != null) {
          val = evaluated.toString();
        }
      } catch (_) {}
    }
    return CurrencyFormatter.parseToCents(val).toDouble();
  }

  double? _parseAndEval(String expression) {
    final normalized = expression.replaceAll(' ', '');
    try {
      return _parseAdditionSubtraction(normalized);
    } catch (_) {
      return null;
    }
  }

  double _parseAdditionSubtraction(String expr) {
    int opIndex = -1;
    String currentOp = '';
    for (int i = expr.length - 1; i >= 0; i--) {
      final char = expr[i];
      if (char == '+' || char == '-') {
        opIndex = i;
        currentOp = char;
        break;
      }
    }
    if (opIndex != -1) {
      final left = _parseAdditionSubtraction(expr.substring(0, opIndex));
      final right = _parseMultiplicationDivision(expr.substring(opIndex + 1));
      if (currentOp == '+') return left + right;
      if (currentOp == '-') return left - right;
    }
    return _parseMultiplicationDivision(expr);
  }

  double _parseMultiplicationDivision(String expr) {
    int opIndex = -1;
    String currentOp = '';
    for (int i = expr.length - 1; i >= 0; i--) {
      final char = expr[i];
      if (char == '*' || char == '/') {
        opIndex = i;
        currentOp = char;
        break;
      }
    }
    if (opIndex != -1) {
      final left = _parseMultiplicationDivision(expr.substring(0, opIndex));
      final right = double.parse(expr.substring(opIndex + 1));
      if (currentOp == '*') return left * right;
      if (currentOp == '/') {
        if (right == 0) throw Exception('Division by zero');
        return left / right;
      }
    }
    return double.parse(expr);
  }

  Future<void> _saveTransaction() async {
    final cents = _getAmountCents().round();
    if (cents <= 0) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    if (_selectedAccountId == null) {
      CustomToast.show(
        context,
        message: 'Please select a source account.',
        type: ToastType.error,
      );
      return;
    }
    if (_transactionType == 'Transfer' &&
        _selectedDestinationAccountId == null) {
      CustomToast.show(
        context,
        message: 'Please select a destination account.',
        type: ToastType.error,
      );
      return;
    }
    if (_transactionType == 'Transfer' &&
        _selectedDestinationAccountId == _selectedAccountId) {
      CustomToast.show(
        context,
        message: 'Source and destination accounts must be different.',
        type: ToastType.error,
      );
      return;
    }
    if (_selectedCategoryId == null) {
      CustomToast.show(
        context,
        message: 'Please select a category.',
        type: ToastType.error,
      );
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    final existingTransaction = _isEditMode ? _existingTransaction : null;
    final trackerId = ref.read(activeTrackerIdProvider);

    final newTransaction = Transaction(
      id: existingTransaction?.id ?? const Uuid().v4(),
      accountId: _selectedAccountId!,
      destinationAccountId: _transactionType == 'Transfer'
          ? _selectedDestinationAccountId
          : null,
      categoryId: _selectedCategoryId!,
      trackerId: existingTransaction?.trackerId ?? trackerId,
      amount: cents,
      type: _transactionType.toLowerCase(),
      description: _descriptionController.text.trim(),
      reference: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      source: 'manual',
      createdAt: _selectedDate,
      updatedAt: DateTime.now(),
    );

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
        settingsRepo.setLastCategoryId(
          _transactionType.toLowerCase(),
          _selectedCategoryId!,
        );
      }

      HapticFeedback.mediumImpact();

      ref.invalidate(accountsStreamProvider);
      ref.invalidate(recentTransactionsStreamProvider);
      ref.invalidate(filteredTransactionsStreamProvider);
      ref.invalidate(netWorthProvider);

      if (mounted) {
        CustomToast.show(
          context,
          message: 'Transaction saved!',
          type: ToastType.success,
        );
        context.pop();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Failed to save transaction: $e',
        type: ToastType.error,
      );
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

  void _showSecondaryDetailsSheet(BuildContext context) {
    showSpringSheet(
      context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final onSurface = theme.colorScheme.onSurface;
        return Consumer(
          builder: (context, ref, _) {
            final categories = ref.watch(categoriesFutureProvider).value ?? [];
            final filteredCategories = categories.where((cat) {
              return cat.type.toLowerCase() == _transactionType.toLowerCase();
            }).toList();

            if (_selectedCategoryId == null && filteredCategories.isNotEmpty) {
              _selectedCategoryId = filteredCategories.first.id;
            }

            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24.0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing20,
                    vertical: kSpacing24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: kSpacing20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        Text(
                          'Transaction details'.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: kSpacing16),

                        StaggeredFadeSlide(
                          index: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category',
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: kSpacing12),
                              GridView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 1.0,
                                    ),
                                itemCount: filteredCategories.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == filteredCategories.length) {
                                    return TactileSpringContainer(
                                      onTap: () async {
                                        final newCat =
                                            await showAddCategoryDialog(
                                              context,
                                              ref,
                                              initialType: _transactionType,
                                            );
                                        if (newCat != null) {
                                          _lastCategoryByType[_transactionType] =
                                              newCat.id;
                                          setSheetState(() {
                                            _selectedCategoryId = newCat.id;
                                          });
                                          setState(() {
                                            _selectedCategoryId = newCat.id;
                                          });
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant,
                                            style: BorderStyle.solid,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              PesaFlowIcons.add,
                                              color: theme.colorScheme.primary,
                                              size: 24,
                                            ),
                                            const SizedBox(height: kSpacing6),
                                            Text(
                                              'Custom',
                                              style: context.ts(
                                                11,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  final cat = filteredCategories[index];
                                  final isSel = cat.id == _selectedCategoryId;
                                  final catColor = hexToColor(cat.color);

                                  return TactileSpringContainer(
                                    onTap: () {
                                      _lastCategoryByType[_transactionType] =
                                          cat.id;
                                      setSheetState(
                                        () => _selectedCategoryId = cat.id,
                                      );
                                      setState(
                                        () => _selectedCategoryId = cat.id,
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? catColor.withValues(alpha: 0.15)
                                            : theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSel
                                              ? catColor
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                        boxShadow: isSel
                                            ? [
                                                BoxShadow(
                                                  color: catColor.withValues(
                                                    alpha: 0.25,
                                                  ),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            getCategoryIcon(cat.icon),
                                            color: isSel
                                                ? catColor
                                                : (theme.brightness ==
                                                          Brightness.dark
                                                      ? Colors.white60
                                                      : Colors.black54),
                                            size: 24,
                                          ),
                                          const SizedBox(height: kSpacing6),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: kSpacing4,
                                            ),
                                            child: Text(
                                              cat.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: context.ts(
                                                11,
                                                color: isSel
                                                    ? (theme.brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : catColor)
                                                    : (theme.brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.7,
                                                                )
                                                          : theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.87,
                                                                )),
                                                fontWeight: isSel
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpacing20),

                        StaggeredFadeSlide(
                          index: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Description',
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: kSpacing8),
                              TextField(
                                controller: _descriptionController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: context.inputDecoration(
                                  hintText: 'e.g. Lunch, taxi, data bundle',
                                ),
                                onChanged: (val) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpacing10),

                        StaggeredFadeSlide(
                          index: 2,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children:
                                  (_transactionType == 'Expense'
                                          ? _expenseSuggestions
                                          : (_transactionType == 'Income'
                                                ? _incomeSuggestions
                                                : _transferSuggestions))
                                      .map((suggestion) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: kSpacing6,
                                          ),
                                          child: ActionChip(
                                            label: Text(
                                              suggestion,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: onSurface.withValues(
                                                      alpha: 0.87,
                                                    ),
                                                  ),
                                            ),
                                            backgroundColor: onSurface
                                                .withValues(alpha: 0.05),
                                            side: BorderSide(
                                              color: onSurface.withValues(
                                                alpha: 0.08,
                                              ),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            onPressed: () {
                                              setSheetState(() {
                                                _descriptionController.text =
                                                    suggestion;
                                              });
                                              setState(() {
                                                _descriptionController.text =
                                                    suggestion;
                                              });
                                            },
                                          ),
                                        );
                                      })
                                      .toList(),
                            ),
                          ),
                        ),
                        // Progressive Disclosure: Collapsible details
                        const SizedBox(height: kSpacing12),
                        InkWell(
                          onTap: () {
                            setSheetState(() => _showAdvanced = !_showAdvanced);
                            setState(() => _showAdvanced = !_showAdvanced);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: kSpacing8,
                              horizontal: kSpacing4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ADDITIONAL DETAILS',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Icon(
                                  _showAdvanced
                                      ? PesaFlowIcons.chevronUp
                                      : PesaFlowIcons.chevronDown,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: kSpacing12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Carrier Reference (Optional)',
                                  style: context.ts(
                                    13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: kSpacing8),
                                TextField(
                                  controller: _referenceController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: onSurface.withValues(alpha: 0.87),
                                  ),
                                  decoration: context.inputDecoration(
                                    hintText: 'e.g. PP230489A1',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: _showAdvanced
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 250),
                        ),
                        const SizedBox(height: kSpacing20),

                        StaggeredFadeSlide(
                          index: 3,
                          child: ModernDateSelector(
                            labelText: 'Transaction Date',
                            value: _selectedDate,
                            prefixIcon: PesaFlowIcons.calendar,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2101),
                            onChanged: (picked) {
                              setSheetState(() => _selectedDate = picked);
                              setState(() => _selectedDate = picked);
                            },
                          ),
                        ),
                        const SizedBox(height: kSpacing32),

                        if (!_isEditMode)
                          StaggeredFadeSlide(
                            index: 3,
                            child: GestureDetector(
                              onTap: () => setSheetState(
                                () => _saveAsTemplate = !_saveAsTemplate,
                              ),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kSpacing16,
                                  vertical: kSpacing12,
                                ),
                                decoration: BoxDecoration(
                                  color: _saveAsTemplate
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.08,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _saveAsTemplate
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.3,
                                          )
                                        : onSurface.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _saveAsTemplate
                                          ? PesaFlowIcons.bookmarkFilled
                                          : PesaFlowIcons.bookmark,
                                      size: 20,
                                      color: _saveAsTemplate
                                          ? theme.colorScheme.primary
                                          : onSurface.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(width: kSpacing12),
                                    Expanded(
                                      child: Text(
                                        'Save as template',
                                        style: context.ts(
                                          14,
                                          fontWeight: FontWeight.w500,
                                          color: _saveAsTemplate
                                              ? theme.colorScheme.primary
                                              : onSurface.withValues(
                                                  alpha: 0.6,
                                                ),
                                        ),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: _saveAsTemplate
                                            ? theme.colorScheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _saveAsTemplate
                                              ? theme.colorScheme.primary
                                              : onSurface.withValues(
                                                  alpha: 0.3,
                                                ),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: _saveAsTemplate
                                          ? const Icon(
                                              PesaFlowIcons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (!_isEditMode) const SizedBox(height: kSpacing12),

                        StaggeredFadeSlide(
                          index: 4,
                          child: TactileSpringContainer(
                            onTap: () {
                              Navigator.pop(context);
                              _saveTransaction();
                            },
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              alignment: Alignment.center,
                              decoration: ShapeDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary.withValues(
                                      alpha: 0.8,
                                    ),
                                  ],
                                ),
                                shape: const SquircleBorder(borderRadius: 24.0),
                                shadows: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                _isEditMode
                                    ? 'Update Transaction'
                                    : 'Record Transaction',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
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
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
              style: TextStyle(
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
        _amountStr = baseValue % 1 == 0
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accounts = ref.watch(accountsStreamProvider).value ?? [];

    final spendingPatternAsync = ref.watch(currentSpendingPatternProvider);

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

    // Parsing amount for bold screen display
    final String formattedDisplay;
    if (_amountStr.contains(RegExp(r'[\+\-\*\/]'))) {
      formattedDisplay = _exprStringForDisplay(_amountStr);
    } else {
      final double amountValue = double.tryParse(_amountStr) ?? 0.0;
      formattedDisplay = NumberFormat('#,###.##').format(amountValue);
    }

    final double baseFontSize = _amountStr.length > 10
        ? 36.0
        : (_amountStr.length > 7 ? 46.0 : 64.0);
    final double fontSize = responsiveFontSize(context, base: baseFontSize);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : accounts.isEmpty
          ? EmptyState(
              icon: PesaFlowIcons.warning,
              title: 'No Accounts Available',
              subtitle:
                  'You must create at least one Account before recording manual transactions.',
              illustration: PesaFlowIllustration.emptyTransactions(),
              action: TactileSpringContainer(
                onTap: () => context.go('/'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
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
                  ),
                  SizedBox(height: context.isCompactView ? 8 : 16),
                  StaggeredFadeSlide(
                    index: 0,
                    child: Container(
                      width: responsiveValue(
                        context,
                        compact: 280,
                        tablet: 400,
                        desktop: 480,
                      ),
                      padding: const EdgeInsets.all(kSpacing4),
                      decoration: BoxDecoration(
                        color: onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Expense pill
                          Expanded(
                            child: TactileSpringContainer(
                              onTap: () => setState(() {
                                _transactionType = 'Expense';
                                _selectedCategoryId =
                                    _lastCategoryByType['Expense'];
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: kSpacing10,
                                ),
                                decoration: BoxDecoration(
                                  color: _transactionType == 'Expense'
                                      ? context.appColors.expenseColor
                                            .withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(100),
                                  border: _transactionType == 'Expense'
                                      ? Border.all(
                                          color: context.appColors.expenseColor,
                                          width: 1.2,
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Expense',
                                    style: context.ts(
                                      13,
                                      fontWeight: FontWeight.bold,
                                      color: _transactionType == 'Expense'
                                          ? context.appColors.expenseColor
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Income pill
                          Expanded(
                            child: TactileSpringContainer(
                              onTap: () => setState(() {
                                _transactionType = 'Income';
                                _selectedCategoryId =
                                    _lastCategoryByType['Income'];
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: kSpacing10,
                                ),
                                decoration: BoxDecoration(
                                  color: _transactionType == 'Income'
                                      ? AppTheme.transferColorDark.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(100),
                                  border: _transactionType == 'Income'
                                      ? Border.all(
                                          color: AppTheme.transferColorDark,
                                          width: 1.2,
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Income',
                                    style: context.ts(
                                      13,
                                      fontWeight: FontWeight.bold,
                                      color: _transactionType == 'Income'
                                          ? AppTheme.transferColorDark
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Transfer pill
                          Expanded(
                            child: TactileSpringContainer(
                              onTap: () => setState(() {
                                _transactionType = 'Transfer';
                                _selectedCategoryId =
                                    _lastCategoryByType['Transfer'];
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: kSpacing10,
                                ),
                                decoration: BoxDecoration(
                                  color: _transactionType == 'Transfer'
                                      ? AppTheme.transferColorDark.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(100),
                                  border: _transactionType == 'Transfer'
                                      ? Border.all(
                                          color: AppTheme.transferColorDark,
                                          width: 1.2,
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Transfer',
                                    style: context.ts(
                                      13,
                                      fontWeight: FontWeight.bold,
                                      color: _transactionType == 'Transfer'
                                          ? AppTheme.transferColorDark
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Giant visual amount display
                  StaggeredFadeSlide(
                    index: 1,
                    child: Column(
                      children: [
                        Text(
                          'Amount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: kSpacing6),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing24,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: KeypadSpringText(
                              text: 'Tsh $formattedDisplay',
                              style: theme.textTheme.headlineMedium!.copyWith(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w900,
                                color: onSurface,
                                fontFamily: 'monospace',
                                letterSpacing: -1.0,
                              ),
                            ),
                          ),
                        ),
                        if (spendingPatternAsync.asData?.value
                            case final pattern? when _amountStr == '0')
                          Padding(
                            padding: const EdgeInsets.only(top: kSpacing8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  final formatted =
                                      CurrencyFormatter.formatCents(
                                        pattern.averageAmountCents,
                                      ).replaceAll('Tsh ', '');
                                  _amountStr = formatted;
                                  _selectedCategoryId = pattern.categoryId;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Usually ${CurrencyFormatter.formatCents(pattern.averageAmountCents)} at this time',
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        if (_amountError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: kSpacing4),
                            child: Text(
                              _amountError!,
                              style: context.ts(
                                12,
                                color: context.appColors.expenseColor,
                              ),
                            ),
                          ),
                        const SizedBox(height: kSpacing14),
                      ],
                    ),
                  ),

                  StaggeredFadeSlide(
                    index: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TactileSpringContainer(
                          onTap: () =>
                              _showAccountPickerSheet(context, accounts),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing16,
                              vertical: kSpacing8,
                            ),
                            decoration: BoxDecoration(
                              color: onSurface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: onSurface.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'From ${activeAccount.name}',
                                  style: context.ts(
                                    13,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface.withValues(alpha: 0.87),
                                  ),
                                ),
                                const SizedBox(width: kSpacing4),
                                Icon(
                                  PesaFlowIcons.chevronDown,
                                  color: onSurface.withValues(alpha: 0.54),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_transactionType == 'Transfer') ...[
                          const SizedBox(width: kSpacing8),
                          TactileSpringContainer(
                            onTap: () => _showDestinationAccountPickerSheet(
                              context,
                              accounts,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: kSpacing16,
                                vertical: kSpacing8,
                              ),
                              decoration: BoxDecoration(
                                color: onSurface.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: onSurface.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedDestinationAccountId != null
                                        ? 'To ${accounts.firstWhere(
                                            (a) => a.id == _selectedDestinationAccountId,
                                            orElse: () => Account(id: '', name: 'Unknown', type: '', balance: 0, icon: '', sortOrder: 0, isArchived: false, createdAt: DateTime.now()),
                                          ).name}'
                                        : 'To',
                                    style: context.ts(
                                      13,
                                      fontWeight: FontWeight.bold,
                                      color: onSurface.withValues(alpha: 0.87),
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing4),
                                  Icon(
                                    PesaFlowIcons.chevronDown,
                                    color: onSurface.withValues(alpha: 0.54),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Numeric Keypad Grid (Cupertino Calculator replacement)
                  StaggeredFadeSlide(
                    index: 3,
                    child: CalculatorNumpad(
                      initialValue: _amountStr,
                      onValueChanged: (val) {
                        setState(() {
                          _amountStr = val;
                          _amountError = null;
                        });
                      },
                      onConfirm: () => _showSecondaryDetailsSheet(context),
                    ),
                  ),
                  SizedBox(height: context.isCompactView ? 16 : 24),

                  // Continue Button
                  StaggeredFadeSlide(
                    index: 4,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing,
                        vertical: kSpacing12,
                      ),
                      child: TactileSpringContainer(
                        onTap: () => _showSecondaryDetailsSheet(context),
                        child: Container(
                          width: double.infinity,
                          height: context.isCompactView ? 44 : 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.8,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Continue',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpacing16),

                  // Templates button
                  if (!_isEditMode)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing,
                      ),
                      child: TactileSpringContainer(
                        onTap: () => _showTemplatePickerSheet(context),
                        child: Container(
                          width: double.infinity,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: onSurface.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PesaFlowIcons.bookmark,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: kSpacing8),
                              Text(
                                'Templates',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: kSpacing16),
                ],
              ),
            ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final textColor = onSurface;

    return Row(
      children: keys.asMap().entries.map((entry) {
        final key = entry.value;

        final keypadButton = KeypadButton(
          text: key,
          onTap: () => _keypadPress(key),
          height: context.isCompactView ? 60 : 78,
          textColor: textColor,
        );

        return Expanded(
          child: key == '<'
              ? GestureDetector(
                  onLongPress: () {
                    HapticFeedback.vibrate();
                    setState(() => _amountStr = '0');
                  },
                  child: keypadButton,
                )
              : keypadButton,
        );
      }).toList(),
    );
  }
}

class KeypadButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final double height;
  final Color textColor;

  const KeypadButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.height,
    required this.textColor,
  });

  @override
  State<KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<KeypadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown() {
    _pressController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp() {
    _pressController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSpecialKey = widget.text == '<' || widget.text == '.';

    final Color baseBg = isSpecialKey
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
        : theme.colorScheme.surfaceContainerHigh;

    final Color activeBg = isSpecialKey
        ? theme.colorScheme.primary.withValues(alpha: 0.16)
        : theme.colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) {
        final scale = _scaleAnimation.value;
        final bg = Color.lerp(baseBg, activeBg, _pressController.value);

        return Transform.scale(
          scale: scale,
          child: Padding(
            padding: const EdgeInsets.all(kSpacing4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _onTapDown(),
              onTapUp: (_) => _onTapUp(),
              onTapCancel: () => _onTapCancel(),
              child: Container(
                height: widget.height - kSpacing8,
                decoration: ShapeDecoration(
                  color: bg,
                  shape: SquircleBorder(
                    side: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                      width: 0.6,
                    ),
                    borderRadius: 14.0,
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.03 * (1.0 - _pressController.value),
                      ),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Center(
        child: widget.text == '<'
            ? Icon(PesaFlowIcons.backspace, color: widget.textColor, size: 20)
            : Text(
                widget.text,
                style: context.ts(
                  22,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM DYNAMIC KEYPAD SPRING MONOSPACE TEXT
// ════════════════════════════════════════════════════════════════════════════
class KeypadSpringText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const KeypadSpringText({super.key, required this.text, required this.style});

  @override
  State<KeypadSpringText> createState() => _KeypadSpringTextState();
}

class _KeypadSpringTextState extends State<KeypadSpringText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.93,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.93,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant KeypadSpringText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(widget.text, style: widget.style),
    );
  }
}
