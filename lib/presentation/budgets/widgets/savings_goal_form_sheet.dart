import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class SavingsGoalFormSheet extends ConsumerStatefulWidget {
  final SavingsGoal? existingGoal;
  const SavingsGoalFormSheet({this.existingGoal, super.key});

  @override
  ConsumerState<SavingsGoalFormSheet> createState() =>
      _SavingsGoalFormSheetState();
}

class _SavingsGoalFormSheetState extends ConsumerState<SavingsGoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  late String _selectedColor;
  late String _selectedIcon;
  late DateTime _selectedDate;
  bool _isLoading = false;

  // Curated 12-icon squircle grid with labels
  static const List<Map<String, dynamic>> _iconChoices = [
    {'name': 'savings', 'icon': PesaFlowIcons.savings, 'label': 'Savings'},
    {'name': 'target', 'icon': PesaFlowIcons.target, 'label': 'Milestone'},
    {'name': 'wallet', 'icon': PesaFlowIcons.wallet, 'label': 'Reserve'},
    {'name': 'home', 'icon': PesaFlowIcons.home, 'label': 'Home'},
    {'name': 'car', 'icon': PesaFlowIcons.car, 'label': 'Vehicle'},
    {'name': 'flight', 'icon': PesaFlowIcons.flight, 'label': 'Travel'},
    {'name': 'laptop', 'icon': PesaFlowIcons.laptop, 'label': 'Tech'},
    {'name': 'phone', 'icon': PesaFlowIcons.phone, 'label': 'Device'},
    {'name': 'school', 'icon': PesaFlowIcons.school, 'label': 'Study'},
    {'name': 'business', 'icon': PesaFlowIcons.business, 'label': 'Business'},
    {'name': 'heart', 'icon': PesaFlowIcons.heart, 'label': 'Health'},
    {'name': 'gift', 'icon': PesaFlowIcons.gift, 'label': 'Gift'},
  ];

  // Tanzanian milestone starter templates
  static final List<Map<String, dynamic>> _goalTemplates = [
    {
      'title': 'Emergency Fund',
      'amount': 2000000,
      'months': 6,
      'color': AppTheme.goalPalette[0],
      'icon': 'savings',
    },
    {
      'title': 'Vacation Trip',
      'amount': 1500000,
      'months': 3,
      'color': AppTheme.goalPalette[7],
      'icon': 'flight',
    },
    {
      'title': 'Land & Construction',
      'amount': 10000000,
      'months': 12,
      'color': AppTheme.goalPalette[6],
      'icon': 'home',
    },
    {
      'title': 'Business Capital',
      'amount': 5000000,
      'months': 6,
      'color': AppTheme.goalPalette[1],
      'icon': 'business',
    },
    {
      'title': 'Education Tuition',
      'amount': 2500000,
      'months': 8,
      'color': AppTheme.goalPalette[3],
      'icon': 'school',
    },
    {
      'title': 'New Vehicle',
      'amount': 8000000,
      'months': 12,
      'color': AppTheme.goalPalette[4],
      'icon': 'car',
    },
    {
      'title': 'Tech Upgrade',
      'amount': 2500000,
      'months': 4,
      'color': AppTheme.goalPalette[2],
      'icon': 'laptop',
    },
    {
      'title': 'Special Event',
      'amount': 1200000,
      'months': 2,
      'color': AppTheme.goalPalette[5],
      'icon': 'gift',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingGoal != null) {
      _nameController.text = widget.existingGoal!.name;
      _amountController.text = (widget.existingGoal!.targetAmount ~/ 100)
          .toString();
      _selectedColor = widget.existingGoal!.color;
      _selectedIcon = widget.existingGoal!.icon;
      _selectedDate = widget.existingGoal!.targetDate;
    } else {
      _selectedColor = AppTheme.goalPalette[0];
      _selectedIcon = 'savings';
      _selectedDate = DateTime.now().add(const Duration(days: 90));
    }

    _nameController.addListener(_onFieldChanged);
    _amountController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _amountController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _applyTemplate(Map<String, dynamic> template) {
    PesaHaptics.selection();
    setState(() {
      _nameController.text = template['title'] as String;
      _amountController.text = (template['amount'] as int).toString();
      _selectedColor = template['color'] as String;
      _selectedIcon = template['icon'] as String;
      final months = template['months'] as int;
      _selectedDate = DateTime.now().add(Duration(days: months * 30));
    });
  }

  void _addAmount(int centsDelta) {
    PesaHaptics.selection();
    final currentCents = CurrencyFormatter.parseToCents(_amountController.text);
    final nextCents = (currentCents + centsDelta).clamp(0, 99999999999);
    setState(() {
      _amountController.text = (nextCents ~/ 100).toString();
    });
  }

  void _setHorizonMonths(int months) {
    PesaHaptics.selection();
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: months * 30));
    });
  }

  String get _targetAmountFormatted {
    final text = _amountController.text.trim();
    if (text.isEmpty) return 'TSh 0';
    final cents = CurrencyFormatter.parseToCents(text);
    return CurrencyFormatter.formatCents(cents);
  }

  String get _smartPaceInsight {
    final text = _amountController.text.trim();
    if (text.isEmpty) return '';
    final cents = CurrencyFormatter.parseToCents(text);
    if (cents <= 0) return '';
    final now = DateTime.now();
    final days = _selectedDate.difference(now).inDays;
    if (days <= 0) return 'Target timeline has arrived';
    if (days < 30) {
      final weeks = (days / 7).clamp(1.0, 4.0);
      final perWeek = (cents / weeks).round();
      return 'Save ~${CurrencyFormatter.formatCents(perWeek)} / week';
    } else {
      final months = (days / 30.4).clamp(1.0, 120.0);
      final perMonth = (cents / months).round();
      return 'Save ~${CurrencyFormatter.formatCents(perMonth)} / month';
    }
  }

  String get _countdownText {
    final now = DateTime.now();
    final days = _selectedDate.difference(now).inDays;
    if (days <= 0) return 'Due today';
    if (days < 30) return '$days days left';
    final months = (days / 30.4).round();
    if (months == 1) return '~1 month left';
    if (months < 12) return '~$months months left';
    final years = (months / 12).toStringAsFixed(1);
    return '~$years yrs left';
  }

  Future<void> _save() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(savingsGoalRepositoryProvider);
      final trackerId = ref.read(activeTrackerIdProvider);
      final targetVal = CurrencyFormatter.parseToCents(_amountController.text);

      if (widget.existingGoal != null) {
        final updated = widget.existingGoal!.copyWith(
          name: _nameController.text.trim(),
          targetAmount: targetVal,
          targetDate: _selectedDate,
          color: _selectedColor,
          icon: _selectedIcon,
        );
        await repo.updateSavingsGoal(updated);
      } else {
        await repo.createSavingsGoal(
          name: _nameController.text.trim(),
          targetAmount: targetVal,
          targetDate: _selectedDate,
          color: _selectedColor,
          icon: _selectedIcon,
          trackerId: trackerId,
        );
      }

      ref.invalidate(savingsGoalsStreamProvider);
      ref.invalidate(savingsGoalsTotalSavedProvider);

      if (mounted) {
        CustomToast.show(
          context,
          message: widget.existingGoal != null
              ? 'Savings goal updated!'
              : 'Savings goal created!',
          type: ToastType.success,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Error saving: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeCol = hexToColor(_selectedColor);
    final isEditing = widget.existingGoal != null;
    final paceInsight = _smartPaceInsight;
    final goalTitle = _nameController.text.trim().isEmpty
        ? 'Goal Preview'
        : _nameController.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusDialog),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + kSpacing20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle bar
          const SizedBox(height: kSpacing12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.hairlineStrong,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: kSpacing14),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Savings Goal' : 'New Savings Goal',
                        style: context.ts(
                          18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing
                            ? 'Adjust target parameters & visual theme'
                            : 'Set milestone targets & visual identity',
                        style: context.ts(
                          12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TactileSpringContainer(
                  haptic: HapticType.soft,
                  onTap: () => context.pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(
                        AppTheme.squircleRadius(32),
                      ),
                    ),
                    child: Icon(
                      PesaFlowIcons.close,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacing12),

          // Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Executive Live Milestone Projection Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(kSpacing16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        border: Border.all(
                          color: context.appColors.hairlineStrong,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.appColors.shadowSubtle,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AnimatedContainer(
                                duration: MotionTokens.durationNormal,
                                curve: Curves.easeOutCubic,
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: themeCol.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.squircleRadius(50),
                                  ),
                                  border: Border.all(
                                    color: themeCol.withValues(alpha: 0.35),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    getGoalIcon(_selectedIcon),
                                    color: themeCol,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: kSpacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goalTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.ts(
                                        16,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Target: $_targetAmountFormatted',
                                      style: AppTheme.getMonospaceStyle(
                                        context.ts(
                                          13,
                                          fontWeight: FontWeight.w700,
                                          color: themeCol,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill,
                                  ),
                                  border: Border.all(
                                    color: context.appColors.hairlineStrong,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PesaFlowIcons.calendar,
                                      size: 11,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: kSpacing4),
                                    Text(
                                      _countdownText,
                                      style: context.ts(
                                        11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (paceInsight.isNotEmpty) ...[
                            const SizedBox(height: kSpacing12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: themeCol.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusCompact,
                                ),
                                border: Border.all(
                                  color: themeCol.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    PesaFlowIcons.income,
                                    size: 13,
                                    color: themeCol,
                                  ),
                                  const SizedBox(width: kSpacing6),
                                  Expanded(
                                    child: Text(
                                      paceInsight,
                                      style: context.ts(
                                        11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: kSpacing16),

                    // ── Quick Starter Templates (only if creating new) ──
                    if (!isEditing) ...[
                      Row(
                        children: [
                          Icon(
                            PesaFlowIcons.bolt,
                            size: 13,
                            color: context.appColors.sectionHeader,
                          ),
                          const SizedBox(width: kSpacing5),
                          Text(
                            'QUICK STARTERS',
                            style: context.ts(
                              11,
                              fontWeight: FontWeight.w600,
                              color: context.appColors.sectionHeader,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing8),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _goalTemplates.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: kSpacing8),
                          itemBuilder: (context, index) {
                            final tmpl = _goalTemplates[index];
                            final tmplCol = hexToColor(tmpl['color'] as String);
                            final tmplAmount = CurrencyFormatter.formatCents(
                              (tmpl['amount'] as int) * 100,
                            );
                            return TactileSpringContainer(
                              haptic: HapticType.selection,
                              onTap: () => _applyTemplate(tmpl),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill,
                                  ),
                                  border: Border.all(
                                    color: context.appColors.hairlineStrong,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: tmplCol.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.squircleRadius(20),
                                        ),
                                      ),
                                      child: Icon(
                                        getGoalIcon(tmpl['icon'] as String),
                                        size: 11,
                                        color: tmplCol,
                                      ),
                                    ),
                                    const SizedBox(width: kSpacing6),
                                    Text(
                                      tmpl['title'] as String,
                                      style: context.ts(
                                        11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: kSpacing4),
                                    Text(
                                      '• $tmplAmount',
                                      style: context.ts(
                                        10,
                                        color: context.appColors.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                    ],

                    // ── Title Field ──
                    Text(
                      'GOAL TITLE',
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.sectionHeader,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: kSpacing6),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: context.ts(
                        15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: context.inputDecoration(
                        hintText: 'e.g. Land Plot, Business Capital',
                        prefixIcon: Icon(
                          PesaFlowIcons.title,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter a goal title'
                          : null,
                    ),

                    const SizedBox(height: kSpacing14),

                    // ── Target Amount ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TARGET AMOUNT',
                          style: context.ts(
                            11,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.sectionHeader,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (_amountController.text.isNotEmpty)
                          Text(
                            _targetAmountFormatted,
                            style: AppTheme.getMonospaceStyle(
                              context.ts(
                                12,
                                fontWeight: FontWeight.w700,
                                color: themeCol,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: kSpacing6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: context.ts(
                        17,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: context.inputDecoration(
                        hintText: '0',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(
                            left: 14,
                            right: 8,
                            top: 13,
                          ),
                          child: Text(
                            'TSh',
                            style: context.ts(
                              14,
                              fontWeight: FontWeight.w700,
                              color: themeCol,
                            ),
                          ),
                        ),
                        suffixIcon: _amountController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear amount',
                                icon: Icon(
                                  PesaFlowIcons.close,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                onPressed: () {
                                  _amountController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please specify a target amount';
                        }
                        final cents = CurrencyFormatter.parseToCents(v);
                        if (cents <= 0) {
                          return 'Amount must be greater than zero';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: kSpacing8),

                    // Quick Increment Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildIncrementPill(
                            label: '+100K',
                            onTap: () => _addAmount(10000000),
                            theme: theme,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildIncrementPill(
                            label: '+250K',
                            onTap: () => _addAmount(25000000),
                            theme: theme,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildIncrementPill(
                            label: '+500K',
                            onTap: () => _addAmount(50000000),
                            theme: theme,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildIncrementPill(
                            label: '+1M',
                            onTap: () => _addAmount(100000000),
                            theme: theme,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildIncrementPill(
                            label: '+2M',
                            onTap: () => _addAmount(200000000),
                            theme: theme,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildIncrementPill(
                            label: '+5M',
                            onTap: () => _addAmount(500000000),
                            theme: theme,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildIncrementPill(
                            label: 'Clear',
                            onTap: () {
                              _amountController.clear();
                              setState(() {});
                            },
                            theme: theme,
                            isClear: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: kSpacing16),

                    // ── Target Date & Horizon ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TARGET DEADLINE',
                          style: context.ts(
                            11,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.sectionHeader,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          _countdownText,
                          style: context.ts(
                            11,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacing6),
                    ModernDateSelector(
                      labelText: 'Target Date',
                      value: _selectedDate,
                      prefixIcon: PesaFlowIcons.calendar,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime(2045),
                      onChanged: (d) => setState(() => _selectedDate = d),
                    ),
                    const SizedBox(height: kSpacing8),

                    // Horizon Presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildHorizonChip(
                            label: '1 Mo',
                            months: 1,
                            theme: theme,
                            activeColor: themeCol,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildHorizonChip(
                            label: '3 Mos',
                            months: 3,
                            theme: theme,
                            activeColor: themeCol,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildHorizonChip(
                            label: '6 Mos',
                            months: 6,
                            theme: theme,
                            activeColor: themeCol,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildHorizonChip(
                            label: '1 Yr',
                            months: 12,
                            theme: theme,
                            activeColor: themeCol,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildHorizonChip(
                            label: '2 Yrs',
                            months: 24,
                            theme: theme,
                            activeColor: themeCol,
                          ),
                          const SizedBox(width: kSpacing6),
                          _buildHorizonChip(
                            label: '3 Yrs',
                            months: 36,
                            theme: theme,
                            activeColor: themeCol,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: kSpacing18),

                    // ── Visual Identity: Color Palette ──
                    Text(
                      'THEME COLOR',
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.sectionHeader,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: kSpacing8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: AppTheme.goalPalette.map((hex) {
                        final col = hexToColor(hex);
                        final isSel =
                            _selectedColor.toUpperCase() == hex.toUpperCase();
                        return TactileSpringContainer(
                          haptic: HapticType.selection,
                          onTap: () => setState(() => _selectedColor = hex),
                          child: AnimatedContainer(
                            duration: MotionTokens.durationNormal,
                            curve: Curves.easeOutCubic,
                            width: isSel ? 36 : 30,
                            height: isSel ? 36 : 30,
                            decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(
                                AppTheme.squircleRadius(isSel ? 36 : 30),
                              ),
                              border: Border.all(
                                color: isSel
                                    ? theme.colorScheme.onSurface
                                    : context.appColors.hairlineStrong,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: isSel
                                ? Icon(
                                    PesaFlowIcons.check,
                                    size: 16,
                                    color:
                                        ThemeData.estimateBrightnessForColor(
                                              col,
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: kSpacing18),

                    // ── Visual Identity: Redesigned Squircle Icons Grid ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GOAL ICON',
                          style: context.ts(
                            11,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.sectionHeader,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          'SELECT VISUAL BADGE',
                          style: context.ts(
                            10,
                            color: context.appColors.textLow,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacing8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _iconChoices.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.74,
                          ),
                      itemBuilder: (context, idx) {
                        final itm = _iconChoices[idx];
                        final name = itm['name'] as String;
                        final label = itm['label'] as String;
                        final icon = itm['icon'] as IconData;
                        final isSel = _selectedIcon == name;

                        return GestureDetector(
                          onTap: () {
                            PesaHaptics.selection();
                            setState(() => _selectedIcon = name);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: MotionTokens.durationNormal,
                                curve: Curves.easeOutCubic,
                                width: isSel ? 50 : 46,
                                height: isSel ? 50 : 46,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? themeCol.withValues(alpha: 0.22)
                                      : theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.squircleRadius(isSel ? 50 : 46),
                                  ),
                                  border: Border.all(
                                    color: isSel
                                        ? themeCol
                                        : context.appColors.hairlineStrong,
                                    width: isSel ? 2 : 1.2,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      icon,
                                      size: isSel ? 24 : 22,
                                      color: isSel
                                          ? themeCol
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.85),
                                    ),
                                    if (isSel)
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                          width: 13,
                                          height: 13,
                                          decoration: BoxDecoration(
                                            color: themeCol,
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.squircleRadius(13),
                                            ),
                                            border: Border.all(
                                              color: theme.colorScheme.surface,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Icon(
                                            PesaFlowIcons.check,
                                            size: 7.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: kSpacing4),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.ts(
                                  10,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSel
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.65,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: kSpacing24),

                    // ── Submit Action Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TactileSpringContainer(
                        haptic: HapticType.success,
                        onTap: _isLoading ? null : _save,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: themeCol,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: themeCol.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        ThemeData.estimateBrightnessForColor(
                                              themeCol,
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                )
                              : Text(
                                  isEditing
                                      ? 'Update Savings Goal'
                                      : 'Create Savings Goal',
                                  style: context.ts(
                                    15,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        ThemeData.estimateBrightnessForColor(
                                              themeCol,
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpacing8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncrementPill({
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isClear = false,
  }) {
    return TactileSpringContainer(
      haptic: HapticType.selection,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing10,
          vertical: kSpacing6,
        ),
        decoration: BoxDecoration(
          color: isClear
              ? context.appColors.expenseColor.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: isClear
                ? context.appColors.expenseColor.withValues(alpha: 0.3)
                : context.appColors.hairlineStrong,
          ),
        ),
        child: Text(
          label,
          style: context.ts(
            11,
            fontWeight: FontWeight.w600,
            color: isClear
                ? context.appColors.expenseColor
                : theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizonChip({
    required String label,
    required int months,
    required ThemeData theme,
    required Color activeColor,
  }) {
    final now = DateTime.now();
    final diffDays = _selectedDate.difference(now).inDays;
    final isMatching = (diffDays - (months * 30)).abs() <= 5;

    return TactileSpringContainer(
      haptic: HapticType.selection,
      onTap: () => _setHorizonMonths(months),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing10,
          vertical: kSpacing6,
        ),
        decoration: BoxDecoration(
          color: isMatching
              ? activeColor.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: isMatching
                ? activeColor
                : context.appColors.hairlineStrong,
            width: isMatching ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: context.ts(
            11,
            fontWeight: FontWeight.w600,
            color: isMatching
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}
