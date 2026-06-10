import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  final String? budgetId;
  const BudgetFormScreen({this.budgetId, super.key});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _capController = TextEditingController();
  String? _selectedCategoryId;
  String _period = 'monthly';
  bool _rollover = false;
  String _rolloverType = 'none';
  double _threshold = 0.8;
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.budgetId != null) _loadExistingBudget();
  }

  Future<void> _loadExistingBudget() async {
    final budget = await ref.read(budgetRepositoryProvider).getBudgetById(widget.budgetId!);
    if (budget != null && mounted) {
      setState(() {
        _nameController.text = budget.name;
        _amountController.text = (budget.amount ~/ 100).toString();
        _selectedCategoryId = budget.categoryId;
        _period = budget.period;
        _rollover = budget.rollover;
        _rolloverType = budget.rolloverType;
        _threshold = budget.notificationThreshold;
        _startDate = budget.startDate;
        if (budget.rolloverCap != null) _capController.text = (budget.rolloverCap! ~/ 100).toString();
      });
    }
  }

  @override
  void dispose() { _nameController.dispose(); _amountController.dispose(); _capController.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      if (_selectedCategoryId == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(budgetRepositoryProvider);
      final amountCents = (int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) * 100;
      int? rolloverCap;
      if (_rollover && _rolloverType == 'capped' && _capController.text.isNotEmpty) {
        rolloverCap = (int.tryParse(_capController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) * 100;
      }
      if (widget.budgetId != null) {
        final existing = await repo.getBudgetById(widget.budgetId!);
        if (existing != null) {
          await repo.updateBudget(existing.copyWith(name: _nameController.text.trim(), categoryId: _selectedCategoryId!, period: _period, amount: amountCents, rollover: _rollover, rolloverType: _rolloverType, notificationThreshold: _threshold));
        }
      } else {
        await repo.createBudget(name: _nameController.text.trim(), categoryId: _selectedCategoryId!, period: _period, amount: amountCents, rollover: _rollover, rolloverType: _rolloverType, rolloverCap: rolloverCap, startDate: _startDate, notificationThreshold: _threshold);
      }
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(activeBudgetsStreamProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final isEditing = widget.budgetId != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            IosNavBar(
              title: isEditing ? 'Edit Budget' : 'New Budget',
              largeTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      IosListSection(
                        header: 'Details',
                        rows: [
                          IosListRow(
                            title: TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Budget Name', hintText: 'e.g. Monthly Food', prefixIcon: Icon(Icons.label_rounded), border: InputBorder.none),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      categoriesAsync.when(
                        data: (cats) => ModernDropdown<String>(
                          labelText: 'Category',
                          value: _selectedCategoryId,
                          prefixIcon: Icons.category_rounded,
                          items: cats
                              .where((c) => c.type == 'expense')
                              .map((c) => ModernDropdownItem<String>(
                                    value: c.id,
                                    label: c.name,
                                    icon: getCategoryIcon(c.icon),
                                    color: hexToColor(c.color),
                                    subtitle: 'Budget category for ${c.name}',
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                      const SizedBox(height: 8),
                      IosListSection(
                        header: 'Amount',
                        rows: [
                          IosListRow(
                            title: TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Budget Amount (Tsh)', hintText: 'e.g. 300000', prefixIcon: Icon(Icons.payments_rounded), border: InputBorder.none),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Amount required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                            border: Border.all(color: theme.brightness == Brightness.dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'weekly', label: Text('Week')),
                              ButtonSegment(value: 'biweekly', label: Text('2 Wk')),
                              ButtonSegment(value: 'monthly', label: Text('Month')),
                              ButtonSegment(value: 'yearly', label: Text('Year')),
                            ],
                            selected: {_period},
                            onSelectionChanged: (v) => setState(() => _period = v.first),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      IosListSection(
                        header: 'Schedule',
                        rows: [
                          IosListRow(
                            title: const Text('Start Date'),
                            subtitle: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (d != null) setState(() => _startDate = d);
                            },
                          ),
                        ],
                      ),
                      IosListSection(
                        header: 'Rollover',
                        rows: [
                      IosListRow(
                        title: const Text('Enable Rollover'),
                        subtitle: const Text('Unused budget carries to next period'),
                        trailing: CupertinoSwitch(
                          value: _rollover,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (v) => setState(() => _rollover = v),
                        ),
                      ),
                        ],
                      ),
                      if (_rollover) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                              border: Border.all(color: theme.brightness == Brightness.dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'all', label: Text('All')),
                                ButtonSegment(value: 'capped', label: Text('Capped')),
                              ],
                              selected: {_rolloverType == 'none' ? 'all' : _rolloverType},
                              onSelectionChanged: (v) => setState(() => _rolloverType = v.first),
                            ),
                          ),
                        ),
                        if (_rolloverType == 'capped')
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: TextFormField(
                              controller: _capController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Max Rollover (Tsh)', prefixIcon: Icon(Icons.upcoming_rounded)),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Alert Threshold', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          borderRadius: AppTheme.radiusCard,
                          elevation: CardElevation.medium,
                          child: Column(children: [
                            Text('${(_threshold * 100).round()}%', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                            Slider(value: _threshold, min: 0.5, max: 1.0, divisions: 10, label: '${(_threshold * 100).round()}%', onChanged: (v) => setState(() => _threshold = v)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(isEditing ? 'Update Budget' : 'Create Budget'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
