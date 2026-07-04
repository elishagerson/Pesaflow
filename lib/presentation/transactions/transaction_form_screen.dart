import 'dart:ui';
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
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/state/spending_pattern_provider.dart';
import 'package:pesaflow/presentation/common/widgets/squircle_border.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/press_scale.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  final String? initialType;

  const TransactionFormScreen({super.key, this.transactionId, this.initialType});

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
    } else if (widget.initialType != null) {
      final type = widget.initialType!.trim().toLowerCase();
      if (type == 'expense') {
        _transactionType = 'Expense';
        _selectedCategoryId = _lastCategoryByType['Expense'];
      } else if (type == 'income') {
        _transactionType = 'Income';
        _selectedCategoryId = _lastCategoryByType['Income'];
      } else if (type == 'transfer') {
        _transactionType = 'Transfer';
        _selectedCategoryId = _lastCategoryByType['Transfer'];
      }
    }
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

  double _getAmountCents() {
    return CurrencyFormatter.parseToCents(_amountStr).toDouble();
  }

  Future<void> _saveTransaction() async {
    final cents = _getAmountCents().round();
    if (cents <= 0) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a source account.')),
      );
      return;
    }
    if (_transactionType == 'Transfer' &&
        _selectedDestinationAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination account.')),
      );
      return;
    }
    if (_transactionType == 'Transfer' &&
        _selectedDestinationAccountId == _selectedAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination accounts must be different.'),
        ),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
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

    if (mounted) context.pop();

    try {
      if (existingTransaction != null) {
        await repo.deleteTransaction(existingTransaction.id);
      }
      await repo.createTransaction(newTransaction);

      HapticFeedback.mediumImpact();

      ref.invalidate(accountsStreamProvider);
      ref.invalidate(recentTransactionsStreamProvider);
      ref.invalidate(filteredTransactionsStreamProvider);
      ref.invalidate(netWorthProvider);
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save transaction: $e')));
    }
  }

  void _showAccountPickerSheet(BuildContext context, List<Account> accounts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
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
                        padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
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
                            padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
                            itemCount: accounts.length,
                            itemBuilder: (listCtx, index) {
                              final account = accounts[index];
                              final isSelected =
                                  account.id == _selectedAccountId;
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
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.08)
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
                                          padding: const EdgeInsets.all(kSpacing8),
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
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontSize: 15,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: isSelected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : onSurface
                                                                .withValues(
                                                                  alpha: 0.87,
                                                                ),
                                                    ),
                                              ),
                                              const SizedBox(height: kSpacing2),
                                              Text(
                                                'Balance: ${CurrencyFormatter.formatCents(account.balance)}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: onSurface
                                                          .withValues(
                                                            alpha: 0.38,
                                                          ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.all(kSpacing4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check_rounded,
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
          ),
        );
      },
    );
  }

  void _showDestinationAccountPickerSheet(
    BuildContext context,
    List<Account> accounts,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
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
                        padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
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
                                Icons.arrow_forward_rounded,
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
                            padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
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
                                            () =>
                                                _selectedDestinationAccountId =
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
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.08)
                                          : theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDisabled
                                            ? Colors.grey.withValues(
                                                alpha: 0.15,
                                              )
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
                                          padding: const EdgeInsets.all(kSpacing8),
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
                                                ? Icons.block_rounded
                                                : isSelected
                                                ? PesaFlowIcons.success
                                                : Icons.arrow_forward_rounded,
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
                                                    style: theme
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.copyWith(
                                                          fontSize: 15,
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
                                                              : onSurface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.87,
                                                                    ),
                                                        ),
                                                  ),
                                                  if (isDisabled) ...[
                                                    const SizedBox(width: kSpacing6),
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
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              fontSize: 10,
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
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
                                                      color: onSurface
                                                          .withValues(
                                                            alpha: 0.38,
                                                          ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.all(kSpacing4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check_rounded,
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
          ),
        );
      },
    );
  }

  void _showSecondaryDetailsSheet(
    BuildContext context,
    List<Category> categories,
  ) {
    final filteredCategories = categories.where((cat) {
      return cat.type.toLowerCase() == _transactionType.toLowerCase();
    }).toList();

    if (_selectedCategoryId == null && filteredCategories.isNotEmpty) {
      _selectedCategoryId = filteredCategories.first.id;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final onSurface = theme.colorScheme.onSurface;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              child: Container(
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
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.2,
                          ),
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: kSpacing12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.0,
                                ),
                            itemCount: filteredCategories.length,
                            itemBuilder: (context, index) {
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
                                  setState(() => _selectedCategoryId = cat.id);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? catColor.withValues(alpha: 0.15)
                                        : (theme.brightness == Brightness.dark
                                              ? const Color(0xFF1B1B1D)
                                              : Colors.grey.withValues(
                                                  alpha: 0.05,
                                                )),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontSize: 11,
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: kSpacing8),
                          TextField(
                            controller: _descriptionController,
                            textCapitalization: TextCapitalization.sentences,
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
                                      child: TactileSpringContainer(
                                        onTap: () {
                                          setSheetState(() {
                                            _descriptionController.text =
                                                suggestion;
                                          });
                                          setState(() {
                                            _descriptionController.text =
                                                suggestion;
                                          });
                                        },
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
                                          backgroundColor: onSurface.withValues(
                                            alpha: 0.05,
                                          ),
                                          side: BorderSide(
                                            color: onSurface.withValues(
                                              alpha: 0.08,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                          onPressed: () {},
                                        ),
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
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: kSpacing8),
                            TextField(
                              controller: _referenceController,
                              textCapitalization: TextCapitalization.characters,
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
                            shape: const SquircleBorder(
                              borderRadius: 24.0,
                            ),
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesFutureProvider).value ?? [];

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
    final double amountValue = double.tryParse(_amountStr) ?? 0.0;
    final String formattedDisplay = NumberFormat(
      '#,###.##',
    ).format(amountValue);

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
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
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
                      padding: const EdgeInsets.all(kSpacing4)),
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
                            child: GestureDetector(
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
                                      ? const Color(
                                          0xFFFF453A,
                                        ).withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(100),
                                  border: _transactionType == 'Expense'
                                      ? Border.all(
                                          color: const Color(0xFFFF453A),
                                          width: 1.2,
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Expense',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _transactionType == 'Expense'
                                          ? const Color(0xFFFF453A)
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Income pill
                          Expanded(
                            child: GestureDetector(
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
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
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
                            child: GestureDetector(
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
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
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
                          padding: const EdgeInsets.symmetric(horizontal: kSpacing24)),
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
                                  color: const Color(
                                    0xFF0F4C5C,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Usually ${CurrencyFormatter.formatCents(pattern.averageAmountCents)} at this time',
                                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Color(0xFF0F4C5C),
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
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface.withValues(alpha: 0.87),
                                  ),
                                ),
                                const SizedBox(width: kSpacing4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
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
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: onSurface.withValues(alpha: 0.87),
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
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

                  // Numeric Keypad Grid (Edge-to-edge with elegant thin line grid dividers)
                  StaggeredFadeSlide(
                    index: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: onSurface.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildKeypadRow(['1', '2', '3']),
                          _buildKeypadRow(['4', '5', '6']),
                          _buildKeypadRow(['7', '8', '9']),
                          _buildKeypadRow(['.', '0', '<']),
                        ],
                      ),
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
                      child: PressScale(
                        onTap: () =>
                            _showSecondaryDetailsSheet(context, categories),
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
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
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
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.onSurface.withValues(alpha: 0.04);

    final Color activeBg = isSpecialKey
        ? theme.colorScheme.primary.withValues(alpha: 0.24)
        : theme.colorScheme.onSurface.withValues(alpha: 0.12);

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
                      color: theme.colorScheme.outlineVariant,
                      width: 0.8,
                    ),
                    borderRadius: 16.0,
                  ),
                  shadows: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(
                        alpha: 0.04 * (1.0 - _pressController.value),
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
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
            ? Icon(
                Icons.backspace_outlined,
                color: widget.textColor,
                size: 20,
              )
            : Text(
                widget.text,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
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
