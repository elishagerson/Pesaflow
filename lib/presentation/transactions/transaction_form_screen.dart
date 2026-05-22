import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/dashboard/dashboard_screen.dart'; // To reuse TactileSpringContainer!

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
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();

  bool _isEditMode = false;
  bool _isLoading = false;
  Transaction? _existingTransaction;

  final List<String> _expenseSuggestions = ['Lunch', 'Transport / Taxi', 'Airtime Bundle', 'Electricity Luku', 'Groceries', 'Rent', 'Water Bill'];
  final List<String> _incomeSuggestions = ['Salary Paycheck', 'Business Sale', 'Freelance gig', 'Allowance', 'Dividends / Interest'];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.transactionId != null;
    if (_isEditMode) {
      _loadExistingTransaction();
    }
  }

  Future<void> _loadExistingTransaction() async {
    setState(() => _isLoading = true);
    final repo = ref.read(transactionRepositoryProvider);
    final list = await repo.watchRecentTransactions(100).first;
    final match = list.firstWhere((item) => item.transaction.id == widget.transactionId);
    
    _existingTransaction = match.transaction;
    
    // Convert cents back to decimal base string
    final double baseValue = match.transaction.amount / 100.0;
    _amountStr = baseValue % 1 == 0 ? baseValue.toInt().toString() : baseValue.toString();
    
    _descriptionController.text = match.transaction.description;
    _referenceController.text = match.transaction.reference ?? '';
    _selectedAccountId = match.transaction.accountId;
    _selectedCategoryId = match.transaction.categoryId;
    _transactionType = match.transaction.type[0].toUpperCase() + match.transaction.type.substring(1).toLowerCase();
    _selectedDate = match.transaction.createdAt;
    
    setState(() => _isLoading = false);
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
        const SnackBar(content: Text('Please select an account.')),
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

    if (_isEditMode && _existingTransaction != null) {
      await repo.deleteTransaction(_existingTransaction!.id);
    }

    final trackerId = ref.read(activeTrackerIdProvider);

    final newTransaction = Transaction(
      id: _isEditMode ? _existingTransaction!.id : const Uuid().v4(),
      accountId: _selectedAccountId!,
      categoryId: _selectedCategoryId!,
      trackerId: _isEditMode ? _existingTransaction!.trackerId : trackerId,
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
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
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
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
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
                            ? theme.colorScheme.primary.withOpacity(0.08) 
                            : AppTheme.surfaceContainerDark,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: isSelected 
                              ? theme.colorScheme.primary.withOpacity(0.3) 
                              : const Color(0x15FFFFFF),
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
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
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
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
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

                    // Category scroll list
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredCategories.length,
                        itemBuilder: (context, index) {
                          final cat = filteredCategories[index];
                          final isSel = cat.id == _selectedCategoryId;
                          final catColor = _hexToColor(cat.color);

                          return TactileSpringContainer(
                            onTap: () {
                              setSheetState(() => _selectedCategoryId = cat.id);
                              setState(() => _selectedCategoryId = cat.id);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8.0),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              decoration: BoxDecoration(
                                color: isSel ? catColor.withOpacity(0.12) : AppTheme.surfaceContainerDark,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: isSel ? catColor : const Color(0x15FFFFFF),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(_getCategoryIcon(cat.icon), color: isSel ? catColor : Colors.grey, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      color: isSel ? catColor : Colors.white70,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
                                : _incomeSuggestions)
                            .map((suggestion) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ActionChip(
                              label: Text(suggestion, style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppTheme.surfaceContainerDark,
                              side: const BorderSide(color: Color(0x15FFFFFF)),
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
                      decoration: const InputDecoration(
                        hintText: 'e.g. PP230489A1',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date input selector
                    const Text('Transaction Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setSheetState(() => _selectedDate = picked);
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x15FFFFFF)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const Icon(Icons.calendar_month_rounded, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
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

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return Colors.grey;
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'briefcase':
        return Icons.work_rounded;
      case 'store':
        return Icons.storefront_rounded;
      case 'cart':
        return Icons.shopping_cart_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'zap':
        return Icons.electric_bolt_rounded;
      case 'phone':
        return Icons.phone_android_rounded;
      case 'heart':
        return Icons.favorite_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'film':
        return Icons.movie_rounded;
      case 'shopping-bag':
        return Icons.shopping_bag_rounded;
      case 'coffee':
        return Icons.coffee_rounded;
      case 'send':
        return Icons.send_rounded;
      case 'credit-card':
        return Icons.credit_card_rounded;
      case 'banknote':
        return Icons.payments_rounded;
      case 'piggy-bank':
        return Icons.savings_rounded;
      case 'plus-circle':
      default:
        return Icons.add_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        width: 280,
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerDark,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: const Color(0x15FFFFFF)),
                        ),
                        child: Row(
                          children: [
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
                                        ? const Color(0xFF262626) 
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Expense',
                                      style: TextStyle(
                                        color: _transactionType == 'Expense' ? Colors.white : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
                                        ? const Color(0xFF262626) 
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Income',
                                      style: TextStyle(
                                        color: _transactionType == 'Income' ? Colors.white : Colors.grey,
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
                          child: Text(
                            'Tsh $formattedDisplay',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Floating source account pill
                      TactileSpringContainer(
                        onTap: () => _showAccountPickerSheet(context, accounts),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B1D),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: const Color(0x15FFFFFF)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'From ${activeAccount.name}',
                                style: const TextStyle(
                                  color: Colors.white70, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Numeric Keypad Grid (Edge-to-edge with elegant thin line grid dividers)
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0x12FFFFFF), width: 0.5),
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
                  top: const BorderSide(color: Color(0x12FFFFFF), width: 0.5),
                  right: index < 2
                      ? const BorderSide(color: Color(0x12FFFFFF), width: 0.5)
                      : BorderSide.none,
                ),
              ),
              child: Center(
                child: key == '<'
                    ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 20)
                    : Text(
                        key,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
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
