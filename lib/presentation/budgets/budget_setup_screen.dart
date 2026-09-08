import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/data/repositories/budget_group_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';
import 'package:pesaflow/domain/models/enums.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  final _pageController = PageController();
  final _incomeController = TextEditingController();
  int _currentStep = 0;
  BudgetRuleType _selectedRule = BudgetRuleType.rule503020;
  double _customNeeds = 0.50;
  double _customWants = 0.30;
  double _customInvestments = 0.20;
  bool _isSaving = false;

  static const _totalSteps = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  int get _incomeCents =>
      CurrencyFormatter.parseToCents(_incomeController.text);

  void _goToStep(int step) {
    if (step < 0 || step >= _totalSteps) return;
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final incomeCents = _incomeCents;
    if (incomeCents <= 0) {
      CustomToast.show(
        context,
        message: 'Please enter your monthly income',
        type: ToastType.error,
      );
      _goToStep(0);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final groupRepo = ref.read(budgetGroupRepositoryProvider);
      final settingsRepo = ref.read(settingsRepositoryProvider);

      // Save income and rule to settings
      await settingsRepo.setSetting('monthly_income', incomeCents.toString());
      await settingsRepo.setSetting('budget_rule', _selectedRule.toDbString());

      // Create the 3 budget groups
      await groupRepo.createBudgetPlan(
        rule: _selectedRule,
        monthlyIncomeCents: incomeCents,
        customNeeds: _selectedRule == BudgetRuleType.custom
            ? _customNeeds
            : null,
        customWants: _selectedRule == BudgetRuleType.custom
            ? _customWants
            : null,
        customInvestments: _selectedRule == BudgetRuleType.custom
            ? _customInvestments
            : null,
      );

      // Invalidate providers
      ref.invalidate(budgetGroupsProvider);
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(monthlyIncomeProvider);
      ref.invalidate(budgetRuleProvider);

      if (mounted) {
        CustomToast.show(
          context,
          message: 'Budget plan created!',
          type: ToastType.success,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Error creating plan: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const FloatingTopBar(
              title: 'Budget Setup',
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
            ),

            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpacing24),
              child: Row(
                children: List.generate(_totalSteps, (i) {
                  final isActive = i <= _currentStep;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i < _totalSteps - 1 ? kSpacing6 : 0,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary
                              : onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: kSpacing8),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildIncomeStep(theme, onSurface),
                  _buildRuleStep(theme, onSurface),
                  _buildReviewStep(theme, onSurface),
                ],
              ),
            ),

            // Bottom action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSpacing20,
                kSpacing12,
                kSpacing20,
                kSpacing20,
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: TactileSpringContainer(
                        onTap: () => _goToStep(_currentStep - 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: kSpacing14,
                          ),
                          decoration: BoxDecoration(
                            color: onSurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Back',
                              style: context.ts(
                                15,
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: kSpacing12),
                  Expanded(
                    flex: 2,
                    child: TactileSpringContainer(
                      onTap: _currentStep < _totalSteps - 1
                          ? () {
                              if (_currentStep == 0 && _incomeCents <= 0) {
                                CustomToast.show(
                                  context,
                                  message: 'Enter your monthly income first',
                                  type: ToastType.error,
                                );
                                return;
                              }
                              PesaHaptics.light();
                              _goToStep(_currentStep + 1);
                            }
                          : _isSaving
                          ? null
                          : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: kSpacing14,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
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
                        child: Center(
                          child: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : Text(
                                  _currentStep < _totalSteps - 1
                                      ? 'Continue'
                                      : 'Create Budget Plan',
                                  style: context.ts(
                                    15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 1: Set Monthly Income
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildIncomeStep(ThemeData theme, Color onSurface) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredFadeSlide(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What\'s your monthly income?',
                  style: context.ts(
                    26,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: kSpacing8),
                Text(
                  'We\'ll use this to calculate your budget allocations. You can always change this later.',
                  style: context.ts(
                    14,
                    color: onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacing32),

          // Big income input
          StaggeredFadeSlide(
            index: 1,
            child: GlassCard(
              padding: const EdgeInsets.all(kSpacing24),
              borderRadius: AppTheme.radiusCard,
              child: Column(
                children: [
                  Icon(
                    PesaFlowIcons.income,
                    size: 40,
                    color: context.appColors.incomeColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: kSpacing16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tsh ',
                        style: context.ts(
                          24,
                          fontWeight: FontWeight.w600,
                          color: onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _incomeController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: AppTheme.getMonospaceStyle(
                            theme.textTheme.headlineMedium!.copyWith(
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                            ),
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: context.ts(
                              32,
                              color: onSurface.withValues(alpha: 0.15),
                              fontWeight: FontWeight.w800,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing12),
                  Text(
                    'Monthly take-home pay',
                    style: context.ts(
                      12,
                      color: onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 2: Choose Budget Rule
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildRuleStep(ThemeData theme, Color onSurface) {
    final incomeCents = _incomeCents;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredFadeSlide(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a budgeting rule',
                  style: context.ts(
                    26,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: kSpacing8),
                Text(
                  'This determines how your income splits across Needs, Wants, and Investments.',
                  style: context.ts(
                    14,
                    color: onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacing24),

          // Rule options
          ...BudgetRuleType.values.map((rule) {
            final isSelected = _selectedRule == rule;
            final (
              needsPct,
              wantsPct,
              investPct,
            ) = rule == BudgetRuleType.custom
                ? (_customNeeds, _customWants, _customInvestments)
                : rule.percentages;

            return Padding(
              padding: const EdgeInsets.only(bottom: kSpacing12),
              child: StaggeredFadeSlide(
                index: rule.index + 1,
                child: TactileSpringContainer(
                  onTap: () {
                    PesaHaptics.light();
                    setState(() => _selectedRule = rule);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(kSpacing16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : onSurface.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.4)
                            : onSurface.withValues(alpha: 0.06),
                        width: isSelected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : onSurface.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      PesaFlowIcons.check,
                                      size: 14,
                                      color: theme.colorScheme.onPrimary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: kSpacing12),
                            Text(
                              rule.displayName,
                              style: context.ts(
                                16,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing6),
                        Padding(
                          padding: const EdgeInsets.only(left: 34),
                          child: Text(
                            rule.subtitle,
                            style: context.ts(
                              12,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        if (isSelected && incomeCents > 0) ...[
                          const SizedBox(height: kSpacing16),
                          // Split preview bar
                          _SplitPreviewBar(
                            needsPct: needsPct,
                            wantsPct: wantsPct,
                            investPct: investPct,
                            incomeCents: incomeCents,
                          ),
                        ],
                        // Custom sliders
                        if (isSelected && rule == BudgetRuleType.custom) ...[
                          const SizedBox(height: kSpacing16),
                          _buildCustomSlider(
                            'Needs',
                            _customNeeds,
                            context.appColors.needsColor,
                            (v) => _adjustCustomPercentage('needs', v),
                          ),
                          _buildCustomSlider(
                            'Wants',
                            _customWants,
                            context.appColors.wantsColor,
                            (v) => _adjustCustomPercentage('wants', v),
                          ),
                          _buildCustomSlider(
                            'Investments',
                            _customInvestments,
                            context.appColors.investColor,
                            (v) => _adjustCustomPercentage('investments', v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _adjustCustomPercentage(String which, double value) {
    setState(() {
      switch (which) {
        case 'needs':
          _customNeeds = value;
          final remaining = 1.0 - value;
          if (_customWants + _customInvestments > 0) {
            final ratio =
                remaining /
                (_customWants + _customInvestments).clamp(0.01, 1.0);
            _customWants = (_customWants * ratio).clamp(0.0, 1.0);
            _customInvestments = (1.0 - _customNeeds - _customWants).clamp(
              0.0,
              1.0,
            );
          } else {
            _customWants = remaining / 2;
            _customInvestments = remaining / 2;
          }
        case 'wants':
          _customWants = value;
          final remaining = 1.0 - value;
          if (_customNeeds + _customInvestments > 0) {
            final ratio =
                remaining /
                (_customNeeds + _customInvestments).clamp(0.01, 1.0);
            _customNeeds = (_customNeeds * ratio).clamp(0.0, 1.0);
            _customInvestments = (1.0 - _customNeeds - _customWants).clamp(
              0.0,
              1.0,
            );
          } else {
            _customNeeds = remaining / 2;
            _customInvestments = remaining / 2;
          }
        case 'investments':
          _customInvestments = value;
          final remaining = 1.0 - value;
          if (_customNeeds + _customWants > 0) {
            final ratio =
                remaining / (_customNeeds + _customWants).clamp(0.01, 1.0);
            _customNeeds = (_customNeeds * ratio).clamp(0.0, 1.0);
            _customWants = (1.0 - _customNeeds - _customInvestments).clamp(
              0.0,
              1.0,
            );
          } else {
            _customNeeds = remaining / 2;
            _customWants = remaining / 2;
          }
      }
    });
  }

  Widget _buildCustomSlider(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label ${(value * 100).round()}%',
              style: context.ts(12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.15),
                thumbColor: color,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value.clamp(0.05, 0.90),
                min: 0.05,
                max: 0.90,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 3: Review & Create
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildReviewStep(ThemeData theme, Color onSurface) {
    final incomeCents = _incomeCents;
    final (
      needsPct,
      wantsPct,
      investPct,
    ) = _selectedRule == BudgetRuleType.custom
        ? (_customNeeds, _customWants, _customInvestments)
        : _selectedRule.percentages;

    final allocations = BudgetEngine.computeGroupAllocations(
      monthlyIncome: incomeCents,
      rule: _selectedRule,
      customNeeds: _selectedRule == BudgetRuleType.custom ? _customNeeds : null,
      customWants: _selectedRule == BudgetRuleType.custom ? _customWants : null,
      customInvestments: _selectedRule == BudgetRuleType.custom
          ? _customInvestments
          : null,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredFadeSlide(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review your budget plan',
                  style: context.ts(
                    26,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: kSpacing8),
                Text(
                  'Here\'s how your income will be allocated. You can add specific category budgets within each group after setup.',
                  style: context.ts(
                    14,
                    color: onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacing24),

          // Income summary
          StaggeredFadeSlide(
            index: 1,
            child: GlassCard(
              padding: const EdgeInsets.all(kSpacing16),
              borderRadius: AppTheme.radiusCard,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(kSpacing10),
                    decoration: BoxDecoration(
                      color: context.appColors.incomeColor.withValues(
                        alpha: 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PesaFlowIcons.income,
                      color: context.appColors.incomeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: kSpacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Income',
                          style: context.ts(
                            12,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatCents(incomeCents),
                          style: context.ts(
                            18,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacing10,
                      vertical: kSpacing4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      _selectedRule.displayName,
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpacing16),

          // Split preview bar
          StaggeredFadeSlide(
            index: 2,
            child: _SplitPreviewBar(
              needsPct: needsPct,
              wantsPct: wantsPct,
              investPct: investPct,
              incomeCents: incomeCents,
            ),
          ),
          const SizedBox(height: kSpacing24),

          // Group cards
          ...allocations.asMap().entries.map((entry) {
            final i = entry.key;
            final alloc = entry.value;
            final (icon, color) = _groupVisuals(context, alloc.type);

            return StaggeredFadeSlide(
              index: 3 + i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: kSpacing12),
                child: GlassCard(
                  padding: const EdgeInsets.all(kSpacing16),
                  borderRadius: AppTheme.radiusCard,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(kSpacing10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: kSpacing14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alloc.type.displayName,
                              style: context.ts(
                                16,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: kSpacing2),
                            Text(
                              '${(alloc.percentage * 100).round()}% of income',
                              style: context.ts(
                                12,
                                color: onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCents(alloc.amount),
                        style: context.ts(
                          16,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: kSpacing16),
          StaggeredFadeSlide(
            index: 6,
            child: Container(
              padding: const EdgeInsets.all(kSpacing12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusCompact),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PesaFlowIcons.info,
                    size: 16,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: kSpacing10),
                  Expanded(
                    child: Text(
                      'After creating your plan, you can add specific category budgets (Food, Transport, etc.) within each group.',
                      style: context.ts(
                        12,
                        color: onSurface.withValues(alpha: 0.6),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _groupVisuals(BuildContext context, BudgetGroupType type) {
    final appColors = context.appColors;
    return switch (type) {
      BudgetGroupType.needs => (PesaFlowIcons.home, appColors.needsColor),
      BudgetGroupType.wants => (
        PesaFlowIcons.shoppingBag,
        appColors.wantsColor,
      ),
      BudgetGroupType.investments => (
        PesaFlowIcons.income,
        appColors.investColor,
      ),
      BudgetGroupType.custom => (PesaFlowIcons.budgets, appColors.neutralColor),
    };
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SPLIT PREVIEW BAR
// ════════════════════════════════════════════════════════════════════════════

class _SplitPreviewBar extends StatelessWidget {
  final double needsPct;
  final double wantsPct;
  final double investPct;
  final int incomeCents;

  const _SplitPreviewBar({
    required this.needsPct,
    required this.wantsPct,
    required this.investPct,
    required this.incomeCents,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                Flexible(
                  flex: (needsPct * 100).round(),
                  child: Container(color: appColors.needsColor),
                ),
                Flexible(
                  flex: (wantsPct * 100).round(),
                  child: Container(color: appColors.wantsColor),
                ),
                Flexible(
                  flex: (investPct * 100).round(),
                  child: Container(color: appColors.investColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: kSpacing10),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _legendItem(
              'Needs',
              needsPct,
              appColors.needsColor,
              onSurface,
              context,
            ),
            _legendItem(
              'Wants',
              wantsPct,
              appColors.wantsColor,
              onSurface,
              context,
            ),
            _legendItem(
              'Invest',
              investPct,
              appColors.investColor,
              onSurface,
              context,
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(
    String label,
    double pct,
    Color color,
    Color onSurface,
    BuildContext context,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: kSpacing4),
        Text(
          '$label ${(pct * 100).round()}%',
          style: context.ts(
            11,
            fontWeight: FontWeight.w600,
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
