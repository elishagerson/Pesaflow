import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/shake_widget.dart';

class SavingsGoalFormScreen extends ConsumerStatefulWidget {
  final String? goalId;
  const SavingsGoalFormScreen({this.goalId, super.key});

  @override
  ConsumerState<SavingsGoalFormScreen> createState() =>
      _SavingsGoalFormScreenState();
}

class _SavingsGoalFormScreenState extends ConsumerState<SavingsGoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  late String _selectedColor;
  late String _selectedIcon;
  late DateTime _selectedDate;
  bool _isLoading = false;
  bool _shakeFields = false;

  static const List<String> _curatedColors = [
    '#30D158', // Emerald
    '#0A84FF', // Electric Blue
    '#5E5CE6', // Indigo
    '#BF5AF2', // Purple
    '#FF375F', // Rose / Crimson
    '#FF9F0A', // Amber
    '#FFD60A', // Gold
    '#64D2FF', // Sky
  ];

  static final List<Map<String, dynamic>> _curatedIcons = [
    {'name': 'savings', 'icon': PesaFlowIcons.savings, 'label': 'Savings'},
    {'name': 'home', 'icon': PesaFlowIcons.home, 'label': 'Home'},
    {'name': 'flight', 'icon': PesaFlowIcons.flight, 'label': 'Travel'},
    {'name': 'car', 'icon': PesaFlowIcons.car, 'label': 'Vehicle'},
    {'name': 'laptop', 'icon': PesaFlowIcons.laptop, 'label': 'Tech'},
    {'name': 'school', 'icon': PesaFlowIcons.school, 'label': 'Study'},
    {'name': 'heart', 'icon': PesaFlowIcons.heart, 'label': 'Health'},
    {'name': 'gift', 'icon': PesaFlowIcons.gift, 'label': 'Gift'},
    {'name': 'wallet', 'icon': PesaFlowIcons.wallet, 'label': 'Wallet'},
    {'name': 'target', 'icon': PesaFlowIcons.target, 'label': 'Milestone'},
    {'name': 'business', 'icon': PesaFlowIcons.business, 'label': 'Business'},
    {'name': 'phone', 'icon': PesaFlowIcons.phone, 'label': 'Device'},
  ];

  static final List<Map<String, dynamic>> _presetTemplates = [
    {
      'title': 'Emergency Fund',
      'icon': 'savings',
      'color': '#30D158',
      'amount': '1500000',
      'days': 180,
    },
    {
      'title': 'Vacation Trip',
      'icon': 'flight',
      'color': '#0A84FF',
      'amount': '2000000',
      'days': 120,
    },
    {
      'title': 'New Vehicle',
      'icon': 'car',
      'color': '#FF9F0A',
      'amount': '5000000',
      'days': 365,
    },
    {
      'title': 'Tech Upgrade',
      'icon': 'laptop',
      'color': '#5E5CE6',
      'amount': '2500000',
      'days': 90,
    },
    {
      'title': 'Education Tuition',
      'icon': 'school',
      'color': '#BF5AF2',
      'amount': '3000000',
      'days': 240,
    },
    {
      'title': 'Special Event',
      'icon': 'heart',
      'color': '#FF375F',
      'amount': '4000000',
      'days': 300,
    },
  ];

  bool get _isDirty {
    if (_isLoading) return false;
    return _nameController.text.trim().isNotEmpty ||
        _amountController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _amountController.addListener(_onFieldChanged);
    _selectedColor = '#30D158';
    _selectedIcon = 'savings';
    _selectedDate = DateTime.now().add(const Duration(days: 90));
    if (widget.goalId != null) _loadGoal();
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

  Future<void> _loadGoal() async {
    final repo = ref.read(savingsGoalRepositoryProvider);
    final goal = await repo.getSavingsGoalById(widget.goalId!);
    if (goal != null && mounted) {
      setState(() {
        _nameController.text = goal.name;
        _amountController.text = (goal.targetAmount ~/ 100).toString();
        _selectedColor = goal.color;
        _selectedIcon = goal.icon;
        _selectedDate = goal.targetDate;
      });
    }
  }

  void _applyPreset(Map<String, dynamic> preset) {
    PesaHaptics.selection();
    setState(() {
      _nameController.text = preset['title'] as String;
      _selectedIcon = preset['icon'] as String;
      _selectedColor = preset['color'] as String;
      _amountController.text = preset['amount'] as String;
      _selectedDate = DateTime.now().add(Duration(days: preset['days'] as int));
    });
  }

  void _adjustAmount(int addTsh) {
    PesaHaptics.selection();
    final curCents = CurrencyFormatter.parseToCents(_amountController.text);
    final curTsh = curCents ~/ 100;
    final newTsh = curTsh + addTsh;
    setState(() {
      _amountController.text = newTsh.toString();
    });
  }

  void _clearAmount() {
    PesaHaptics.light();
    setState(() {
      _amountController.clear();
    });
  }

  void _setDateHorizon(int days) {
    PesaHaptics.selection();
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: days));
    });
  }

  String get _targetAmountFormatted {
    final text = _amountController.text.trim();
    if (text.isEmpty) return 'TSh 0';
    final cents = CurrencyFormatter.parseToCents(text);
    return 'TSh ${CurrencyFormatter.format(cents)}';
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
      return 'Save ~TSh ${CurrencyFormatter.format(perWeek)} / week';
    } else {
      final months = (days / 30.4).clamp(1.0, 120.0);
      final perMonth = (cents / months).round();
      return 'Save ~TSh ${CurrencyFormatter.format(perMonth)} / month';
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
    if (!_formKey.currentState!.validate()) {
      setState(() => _shakeFields = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shakeFields = false);
      });
      return;
    }

    final targetVal = CurrencyFormatter.parseToCents(_amountController.text);

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(savingsGoalRepositoryProvider);
      final trackerId = ref.read(activeTrackerIdProvider);

      if (widget.goalId != null) {
        final existing = await repo.getSavingsGoalById(widget.goalId!);
        if (existing != null) {
          final updated = existing.copyWith(
            name: _nameController.text.trim(),
            targetAmount: targetVal,
            targetDate: _selectedDate,
            color: _selectedColor,
            icon: _selectedIcon,
          );
          await repo.updateSavingsGoal(updated);
        }
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
          message: widget.goalId != null ? 'Goal updated' : 'Goal created',
          type: ToastType.success,
        );
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Error saving goal: $e',
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

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await ModernDialog.show<bool>(
          context: context,
          title: const Text('Discard Changes?'),
          titleIcon: PesaFlowIcons.warning,
          iconColor: context.appColors.expenseColor,
          content: const Text(
            'You have unsaved changes. Are you sure you want to go back?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.expenseColor,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
        if (shouldPop == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              FloatingTopBar(
                title: widget.goalId != null ? 'Edit Goal' : 'New Goal',
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    kSpacing16,
                    0,
                    kSpacing16,
                    kSpacing32,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Live Goal Card Preview ──
                        Container(
                          padding: const EdgeInsets.all(kSpacing16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusDialog,
                            ),
                            border: Border.all(
                              color: themeCol.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: themeCol.withValues(
                                  alpha: context.isDark ? 0.22 : 0.08,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: context.isDark ? 0.20 : 0.03,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: themeCol.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusCard,
                                      ),
                                      border: Border.all(
                                        color: themeCol.withValues(alpha: 0.30),
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        getGoalIcon(_selectedIcon),
                                        color: themeCol,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _nameController.text.trim().isEmpty
                                              ? 'Name Your Goal'
                                              : _nameController.text.trim(),
                                          style: context.ts(
                                            17,
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: kSpacing2),
                                        Text(
                                          _countdownText,
                                          style: context.ts(
                                            12,
                                            color: context.appColors.textMedium,
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
                                      color: themeCol.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusPill,
                                      ),
                                      border: Border.all(
                                        color: themeCol.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      'Target',
                                      style: context.ts(
                                        11,
                                        fontWeight: FontWeight.w600,
                                        color: themeCol,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: kSpacing16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'Target Amount: ',
                                    style: context.ts(
                                      12,
                                      color: context.appColors.textMedium,
                                    ),
                                  ),
                                  Text(
                                    _targetAmountFormatted,
                                    style: context.ts(
                                      20,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              if (_smartPaceInsight.isNotEmpty) ...[
                                const SizedBox(height: kSpacing8),
                                Row(
                                  children: [
                                    Icon(
                                      PesaFlowIcons.lightbulb,
                                      size: 14,
                                      color: themeCol,
                                    ),
                                    const SizedBox(width: kSpacing6),
                                    Text(
                                      _smartPaceInsight,
                                      style: context.ts(
                                        12,
                                        fontWeight: FontWeight.w600,
                                        color: themeCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ── Quick Presets (Only shown when name is empty) ──
                        if (widget.goalId == null &&
                            _nameController.text.trim().isEmpty) ...[
                          const SizedBox(height: kSpacing20),
                          Padding(
                            padding: const EdgeInsets.only(left: kSpacing4),
                            child: Text(
                              'QUICK TEMPLATES',
                              style: context.ts(
                                12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.85,
                                ),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: kSpacing8),
                          SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _presetTemplates.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: kSpacing8),
                              itemBuilder: (context, i) {
                                final p = _presetTemplates[i];
                                final pCol = hexToColor(p['color'] as String);
                                return InkWell(
                                  onTap: () => _applyPreset(p),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing12,
                                      vertical: kSpacing6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusPill,
                                      ),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          getGoalIcon(p['icon'] as String),
                                          size: 14,
                                          color: pCol,
                                        ),
                                        const SizedBox(width: kSpacing6),
                                        Text(
                                          p['title'] as String,
                                          style: context.ts(
                                            12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: kSpacing20),

                        // ── Card 1: Goal Details ──
                        Padding(
                          padding: const EdgeInsets.only(left: kSpacing4),
                          child: Text(
                            'GOAL DETAILS',
                            style: context.ts(
                              12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.85,
                              ),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing8),
                        Container(
                          padding: const EdgeInsets.all(kSpacing16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusCard,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: context.isDark ? 0.20 : 0.03,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title Field
                              ShakeWidget(
                                shaking: _shakeFields,
                                child: TextFormField(
                                  controller: _nameController,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  style: context.ts(
                                    15,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Please enter a goal name';
                                    }
                                    return null;
                                  },
                                  decoration: context.inputDecoration(
                                    labelText: 'Goal Title',
                                    hintText: 'e.g. Vacation to Zanzibar',
                                    prefixIcon: Icon(
                                      PesaFlowIcons.bookmarkFilled,
                                      size: 18,
                                      color: themeCol,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: kSpacing16),

                              // Amount Field
                              ShakeWidget(
                                shaking: _shakeFields,
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: context.ts(
                                    16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Enter a target amount';
                                    }
                                    final val =
                                        CurrencyFormatter.parseToCents(v);
                                    if (val <= 0) {
                                      return 'Amount must be greater than 0';
                                    }
                                    return null;
                                  },
                                  decoration: context.inputDecoration(
                                    labelText: 'Target Amount',
                                    hintText: 'e.g. 1,500,000',
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 14,
                                        right: 8,
                                        top: 14,
                                      ),
                                      child: Text(
                                        'TSh',
                                        style: context.ts(
                                          14,
                                          fontWeight: FontWeight.bold,
                                          color: themeCol,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: kSpacing10),

                              // Quick Amount Increment Pills
                              Wrap(
                                spacing: kSpacing8,
                                runSpacing: kSpacing6,
                                children: [
                                  ...[100000, 500000, 1000000, 5000000].map(
                                    (amt) {
                                      final label = amt >= 1000000
                                          ? '+${amt ~/ 1000000}M'
                                          : '+${amt ~/ 1000}K';
                                      return InkWell(
                                        onTap: () => _adjustAmount(amt),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusPill,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusPill,
                                            ),
                                            border: Border.all(
                                              color: theme
                                                  .colorScheme
                                                  .outlineVariant
                                                  .withValues(alpha: 0.20),
                                            ),
                                          ),
                                          child: Text(
                                            label,
                                            style: context.ts(
                                              11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_amountController.text.isNotEmpty)
                                    InkWell(
                                      onTap: _clearAmount,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusPill,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.error
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusPill,
                                          ),
                                          border: Border.all(
                                            color: theme.colorScheme.error
                                                .withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Text(
                                          'Clear',
                                          style: context.ts(
                                            11,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: kSpacing16),

                              // Date Selector
                              ModernDateSelector(
                                labelText: 'Target Deadline',
                                value: _selectedDate,
                                prefixIcon: PesaFlowIcons.calendar,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 1),
                                ),
                                lastDate: DateTime(2035),
                                onChanged: (d) =>
                                    setState(() => _selectedDate = d),
                              ),

                              const SizedBox(height: kSpacing10),

                              // Quick Horizon Selector
                              Wrap(
                                spacing: kSpacing8,
                                runSpacing: kSpacing6,
                                children: [
                                  ...[
                                    {'label': '1 Mo', 'days': 30},
                                    {'label': '3 Mos', 'days': 90},
                                    {'label': '6 Mos', 'days': 180},
                                    {'label': '1 Yr', 'days': 365},
                                    {'label': '2 Yrs', 'days': 730},
                                  ].map((h) {
                                    final days = h['days'] as int;
                                    final label = h['label'] as String;
                                    final isSelected = (_selectedDate
                                                .difference(DateTime.now())
                                                .inDays -
                                            days)
                                        .abs() <=
                                        2;
                                    return InkWell(
                                      onTap: () => _setDateHorizon(days),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusPill,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? themeCol.withValues(alpha: 0.15)
                                              : theme.colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusPill,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? themeCol.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : theme
                                                      .colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: 0.20),
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: context.ts(
                                            11,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? themeCol
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: kSpacing20),

                        // ── Card 2: Visual Identity (Color & Icon) ──
                        Padding(
                          padding: const EdgeInsets.only(left: kSpacing4),
                          child: Text(
                            'VISUAL IDENTITY',
                            style: context.ts(
                              12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.85,
                              ),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing8),
                        Container(
                          padding: const EdgeInsets.all(kSpacing16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusCard,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: context.isDark ? 0.20 : 0.03,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Theme Color',
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: kSpacing10),
                              // Curated Color Palette
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: _curatedColors.map((hex) {
                                  final col = hexToColor(hex);
                                  final isSelected = _selectedColor == hex;
                                  return GestureDetector(
                                    onTap: () {
                                      PesaHaptics.selection();
                                      setState(() => _selectedColor = hex);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: isSelected ? 36 : 30,
                                      height: isSelected ? 36 : 30,
                                      decoration: BoxDecoration(
                                        color: col,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.colorScheme.onSurface
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          if (isSelected)
                                            BoxShadow(
                                              color: col.withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                        ],
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              PesaFlowIcons.check,
                                              size: 16,
                                              color: ThemeData.estimateBrightnessForColor(col) ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : Colors.black,
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: kSpacing20),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.20),
                              ),
                              const SizedBox(height: kSpacing16),

                              Text(
                                'Goal Icon',
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: kSpacing12),
                              // 12-Icon Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _curatedIcons.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 1.0,
                                ),
                                itemBuilder: (context, i) {
                                  final item = _curatedIcons[i];
                                  final name = item['name'] as String;
                                  final icon = item['icon'] as IconData;
                                  final isSelected = _selectedIcon == name;
                                  return GestureDetector(
                                    onTap: () {
                                      PesaHaptics.selection();
                                      setState(() => _selectedIcon = name);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? themeCol.withValues(alpha: 0.16)
                                            : theme.colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusCompact,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? themeCol
                                              : theme.colorScheme.outlineVariant
                                                    .withValues(alpha: 0.20),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 20,
                                        color: isSelected
                                            ? themeCol
                                            : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.65),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: kSpacing28),

                        // ── Submit Action Button ──
                        StaggeredFadeSlide(
                          index: 2,
                          child: SizedBox(
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
                                      blurRadius: 12,
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
                                          color: ThemeData.estimateBrightnessForColor(themeCol) ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      )
                                    : Text(
                                        widget.goalId != null
                                            ? 'Save Changes'
                                            : 'Create Savings Goal',
                                        style: context.ts(
                                          16,
                                          fontWeight: FontWeight.w700,
                                          color: ThemeData.estimateBrightnessForColor(themeCol) ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  }
}
