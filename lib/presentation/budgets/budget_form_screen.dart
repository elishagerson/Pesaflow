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
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
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

  Widget _buildLeadingIcon(IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate() || _selectedCategoryId == null) {
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
    final isDark = theme.brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF1B1C22) : const Color(0xFFF2F2F7);
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final isEditing = widget.budgetId != null;

    Widget sectionLabel(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.4),
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    InputDecoration inputDeco({
      required String label,
      String? hint,
      IconData? icon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            IosNavBar(
              title: isEditing ? 'Edit Budget' : 'New Budget',
              largeTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
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
                      sectionLabel('BUDGET DETAILS'),
                      StaggeredFadeSlide(
                        index: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            borderRadius: AppTheme.radiusCard,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  decoration: inputDeco(label: 'Budget Name', hint: 'e.g. Monthly Food', icon: Icons.label_rounded),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                                ),
                                const SizedBox(height: 12),
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
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                                  decoration: inputDeco(label: 'Budget Amount (Tsh)', hint: 'e.g. 300000', icon: Icons.payments_rounded),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Amount required' : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      sectionLabel('PERIOD'),
                      StaggeredFadeSlide(
                        index: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GlassCard(
                            padding: const EdgeInsets.all(6),
                            borderRadius: AppTheme.radiusCard,
                            child: SegmentedButton<String>(
                              style: SegmentedButton.styleFrom(
                                side: BorderSide.none,
                                backgroundColor: Colors.transparent,
                                selectedBackgroundColor: theme.colorScheme.primary,
                                selectedForegroundColor: theme.colorScheme.onPrimary,
                              ),
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
                      ),
                      const SizedBox(height: 8),
                      sectionLabel('START DATE'),
                      StaggeredFadeSlide(
                        index: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GlassCard(
                            padding: const EdgeInsets.all(8),
                            borderRadius: AppTheme.radiusCard,
                            child: ModernDateSelector(
                              labelText: 'Start Date',
                              value: _startDate,
                              prefixIcon: Icons.calendar_today_rounded,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              onChanged: (d) => setState(() => _startDate = d),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      IosListSection(
                        header: 'ROLLOVER',
                        rows: [
                          IosListRow(
                            leading: _buildLeadingIcon(Icons.replay_rounded, Colors.purple),
                            title: const Text('Enable Rollover'),
                            subtitle: const Text('Unused budget carries to next period'),
                            trailing: CupertinoSwitch(
                              value: _rollover,
                              activeTrackColor: theme.colorScheme.primary,
                              onChanged: (v) => setState(() => _rollover = v),
                            ),
                          ),
                        ],
                      ),
                      if (_rollover) ...[
                        StaggeredFadeSlide(
                          index: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GlassCard(
                              padding: const EdgeInsets.all(6),
                              borderRadius: AppTheme.radiusCard,
                              child: Column(
                                children: [
                                  SegmentedButton<String>(
                                    style: SegmentedButton.styleFrom(
                                      side: BorderSide.none,
                                      backgroundColor: Colors.transparent,
                                      selectedBackgroundColor: theme.colorScheme.primary,
                                      selectedForegroundColor: theme.colorScheme.onPrimary,
                                    ),
                                    segments: const [
                                      ButtonSegment(value: 'all', label: Text('All')),
                                      ButtonSegment(value: 'capped', label: Text('Capped')),
                                    ],
                                    selected: {_rolloverType == 'none' ? 'all' : _rolloverType},
                                    onSelectionChanged: (v) => setState(() => _rolloverType = v.first),
                                  ),
                                  if (_rolloverType == 'capped') ...[
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _capController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                                      decoration: inputDeco(label: 'Max Rollover (Tsh)', hint: 'e.g. 50000', icon: Icons.upcoming_rounded),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      sectionLabel('ALERT THRESHOLD'),
                      StaggeredFadeSlide(
                        index: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            borderRadius: AppTheme.radiusCard,
                            elevation: CardElevation.medium,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildLeadingIcon(Icons.notifications_active_rounded, Colors.amber),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Notify when spending reaches',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${(_threshold * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    thumbColor: theme.colorScheme.primary,
                                    overlayColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                    valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
                                    valueIndicatorColor: theme.colorScheme.primary,
                                    valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  child: Slider(
                                    value: _threshold,
                                    min: 0.5,
                                    max: 1.0,
                                    divisions: 10,
                                    label: '${(_threshold * 100).round()}%',
                                    onChanged: (v) => setState(() => _threshold = v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      StaggeredFadeSlide(
                        index: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TactileSpringContainer(
                            onTap: _isLoading ? null : _save,
                            child: Container(
                              width: double.infinity,
                              height: 50,
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
                              child: _isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(
                                      isEditing ? 'Update Budget' : 'Create Budget',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                            ),
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
