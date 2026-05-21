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
import 'package:pesaflow/presentation/state/state_providers.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;

  const TransactionFormScreen({super.key, this.transactionId});

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();

  String _transactionType = 'Expense'; // Default
  String? _selectedAccountId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  bool _isEditMode = false;
  bool _isLoading = false;
  Transaction? _existingTransaction;

  final List<String> _expenseSuggestions = ['Lunch', 'Taxi / Uber', 'Data Bundle', 'Electricity Luku', 'Groceries', 'Rent', 'Water Bill'];
  final List<String> _incomeSuggestions = ['Salary Paycheck', 'Business Sale', 'Freelance Project', 'Allowance', 'Interest / Yield'];

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
    // Fetch transaction by ID
    final repo = ref.read(transactionRepositoryProvider);
    // Since we stream filtered transactions, we can watch them, or retrieve the list
    // Wait, let's just watch recent transactions and look for our matching ID
    final list = await repo.watchRecentTransactions(100).first;
    final match = list.firstWhere((item) => item.transaction.id == widget.transactionId);
    
    _existingTransaction = match.transaction;
    _amountController.text = (match.transaction.amount / 100.0).toStringAsFixed(0);
    _descriptionController.text = match.transaction.description;
    _referenceController.text = match.transaction.reference ?? '';
    _selectedAccountId = match.transaction.accountId;
    _selectedCategoryId = match.transaction.categoryId;
    _transactionType = match.transaction.type[0].toUpperCase() + match.transaction.type.substring(1).toLowerCase();
    _selectedDate = match.transaction.createdAt;
    
    setState(() => _isLoading = false);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
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

    final double amountVal = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    if (amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than zero.')),
      );
      return;
    }

    final cents = (amountVal * 100).round();
    final repo = ref.read(transactionRepositoryProvider);

    setState(() => _isLoading = true);

    if (_isEditMode && _existingTransaction != null) {
      // Safely perform edit: delete old transaction (which reverses balance changes) and insert new transaction
      await repo.deleteTransaction(_existingTransaction!.id);
    }

    final newTransaction = Transaction(
      id: _isEditMode ? _existingTransaction!.id : const Uuid().v4(),
      accountId: _selectedAccountId!,
      categoryId: _selectedCategoryId!,
      amount: cents,
      type: _transactionType.toLowerCase(),
      description: _descriptionController.text.trim(),
      reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      source: 'manual',
      createdAt: _selectedDate,
      updatedAt: DateTime.now(),
    );

    await repo.createTransaction(newTransaction);

    // Invalidate state providers so UI fetches fresh streams
    ref.invalidate(accountsStreamProvider);
    ref.invalidate(recentTransactionsStreamProvider);
    ref.invalidate(filteredTransactionsStreamProvider);
    ref.invalidate(netWorthProvider);

    setState(() => _isLoading = false);

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesFutureProvider).value ?? [];
    
    // Filter categories depending on selected transaction type
    final filteredCategories = categories.where((cat) {
      return cat.type.toLowerCase() == _transactionType.toLowerCase();
    }).toList();

    // Default account selection helper
    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    // Default category selection helper based on filtered lists
    if (_selectedCategoryId == null && filteredCategories.isNotEmpty) {
      _selectedCategoryId = filteredCategories.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'Record Transaction'),
      ),
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
                          'You must create at least one local Cash, Bank or Mobile Money account before recording manual transactions.',
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
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Segmented toggle
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Expense')),
                                  selected: _transactionType == 'Expense',
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() {
                                        _transactionType = 'Expense';
                                        _selectedCategoryId = null; // force recalculation
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Income')),
                                  selected: _transactionType == 'Income',
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() {
                                        _transactionType = 'Income';
                                        _selectedCategoryId = null; // force recalculation
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Large Visual Money Input Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? AppTheme.surfaceContainerDark
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                              border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0x1FFFFFFF)
                                    : const Color(0x1F000000),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AMOUNT (TZS)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                  decoration: const InputDecoration(
                                    prefixText: 'Tsh ',
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Account Selector
                          const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedAccountId,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12.0)),
                            items: accounts.map((acc) {
                              return DropdownMenuItem(
                                value: acc.id,
                                child: Text('${acc.name} (${CurrencyFormatter.formatCents(acc.balance)})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedAccountId = val;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Category Selector
                          const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12.0)),
                            items: filteredCategories.map((cat) {
                              return DropdownMenuItem(
                                value: cat.id,
                                child: Text(cat.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Date Field
                          const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? AppTheme.surfaceDark
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const Icon(Icons.calendar_month_rounded, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Description
                          const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Lunch with team, monthly data',
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Interactive Suggestion Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: (_transactionType == 'Expense'
                                      ? _expenseSuggestions
                                      : _incomeSuggestions)
                                  .map((suggestion) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ActionChip(
                                    label: Text(suggestion),
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
                          const SizedBox(height: 20),

                          // Carrier Reference (Optional)
                          const Text('Carrier Reference (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _referenceController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'e.g. P65AB1C2D (M-Pesa ID)',
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveForm,
                              child: Text(_isEditMode ? 'Update' : 'Save'),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
