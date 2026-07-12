import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/squircle_border.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

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
  String? _nameError;
  String? _amountError;
  String _period = 'monthly';
  bool _rollover = false;
  String _rolloverType = 'none';
  double _threshold = 0.8;
  DateTime _startDate = DateTime.now();
  bool _isSaving = false;
  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
    if (widget.budgetId != null) {
      _loadExistingBudget();
    }
  }

  Future<void> _loadExistingBudget() async {
    final budget = await ref
        .read(budgetRepositoryProvider)
        .getBudgetById(widget.budgetId!);
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
        if (budget.rolloverCap != null) {
          _capController.text = (budget.rolloverCap! ~/ 100).toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _capController.dispose();
    super.dispose();
  }

  Widget _buildLeadingIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(kSpacing8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.125),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _nameError = null;
      _amountError = null;
    });

    bool hasError = false;

    if (_nameController.text.trim().isEmpty) {
      _nameError = 'Enter a budget name';
      hasError = true;
    }

    final amountCents = CurrencyFormatter.parseToCents(_amountController.text);
    if (amountCents <= 0) {
      _amountError = 'Enter a valid amount';
      hasError = true;
    }

    if (_selectedCategoryId == null) {
      CustomToast.show(
        context,
        message: 'Please select a category',
        type: ToastType.error,
      );
      return;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    final repo = ref.read(budgetRepositoryProvider);
    int? rolloverCap;
    if (_rollover &&
        _rolloverType == 'capped' &&
        _capController.text.isNotEmpty) {
      rolloverCap = CurrencyFormatter.parseToCents(_capController.text);
    }

    setState(() => _isSaving = true);

    try {
      if (widget.budgetId != null) {
        final existing = await repo.getBudgetById(widget.budgetId!);
        if (existing != null) {
          await repo.updateBudgetWithPeriodAllocation(
            existing.copyWith(
              name: _nameController.text.trim(),
              categoryId: _selectedCategoryId!,
              period: _period,
              amount: amountCents,
              rollover: _rollover,
              rolloverType: _rolloverType,
              notificationThreshold: _threshold,
            ),
          );
        }
      } else {
        await repo.createBudget(
          name: _nameController.text.trim(),
          categoryId: _selectedCategoryId!,
          period: _period,
          amount: amountCents,
          rollover: _rollover,
          rolloverType: _rolloverType,
          rolloverCap: rolloverCap,
          startDate: _startDate,
          notificationThreshold: _threshold,
        );
      }
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(activeBudgetsStreamProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, message: 'Error: $e', type: ToastType.error);
      }
      setState(() => _isSaving = false);
    }
  }

  Widget _buildCategorySelector(List<dynamic> categories, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: kSpacing4,
            bottom: kSpacing10,
            top: kSpacing12,
          ),
          child: Text(
            'SELECT CATEGORY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat.id == _selectedCategoryId;
              final color = hexToColor(cat.color);

              return Padding(
                padding: const EdgeInsets.only(right: kSpacing12),
                child: TactileSpringContainer(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedCategoryId = cat.id;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    decoration: ShapeDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.03),
                      shape: SquircleBorder(
                        side: BorderSide(
                          color: isSelected
                              ? color
                              : theme.colorScheme.outlineVariant,
                          width: isSelected ? 1.5 : 0.8,
                        ),
                        borderRadius: 14.0,
                      ),
                      shadows: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          getCategoryIcon(cat.icon),
                          color: isSelected
                              ? color
                              : theme.colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(height: kSpacing6),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing4,
                          ),
                          child: Text(
                            cat.name,
                            style: context.ts(10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: kSpacing12),
      ],
    );
  }

  Widget _buildBudgetHero(ThemeData theme, List<dynamic> categories) {
    final selectedCat = categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    final themeColor = selectedCat != null
        ? hexToColor(selectedCat.color)
        : theme.colorScheme.primary;

    final double amount = double.tryParse(_amountController.text) ?? 0.0;
    final formattedVal = NumberFormat('#,###').format(amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: kSpacing20),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.16),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: themeColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _nameController.text.isEmpty
                    ? 'NEW BUDGET'
                    : _nameController.text.toUpperCase(),
                style: context.ts(10, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), letterSpacing: 1.5),
              ),
              const SizedBox(height: kSpacing4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpacing12),
                  child: Text(
                    'Tsh $formattedVal',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'monospace',
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSpacing4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing8,
                  vertical: kSpacing4,
                ),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  _period.toUpperCase(),
                  style: context.ts(10, fontWeight: FontWeight.w900, color: themeColor, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final isEditing = widget.budgetId != null;

    Widget sectionLabel(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          kSpacing16,
          kSpacing8,
          kSpacing16,
          kSpacing6,
        ),
        child: Text(
          label,
          style: context.ts(13, fontWeight: FontWeight.w600, color: onSurface.withValues(alpha: 0.45), letterSpacing: 0.3),
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
                      categoriesAsync.maybeWhen(
                        data: (cats) => _buildBudgetHero(theme, cats),
                        orElse: () => _buildBudgetHero(theme, []),
                      ),
                      const SizedBox(height: kSpacing16),
                      sectionLabel('BUDGET DETAILS'),
                      StaggeredFadeSlide(
                        index: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing16,
                          ),
                          child: GlassCard(
                            padding: const EdgeInsets.all(kSpacing16),
                            borderRadius: AppTheme.radiusCard,
                            child: Column(
                              children: [
                                _InteractiveInputRow(
                                  controller: _nameController,
                                  label: 'Budget Name',
                                  hint: 'e.g. Monthly Food',
                                  icon: Icons.label_rounded,
                                  textCapitalization: TextCapitalization.words,
                                  errorText: _nameError,
                                  onChanged: (_) =>
                                      setState(() => _nameError = null),
                                ),
                                const SizedBox(height: kSpacing16),
                                categoriesAsync.when(
                                  data: (cats) =>
                                      _buildCategorySelector(cats, theme),
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (e, _) => Text('Error: $e'),
                                ),
                                const SizedBox(height: kSpacing8),
                                _InteractiveInputRow(
                                  controller: _amountController,
                                  label: 'Budget Amount (Tsh)',
                                  hint: 'e.g. 300000',
                                  icon: PesaFlowIcons.cash,
                                  keyboardType: TextInputType.number,
                                  errorText: _amountError,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(fontWeight: FontWeight.w500),
                                  onChanged: (_) =>
                                      setState(() => _amountError = null),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing8),
                      sectionLabel('PERIOD'),
                      StaggeredFadeSlide(
                        index: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing16,
                          ),
                          child: GlassCard(
                            padding: const EdgeInsets.all(kSpacing6),
                            borderRadius: AppTheme.radiusCard,
                            child: SizedBox(
                              width: double.infinity,
                              child: CupertinoSlidingSegmentedControl<String>(
                                groupValue: _period,
                                backgroundColor: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.05),
                                thumbColor: theme.colorScheme.surface,
                                children: {
                                  'weekly': Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing10,
                                      vertical: kSpacing8,
                                    ),
                                    child: Text(
                                      'Week',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: _period == 'weekly'
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  'biweekly': Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing10,
                                      vertical: kSpacing8,
                                    ),
                                    child: Text(
                                      '2 Wk',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: _period == 'biweekly'
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  'monthly': Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing10,
                                      vertical: kSpacing8,
                                    ),
                                    child: Text(
                                      'Month',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: _period == 'monthly'
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  'yearly': Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing10,
                                      vertical: kSpacing8,
                                    ),
                                    child: Text(
                                      'Year',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: _period == 'yearly'
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                },
                                onValueChanged: (v) {
                                  if (v != null) setState(() => _period = v);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing8),
                      sectionLabel('START DATE'),
                      StaggeredFadeSlide(
                        index: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing16,
                          ),
                          child: GlassCard(
                            padding: const EdgeInsets.all(kSpacing8),
                            borderRadius: AppTheme.radiusCard,
                            child: ModernDateSelector(
                              labelText: 'Start Date',
                              value: _startDate,
                              prefixIcon: PesaFlowIcons.calendar,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              onChanged: (d) => setState(() => _startDate = d),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing8),
                      IosListSection(
                        header: 'ROLLOVER',
                        rows: [
                          IosListRow(
                            leading: _buildLeadingIcon(
                              Icons.replay_rounded,
                              Colors.purple,
                            ),
                            title: const Text('Enable Rollover'),
                            subtitle: const Text(
                              'Unused budget carries to next period',
                            ),
                            trailing: CupertinoSwitch(
                              value: _rollover,
                              activeTrackColor: theme.colorScheme.primary,
                              onChanged: (v) => setState(() {
                                _rollover = v;
                                if (v && _rolloverType == 'none') {
                                  _rolloverType = 'all';
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                      if (_rollover) ...[
                        StaggeredFadeSlide(
                          index: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing16,
                            ),
                            child: GlassCard(
                              padding: const EdgeInsets.all(kSpacing6),
                              borderRadius: AppTheme.radiusCard,
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: CupertinoSlidingSegmentedControl<String>(
                                      groupValue: _rolloverType,
                                      backgroundColor: theme
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.05),
                                      thumbColor: theme.colorScheme.surface,
                                      children: {
                                        'all': Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: kSpacing12,
                                            vertical: kSpacing8,
                                          ),
                                          child: Text(
                                            'All',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: _rolloverType == 'all'
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                        'capped': Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: kSpacing12,
                                            vertical: kSpacing8,
                                          ),
                                          child: Text(
                                            'Capped',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      _rolloverType == 'capped'
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                      },
                                      onValueChanged: (v) {
                                        if (v != null) {
                                          setState(() => _rolloverType = v);
                                        }
                                      },
                                    ),
                                  ),
                                  if (_rolloverType == 'capped') ...[
                                    const SizedBox(height: kSpacing10),
                                    _InteractiveInputRow(
                                      controller: _capController,
                                      label: 'Max Rollover (Tsh)',
                                      hint: 'e.g. 50000',
                                      icon: Icons.upcoming_rounded,
                                      keyboardType: TextInputType.number,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: kSpacing8),
                      sectionLabel('ALERT THRESHOLD'),
                      StaggeredFadeSlide(
                        index: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing16,
                          ),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            borderRadius: AppTheme.radiusCard,
                            elevation: CardElevation.medium,
                            child: Builder(
                              builder: (context) {
                                final Color thresholdColor = _threshold >= 0.85
                                    ? context.appColors.expenseColor
                                    : (_threshold >= 0.75
                                          ? Colors.amber
                                          : context.appColors.incomeColor);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _buildLeadingIcon(
                                          PesaFlowIcons.notification,
                                          thresholdColor,
                                        ),
                                        const SizedBox(width: kSpacing12),
                                        Expanded(
                                          child: Text(
                                            'Notify when spending reaches',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall!
                                                .copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.7),
                                                ),
                                          ),
                                        ),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          style: theme.textTheme.titleMedium!
                                              .copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: thresholdColor,
                                              ),
                                          child: Text(
                                            '${(_threshold * 100).round()}%',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: kSpacing12),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,
                                        activeTrackColor: thresholdColor,
                                        inactiveTrackColor: thresholdColor
                                            .withValues(alpha: 0.2),
                                        thumbColor: thresholdColor,
                                        overlayColor: thresholdColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 8,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 16,
                                            ),
                                        valueIndicatorShape:
                                            const RectangularSliderValueIndicatorShape(),
                                        valueIndicatorColor: thresholdColor,
                                        valueIndicatorTextStyle:
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      child: Slider(
                                        value: _threshold,
                                        min: 0.5,
                                        max: 1.0,
                                        divisions: 10,
                                        label: '${(_threshold * 100).round()}%',
                                        onChanged: (v) =>
                                            setState(() => _threshold = v),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing32),
                      StaggeredFadeSlide(
                        index: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing16,
                          ),
                          child: TactileSpringContainer(
                            onTap: _save,
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
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isEditing
                                          ? 'Update Budget'
                                          : 'Create Budget',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing40),
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

class _InteractiveInputRow extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;

  const _InteractiveInputRow({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.errorText,
    this.onChanged,
    this.style,
  });

  @override
  State<_InteractiveInputRow> createState() => _InteractiveInputRowState();
}

class _InteractiveInputRowState extends State<_InteractiveInputRow> {
  bool _isFocused = false;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateClearState);
    _showClear = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateClearState);
    super.dispose();
  }

  void _updateClearState() {
    final show = widget.controller.text.isNotEmpty;
    if (show != _showClear) {
      setState(() => _showClear = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing16,
          vertical: kSpacing6,
        ),
        decoration: ShapeDecoration(
          color: _isFocused
              ? theme.colorScheme.primary.withValues(alpha: 0.04)
              : theme.colorScheme.onSurface.withValues(alpha: 0.03),
          shape: SquircleBorder(
            side: BorderSide(
              color: _isFocused
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: _isFocused ? 1.8 : 0.8,
            ),
            borderRadius: 24.0,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(kSpacing10),
              decoration: ShapeDecoration(
                color: _isFocused
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.04),
                shape: const SquircleBorder(borderRadius: 14.0),
              ),
              child: Icon(
                widget.icon,
                color: _isFocused
                    ? theme.colorScheme.primary
                    : onSurface.withValues(alpha: 0.6),
                size: 18,
              ),
            ),
            const SizedBox(width: kSpacing14),
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                textCapitalization: widget.textCapitalization,
                style:
                    widget.style ?? context.ts(15, fontWeight: FontWeight.w600),
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  filled: false,
                  labelText: widget.label,
                  labelStyle: context.ts(
                    12,
                    color: _isFocused
                        ? theme.colorScheme.primary
                        : onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: widget.hint,
                  hintStyle: context.ts(
                    14,
                    color: onSurface.withValues(alpha: 0.3),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorText: widget.errorText,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: kSpacing6,
                  ),
                ),
              ),
            ),
            if (_showClear && _isFocused)
              TactileSpringContainer(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.controller.clear();
                  if (widget.onChanged != null) widget.onChanged!('');
                },
                child: Padding(
                  padding: const EdgeInsets.all(kSpacing6),
                  child: Icon(
                    Icons.cancel_rounded,
                    color: onSurface.withValues(alpha: 0.3),
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
