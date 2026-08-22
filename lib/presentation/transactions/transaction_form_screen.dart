import 'package:flutter/cupertino.dart';

import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/add_category_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_typography_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

import 'package:pesaflow/data/database/app_database.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/presentation/common/widgets/modern_numpad.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';

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
  bool _isSaving = false;
  bool _isLoading = false;
  final bool _saveAsTemplate = false;
  Transaction? _existingTransaction;



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

      if (mounted) {
        if (context.canPop()) context.pop();
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
  

  void _showCategorySheet(BuildContext context, ThemeData theme, AsyncValue<List<dynamic>> categoriesAsync) {
    IosBottomSheet.show(
      context: context,
      initialChildSize: 0.6,
      maxChildSize: 0.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: kSpacing16),
            Text(
              'Select Category',
              style: context.ts(20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: kSpacing24),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  final filteredCategories = categories.where((cat) {
                    return cat.type.toLowerCase() == _transactionType.toLowerCase();
                  }).toList();

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: kSpacing24,
                      crossAxisSpacing: kSpacing16,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: filteredCategories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filteredCategories.length) {
                        return GestureDetector(
                          onTap: () async {
                            final newCat = await showAddCategoryDialog(
                              context,
                              ref,
                              initialType: _transactionType,
                            );
                            if (newCat != null) {
                              _lastCategoryByType[_transactionType] = newCat.id;
                              setState(() => _selectedCategoryId = newCat.id);
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(PesaFlowIcons.add, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(height: kSpacing8),
                              Text('Custom', style: context.ts(12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }

                      final cat = filteredCategories[index];
                      final color = hexToColor(cat.color);
                      final isSelected = cat.id == _selectedCategoryId;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _lastCategoryByType[_transactionType] = cat.id;
                            _selectedCategoryId = cat.id;
                          });
                          Navigator.pop(context);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.2) : theme.colorScheme.onSurface.withValues(alpha: 0.03),
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: color, width: 2) : null,
                              ),
                              child: Icon(getCategoryIcon(cat.icon), color: isSelected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                            const SizedBox(height: kSpacing8),
                            Text(
                              cat.name,
                              style: context.ts(11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteSheet(BuildContext context, ThemeData theme) {
    IosBottomSheet.show(
      context: context,
      initialChildSize: 0.4,
      maxChildSize: 0.6,
      child: Padding(
        padding: EdgeInsets.only(
          left: kSpacing16,
          right: kSpacing16,
          top: kSpacing16,
          bottom: MediaQuery.of(context).viewInsets.bottom + kSpacing16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add a Note', style: context.ts(20, fontWeight: FontWeight.bold)),
            const SizedBox(height: kSpacing24),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              style: context.ts(16),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'What was this for?',
                filled: true,
                fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: kSpacing24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Done', style: context.ts(16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePickerSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            SizedBox(
              height: 190,
              child: CupertinoDatePicker(
                initialDateTime: _selectedDate,
                mode: CupertinoDatePickerMode.date,
                onDateTimeChanged: (val) {
                  setState(() => _selectedDate = val);
                },
              ),
            ),
            CupertinoButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    
    final selectedCatObj = _selectedCategoryId != null 
        ? categoriesAsync.value?.where((c) => c.id == _selectedCategoryId).firstOrNull 
        : null;
        
    final amt = _amountController.text.isEmpty ? '0' : NumberFormat('#,###').format(int.tryParse(_amountController.text) ?? 0);
    final amtColor = _transactionType == 'Expense' ? context.appColors.expenseColor : (_transactionType == 'Income' ? context.appColors.incomeColor : context.appColors.transferColor);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'New Transaction', style: context.ts(18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PesaFlowIcons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // TOP HALF: Display & Context
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Segmented Control
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: kSpacing32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.all(kSpacing4),
                    child: CupertinoSlidingSegmentedControl<String>(
                      backgroundColor: Colors.transparent,
                      thumbColor: theme.colorScheme.surface,
                      groupValue: _transactionType,
                      children: {
                        'Expense': Padding(
                          padding: const EdgeInsets.symmetric(horizontal: kSpacing16, vertical: kSpacing10),
                          child: Text('Expense', style: context.ts(14, fontWeight: FontWeight.w600, color: _transactionType == 'Expense' ? context.appColors.expenseColor : theme.colorScheme.onSurfaceVariant)),
                        ),
                        'Income': Padding(
                          padding: const EdgeInsets.symmetric(horizontal: kSpacing16, vertical: kSpacing10),
                          child: Text('Income', style: context.ts(14, fontWeight: FontWeight.w600, color: _transactionType == 'Income' ? context.appColors.incomeColor : theme.colorScheme.onSurfaceVariant)),
                        ),
                        'Transfer': Padding(
                          padding: const EdgeInsets.symmetric(horizontal: kSpacing16, vertical: kSpacing10),
                          child: Text('Transfer', style: context.ts(14, fontWeight: FontWeight.w600, color: _transactionType == 'Transfer' ? context.appColors.transferColor : theme.colorScheme.onSurfaceVariant)),
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
                  
                  const Spacer(),
                  
                  // Massive Hero Amount
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpacing24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        amt,
                        style: context.ts(72, fontWeight: FontWeight.w900, color: amtColor, letterSpacing: -2),
                      ),
                    ),
                  ),
                  if (_amountError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: kSpacing8),
                      child: Text(_amountError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 14, fontWeight: FontWeight.w500)),
                    ),

                  const SizedBox(height: kSpacing16),
                  
                  // Category Pill
                  TactileSpringContainer(
                    onTap: () => _showCategorySheet(context, theme, categoriesAsync),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: kSpacing16, vertical: kSpacing10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedCatObj != null) ...[
                            Icon(getCategoryIcon(selectedCatObj.icon), color: hexToColor(selectedCatObj.color), size: 18),
                            const SizedBox(width: kSpacing8),
                            Text(selectedCatObj.name, style: context.ts(16, fontWeight: FontWeight.w600)),
                          ] else ...[
                            Icon(PesaFlowIcons.category, color: theme.colorScheme.onSurfaceVariant, size: 18),
                            const SizedBox(width: kSpacing8),
                            Text('Select Category', style: context.ts(16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                          const SizedBox(width: kSpacing4),
                          Icon(Icons.keyboard_arrow_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Quick Action Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: kSpacing24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ActionChip(
                          avatar: const Icon(PesaFlowIcons.calendar, size: 16),
                          label: Text((_selectedDate.year == DateTime.now().year && _selectedDate.month == DateTime.now().month && _selectedDate.day == DateTime.now().day) ? 'Today' : DateFormat('MMM d').format(_selectedDate)),
                          onPressed: () => _showDatePickerSheet(context),
                          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        const SizedBox(width: kSpacing8),
                        ActionChip(
                          avatar: const Icon(PesaFlowIcons.label, size: 16),
                          label: Text(_descriptionController.text.isEmpty ? 'Note' : 'Note Added'),
                          onPressed: () => _showNoteSheet(context, theme),
                          backgroundColor: _descriptionController.text.isNotEmpty ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.03),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        const SizedBox(width: kSpacing8),
                        ActionChip(
                          avatar: const Icon(PesaFlowIcons.wallet, size: 16),
                          label: Text(accounts.where((a) => a.id == _selectedAccountId).firstOrNull?.name ?? 'Account'),
                          onPressed: () => _showAccountPickerSheet(context, accounts),
                          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kSpacing16),
                ],
              ),
            ),
            
            // BOTTOM HALF: Integrated Numpad
            ModernNumpad(
              controller: _amountController,
              isDoneLoading: _isSaving,
              doneLabel: 'Save',
              onDone: _isSaving ? null : _saveTransaction,
            ),
          ],
        ),
      ),
    );
  }
}
