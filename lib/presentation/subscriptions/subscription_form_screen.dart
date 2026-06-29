import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/subscription_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';

class SubscriptionFormScreen extends ConsumerStatefulWidget {
  final String? subscriptionId;
  const SubscriptionFormScreen({super.key, this.subscriptionId});

  @override
  ConsumerState<SubscriptionFormScreen> createState() => _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends ConsumerState<SubscriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _amountController = TextEditingController();
  String _frequency = 'monthly';
  int _intervalValue = 1;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _nextDueDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.subscriptionId != null) _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final sub = await repo.getById(widget.subscriptionId!);
    if (sub != null && mounted) {
      _nameController.text = sub.name;
      _keywordsController.text = sub.merchantKeywords;
      _amountController.text = (sub.amount / 100).toStringAsFixed(0);
      _frequency = sub.frequency;
      _intervalValue = sub.intervalValue;
      _selectedCategoryId = sub.categoryId;
      _selectedAccountId = sub.accountId.isEmpty ? null : sub.accountId;
      _nextDueDate = sub.nextDueDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keywordsController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final amountCents = CurrencyFormatter.parseToCents(_amountController.text);
      final now = DateTime.now();

      if (widget.subscriptionId != null) {
        final existing = await repo.getById(widget.subscriptionId!);
        if (existing != null) {
          await repo.updateSubscription(existing.copyWith(
            name: _nameController.text,
            merchantKeywords: _keywordsController.text,
            amount: amountCents,
            frequency: _frequency,
            intervalValue: _intervalValue,
            categoryId: _selectedCategoryId != null ? Value(_selectedCategoryId) : const Value(null),
            accountId: _selectedAccountId!,
            nextDueDate: _nextDueDate,
            updatedAt: now,
          ));
        }
      } else {
        await repo.createSubscription(Subscription(
          id: const Uuid().v4(),
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId,
          amount: amountCents,
          name: _nameController.text,
          merchantKeywords: _keywordsController.text,
          frequency: _frequency,
          intervalValue: _intervalValue,
          nextDueDate: _nextDueDate,
          lastPaidDate: null,
          totalPaid: 0,
          paymentCount: 0,
          status: 'active',
          trackerId: null,
          createdAt: now,
          updatedAt: now,
        ));
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsStreamProvider);

    // Auto-select first account if not set yet
    accountsAsync.whenData((accounts) {
      if (_selectedAccountId == null && accounts.isNotEmpty && widget.subscriptionId == null) {
        setState(() {
          _selectedAccountId = accounts.first.id;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.subscriptionId != null ? 'Edit Subscription' : 'Add Subscription')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(kSpacing16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Service name', hintText: 'Netflix, Spotify, DStv...'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: kSpacing16),
            accountsAsync.when(
              data: (accounts) {
                return ModernDropdown<String>(
                  labelText: 'Account',
                  value: _selectedAccountId,
                  prefixIcon: Icons.account_balance_rounded,
                  items: accounts.map((a) => ModernDropdownItem<String>(
                    value: a.id,
                    label: a.name,
                    subtitle: a.type.toUpperCase().replaceAll('_', ' '),
                    icon: Icons.account_balance_wallet_rounded,
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading accounts: $e'),
            ),
            const SizedBox(height: kSpacing16),
            Consumer(builder: (context, watchRef, _) {
              final catsAsync = watchRef.watch(categoriesFutureProvider);
              return catsAsync.when(
                data: (cats) {
                  final expenseCats = cats.where((c) => c.type == 'expense').toList();
                  return ModernDropdown<String>(
                    labelText: 'Category (optional)',
                    value: _selectedCategoryId,
                    prefixIcon: Icons.category_rounded,
                    items: [
                      const ModernDropdownItem<String>(value: '', label: 'None', icon: Icons.block, color: Colors.grey),
                      ...expenseCats.map((c) => ModernDropdownItem<String>(
                        value: c.id,
                        label: c.name,
                        icon: getCategoryIcon(c.icon),
                        color: hexToColor(c.color),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedCategoryId = v == '' ? null : v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              );
            }),
            const SizedBox(height: kSpacing16),
            TextFormField(
              controller: _keywordsController,
              decoration: const InputDecoration(
                labelText: 'SMS keywords',
                hintText: 'netflix,nflx,stream',
                helperText: 'Comma-separated — matched against SMS text',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: kSpacing16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (TZS)', hintText: '15000'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: kSpacing16),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
            ),
            const SizedBox(height: kSpacing16),
            Row(
              children: [
                Text('Every', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                const SizedBox(width: kSpacing8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    initialValue: _intervalValue.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: kSpacing8, vertical: kSpacing8),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) setState(() => _intervalValue = n);
                    },
                  ),
                ),
                const SizedBox(width: kSpacing8),
                Text(_frequencyLabel(_frequency), style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextDueDate.isBefore(now) ? now : _nextDueDate,
                  firstDate: DateTime(2020),
                  lastDate: now.add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  setState(() => _nextDueDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Next Due Date',
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_nextDueDate.day}/${_nextDueDate.month}/${_nextDueDate.year}',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.subscriptionId != null ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  String _frequencyLabel(String frequency) {
    return switch (frequency) {
      'weekly' => 'weeks',
      'biweekly' => 'weeks',
      'monthly' => 'months',
      'quarterly' => 'months',
      'yearly' => 'years',
      _ => frequency,
    };
  }
}
