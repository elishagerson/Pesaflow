import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/recurring_transaction_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class RecurringTransactionFormScreen extends ConsumerStatefulWidget {
  final String? recurringId;

  const RecurringTransactionFormScreen({super.key, this.recurringId});

  @override
  ConsumerState<RecurringTransactionFormScreen> createState() =>
      _RecurringTransactionFormScreenState();
}

class _RecurringTransactionFormScreenState
    extends ConsumerState<RecurringTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _keywordsController = TextEditingController();

  String? _selectedAccountId;
  String? _selectedCategoryId;
  String _type = 'expense';
  String _frequency = 'monthly';
  DateTime _nextDate = DateTime.now();
  DateTime? _endDate;

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.recurringId != null) {
      _isEditing = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(recurringTransactionRepositoryProvider);
    final existing = await repo.getById(widget.recurringId!);
    if (existing == null || !mounted) return;
    setState(() {
      _selectedAccountId = existing.accountId;
      _selectedCategoryId = existing.categoryId;
      _amountController.text = (existing.amount ~/ 100).toString();
      _type = existing.type;
      _descriptionController.text = existing.description ?? '';
      _frequency = existing.frequency;
      _intervalController.text = existing.intervalValue.toString();
      _nextDate = existing.nextDate;
      _endDate = existing.endDate;
      _keywordsController.text = existing.merchantKeywords ?? '';
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool endDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate
          ? (_endDate ?? now.add(const Duration(days: 365)))
          : (_nextDate.isBefore(now) ? now : _nextDate),
      firstDate: endDate ? _nextDate : DateTime(2020),
      lastDate: endDate
          ? now.add(const Duration(days: 365 * 10))
          : now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        if (endDate) {
          _endDate = picked;
        } else {
          _nextDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an account')));
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isLoading = true);

    final amountCents = CurrencyFormatter.parseToCents(_amountController.text);
    if (amountCents <= 0) {
      setState(() => _isLoading = false);
      return;
    }

    final interval = int.tryParse(_intervalController.text) ?? 1;
    final activeTrackerId = ref.read(activeTrackerIdProvider);

    if (_isEditing) {
      final existing = await ref
          .read(recurringTransactionRepositoryProvider)
          .getById(widget.recurringId!);
      if (existing == null) return;
      final updated = existing.copyWith(
        accountId: _selectedAccountId,
        categoryId: Value(_selectedCategoryId),
        amount: amountCents,
        type: _type,
        description: Value(
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
        frequency: _frequency,
        intervalValue: interval,
        nextDate: _nextDate,
        endDate: Value(_endDate),
        merchantKeywords: Value(
          _keywordsController.text.trim().isEmpty
              ? null
              : _keywordsController.text.trim(),
        ),
        updatedAt: DateTime.now(),
      );
      try {
        await ref
            .read(recurringTransactionRepositoryProvider)
            .updateRecurringTransaction(updated);
        if (!mounted) return;
        context.pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update recurring transaction: $e')),
        );
      }
    } else {
      final recurringId = const Uuid().v4();
      final recurring = RecurringTransaction(
        id: recurringId,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId,
        amount: amountCents,
        type: _type,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        frequency: _frequency,
        intervalValue: interval,
        nextDate: _nextDate,
        endDate: _endDate,
        status: 'active',
        trackerId: activeTrackerId,
        merchantKeywords: _keywordsController.text.trim().isEmpty
            ? null
            : _keywordsController.text.trim(),
        totalPaid: 0,
        paymentCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      try {
        await ref
            .read(recurringTransactionRepositoryProvider)
            .createRecurringTransaction(recurring);
        if (!mounted) return;
        context.pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create recurring transaction: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputFill = isDark
        ? const Color(0xFF1B1C22)
        : const Color(0xFFF2F2F7);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recurring' : 'Add Recurring'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredFadeSlide(
                index: 0,
                child: accountsAsync.when(
                  data: (accounts) => DropdownButtonFormField<String>(
                    initialValue: _selectedAccountId,
                    decoration: InputDecoration(
                      labelText: 'Account',
                      prefixIcon: const Icon(PesaFlowIcons.loans, size: 18),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    validator: (v) => v == null ? 'Select an account' : null,
                  ),
                  loading: () => const SizedBox(
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Text(
                    'Error: $e',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 1,
                child: categoriesAsync.when(
                  data: (categories) {
                    final filtered = categories
                        .where((c) => c.type == _type)
                        .toList();
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: const Icon(
                          Icons.category_rounded,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: filtered
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                      validator: (v) => v == null ? 'Select a category' : null,
                    );
                  },
                  loading: () => const SizedBox(
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Text(
                    'Error: $e',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 2,
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (Tsh)',
                    hintText: 'e.g. 50000',
                    prefixIcon: const Icon(Icons.money_rounded, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter amount';
                    final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
                    final parsed = int.tryParse(cleaned);
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 3,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'income',
                      label: Text('Income', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 'expense',
                      label: Text('Expense', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 'transfer',
                      label: Text('Transfer', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (v) {
                    setState(() {
                      _type = v.first;
                      _selectedCategoryId = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 4,
                child: TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. Monthly rent',
                    prefixIcon: const Icon(PesaFlowIcons.edit, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              if (_type == 'expense') ...[
                const SizedBox(height: 16),
                StaggeredFadeSlide(
                  index: 4,
                  child: TextField(
                    controller: _keywordsController,
                    decoration: InputDecoration(
                      labelText: 'SMS Auto-Matching Keywords (optional)',
                      hintText: 'e.g. netflix, spotify (comma separated)',
                      prefixIcon: const Icon(Icons.key_rounded, size: 18),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 5,
                child: DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    prefixIcon: const Icon(
                      PesaFlowIcons.subscriptions,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(
                      value: 'biweekly',
                      child: Text('Biweekly'),
                    ),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(
                      value: 'quarterly',
                      child: Text('Quarterly'),
                    ),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _frequency = v);
                  },
                ),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 6,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Every',
                          hintText: '1',
                          prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                          filled: true,
                          fillColor: inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final parsed = int.tryParse(v);
                          if (parsed == null || parsed < 1) return 'Min 1';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _frequency == 'weekly'
                              ? 'week(s)'
                              : _frequency == 'biweekly'
                              ? 'two weeks'
                              : _frequency == 'monthly'
                              ? 'month(s)'
                              : _frequency == 'quarterly'
                              ? 'quarter(s)'
                              : 'year(s)',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 7,
                child: InkWell(
                  onTap: () => _pickDate(endDate: false),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Next Date',
                      prefixIcon: const Icon(PesaFlowIcons.calendar, size: 18),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_nextDate.day}/${_nextDate.month}/${_nextDate.year}',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 8,
                child: InkWell(
                  onTap: () => _pickDate(endDate: true),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'End Date (optional)',
                      prefixIcon: const Icon(PesaFlowIcons.calendar, size: 18),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _endDate != null
                              ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                              : 'Set end date',
                          style: TextStyle(
                            color: _endDate != null
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[400]),
                          ),
                        ),
                        if (_endDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _endDate = null),
                            child: Icon(
                              PesaFlowIcons.close,
                              size: 18,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              StaggeredFadeSlide(
                index: 9,
                child: TactileSpringContainer(
                  onTap: _isLoading ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isEditing ? 'Update Recurring' : 'Add Recurring',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
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
