import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;

  const TransactionFormScreen({super.key, this.transactionId});

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  String _amountStr = '0'; // Current keypad entered digits
  String _transactionType = 'Expense'; // Default
  String? _selectedAccountId;
  String? _selectedDestinationAccountId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();

  bool _isEditMode = false;
  bool _isLoading = false;
  Transaction? _existingTransaction;

  final List<String> _expenseSuggestions = ['Lunch', 'Transport / Taxi', 'Airtime Bundle', 'Electricity Luku', 'Groceries', 'Rent', 'Water Bill'];
  final List<String> _incomeSuggestions = ['Salary Paycheck', 'Business Sale', 'Freelance gig', 'Allowance', 'Dividends / Interest'];
  final List<String> _transferSuggestions = ['To Savings Vault', 'To Bank Account', 'To Mobile Wallet', 'Card Payment / Settlement'];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.transactionId != null;
    if (_isEditMode) {
      _loadExistingTransaction();
    }
  }

  Future<void> _loadExistingTransaction() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final list = await repo.watchRecentTransactions(100).first;
      if (!mounted) return;
      final match = list.firstWhere(
        (item) => item.transaction.id == widget.transactionId,
        orElse: () => throw StateError('Transaction not found in recent list'),
      );

      _existingTransaction = match.transaction;

      final double baseValue = match.transaction.amount / 100.0;
      _amountStr = baseValue % 1 == 0 ? baseValue.toInt().toString() : baseValue.toString();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transaction: $e')),
      );
    }
  }

  void _keypadPress(String value) {
    setState(() {
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
    final clean = _amountStr.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = double.tryParse(clean) ?? 0.0;
    return parsed * 100.0;
  }

  Future<void> _saveTransaction() async {
    final cents = _getAmountCents().round();
    if (cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than zero.')),
      );
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a source account.')),
      );
      return;
    }
    if (_transactionType == 'Transfer' && _selectedDestinationAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination account.')),
      );
      return;
    }
    if (_transactionType == 'Transfer' && _selectedDestinationAccountId == _selectedAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination accounts must be different.')),
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
    setState(() => _isLoading = true);

    try {
      final existingTransaction = _isEditMode ? _existingTransaction : null;
      if (existingTransaction != null) {
        await repo.deleteTransaction(existingTransaction.id);
      }

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

      await repo.createTransaction(newTransaction);

      ref.invalidate(accountsStreamProvider);
      ref.invalidate(recentTransactionsStreamProvider);
      ref.invalidate(filteredTransactionsStreamProvider);
      ref.invalidate(netWorthProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save transaction: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (mounted) {
      context.pop();
    }
  }

  void _showAccountPickerSheet(BuildContext context, List<Account> accounts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceHighDark : AppTheme.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Text(
                'Select Source Account',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isSelected = account.id == _selectedAccountId;
                  return TactileSpringContainer(
                    onTap: () {
                      setState(() => _selectedAccountId = account.id);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.primary.withValues(alpha: 0.08) 
                            : (isDark ? AppTheme.surfaceContainerDark : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: isSelected 
                              ? theme.colorScheme.primary.withValues(alpha: 0.3) 
                              : (isDark ? const Color(0x15FFFFFF) : Colors.black.withValues(alpha: 0.08)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            account.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatCents(account.balance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? theme.colorScheme.primary : Colors.grey,
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
        );
      },
    );
  }

  void _showDestinationAccountPickerSheet(BuildContext context, List<Account> accounts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceHighDark : AppTheme.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Text(
                'Select Destination Account',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isSelected = account.id == _selectedDestinationAccountId;
                  final isSource = account.id == _selectedAccountId;
                  final isDisabled = isSource;
                  return TactileSpringContainer(
                    onTap: isDisabled ? null : () {
                      setState(() => _selectedDestinationAccountId = account.id);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.primary.withValues(alpha: 0.08) 
                            : (isDark ? AppTheme.surfaceContainerDark : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: isSelected 
                              ? theme.colorScheme.primary.withValues(alpha: 0.3) 
                              : (isDark ? const Color(0x15FFFFFF) : Colors.black.withValues(alpha: 0.08)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                account.name,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isDisabled ? Colors.grey : (isSelected ? theme.colorScheme.primary : null),
                                ),
                              ),
                              if (isDisabled) ...[
                                const SizedBox(width: 6),
                                const Text('(source)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ],
                          ),
                          Text(
                            CurrencyFormatter.formatCents(account.balance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? theme.colorScheme.primary : Colors.grey,
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
        );
      },
    );
  }

  void _showSecondaryDetailsSheet(BuildContext context, List<Category> categories) {
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
        final isDark = theme.brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceHighDark : AppTheme.surfaceLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
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
                    const SizedBox(height: 16),

                    // Category squircle grid selection
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                            setSheetState(() => _selectedCategoryId = cat.id);
                            setState(() => _selectedCategoryId = cat.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSel 
                                  ? catColor.withValues(alpha: 0.15) 
                                  : (theme.brightness == Brightness.dark 
                                      ? const Color(0xFF1B1B1D) 
                                      : Colors.grey.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSel ? catColor : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSel ? [
                                BoxShadow(
                                  color: catColor.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  getCategoryIcon(cat.icon),
                                  color: isSel ? catColor : (theme.brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Text(
                                    cat.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSel 
                                          ? (theme.brightness == Brightness.dark ? Colors.white : catColor) 
                                          : (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Description text input
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Lunch, taxi, data bundle',
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                    const SizedBox(height: 10),

                    // Suggestion chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: (_transactionType == 'Expense'
                                ? _expenseSuggestions
                                : (_transactionType == 'Income' ? _incomeSuggestions : _transferSuggestions))
                            .map((suggestion) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ActionChip(
                              label: Text(suggestion, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                              backgroundColor: isDark ? AppTheme.surfaceContainerDark : Colors.black.withValues(alpha: 0.05),
                              side: BorderSide(color: isDark ? const Color(0x15FFFFFF) : Colors.black.withValues(alpha: 0.08)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              onPressed: () {
                                setSheetState(() {
                                  _descriptionController.text = suggestion;
                                });
                                setState(() {
                                  _descriptionController.text = suggestion;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Carrier Reference field
                    const Text('Carrier Reference (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _referenceController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        hintText: 'e.g. PP230489A1',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date input selector
                    ModernDateSelector(
                      labelText: 'Transaction Date',
                      value: _selectedDate,
                      prefixIcon: Icons.calendar_today_rounded,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                      onChanged: (picked) {
                        setSheetState(() => _selectedDate = picked);
                        setState(() => _selectedDate = picked);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Final save record button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.scaffoldBackgroundColor,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _saveTransaction();
                        },
                        child: Text(_isEditMode ? 'Update Transaction' : 'Record Transaction'),
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
    final isDark = theme.brightness == Brightness.dark;
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesFutureProvider).value ?? [];

    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    final activeAccount = accounts.firstWhere(
      (acc) => acc.id == _selectedAccountId,
      orElse: () => accounts.isNotEmpty ? accounts.first : Account(
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
    final String formattedDisplay = NumberFormat('#,###.##').format(amountValue);

    // Font size scaling based on length
    final double fontSize = _amountStr.length > 10 ? 36.0 : (_amountStr.length > 7 ? 46.0 : 64.0);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : accounts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 64, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        const Text(
                          'No Accounts Available',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You must create at least one Account before recording manual transactions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Go to Dashboard'),
                        ),
                      ],
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
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      // Header Segment Toggle (internal styled pill like first screenshot)
                      const SizedBox(height: 16),
                      Container(
                        width: 320,
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceContainerDark : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: isDark ? const Color(0x15FFFFFF) : Colors.black.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            // Expense pill
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _transactionType = 'Expense';
                                  _selectedCategoryId = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                  decoration: BoxDecoration(
                                    color: _transactionType == 'Expense' 
                                        ? const Color(0xFFFF453A).withValues(alpha: 0.15) 
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                    border: _transactionType == 'Expense'
                                        ? Border.all(color: const Color(0xFFFF453A), width: 1.2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Expense',
                                      style: TextStyle(
                                        color: _transactionType == 'Expense' ? const Color(0xFFFF453A) : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
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
                                  _selectedCategoryId = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                  decoration: BoxDecoration(
                                    color: _transactionType == 'Income' 
                                        ? AppTheme.transferColorDark.withValues(alpha: 0.15) 
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                    border: _transactionType == 'Income'
                                        ? Border.all(color: AppTheme.transferColorDark, width: 1.2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Income',
                                      style: TextStyle(
                                        color: _transactionType == 'Income' ? AppTheme.transferColorDark : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
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
                                  _selectedCategoryId = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                  decoration: BoxDecoration(
                                    color: _transactionType == 'Transfer' 
                                        ? AppTheme.transferColorDark.withValues(alpha: 0.15) 
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                    border: _transactionType == 'Transfer'
                                        ? Border.all(color: AppTheme.transferColorDark, width: 1.2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Transfer',
                                      style: TextStyle(
                                        color: _transactionType == 'Transfer' ? AppTheme.transferColorDark : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Giant visual amount display
                      const Text(
                        'Amount',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: KeypadSpringText(
                            text: 'Tsh $formattedDisplay',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black,
                              fontFamily: 'monospace',
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TactileSpringContainer(
                            onTap: () => _showAccountPickerSheet(context, accounts),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1B1B1D) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: isDark ? const Color(0x15FFFFFF) : Colors.black.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'From ${activeAccount.name}',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.grey : Colors.black54, size: 18),
                                ],
                              ),
                            ),
                          ),
                          if (_transactionType == 'Transfer') ...[
                            const SizedBox(width: 8),
                            TactileSpringContainer(
                              onTap: () => _showDestinationAccountPickerSheet(context, accounts),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1B1B1D) : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: isDark ? const Color(0x15FFFFFF) : Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedDestinationAccountId != null
                                          ? 'To ${accounts.firstWhere((a) => a.id == _selectedDestinationAccountId, orElse: () => Account(id: '', name: 'Unknown', type: '', balance: 0, icon: '', sortOrder: 0, isArchived: false, createdAt: DateTime.now())).name}'
                                          : 'To',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black87, 
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.grey : Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),

                      // Numeric Keypad Grid (Edge-to-edge with elegant thin line grid dividers)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? const Color(0x12FFFFFF) : Colors.black.withValues(alpha: 0.08),
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
                      const SizedBox(height: 24),

                      // Continue Button (stark white visual CTA)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showSecondaryDetailsSheet(context, categories),
                            child: const Text('Continue'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? const Color(0x12FFFFFF) : Colors.black.withValues(alpha: 0.08);

    return Row(
      children: keys.asMap().entries.map((entry) {
        final index = entry.key;
        final key = entry.value;
        return Expanded(
          child: TactileSpringContainer(
            onTap: () => _keypadPress(key),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: dividerColor, width: 0.5),
                  right: index < 2
                      ? BorderSide(color: dividerColor, width: 0.5)
                      : BorderSide.none,
                ),
              ),
              child: Center(
                child: key == '<'
                    ? Icon(Icons.backspace_outlined, color: textColor, size: 20)
                    : Text(
                        key,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM DYNAMIC KEYPAD SPRING MONOSPACE TEXT
// ════════════════════════════════════════════════════════════════════════════
class KeypadSpringText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const KeypadSpringText({
    super.key,
    required this.text,
    required this.style,
  });

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
        tween: Tween<double>(begin: 1.0, end: 0.93)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.93, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
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
