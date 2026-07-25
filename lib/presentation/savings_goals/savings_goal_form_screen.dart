import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/modern_color_picker.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';

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
  String? _nameError;
  String? _amountError;

  late String _selectedColor;
  late String _selectedIcon;
  late DateTime _selectedDate;
  bool _isLoading = false;

  bool get _isDirty {
    if (_isLoading) return false;
    return _nameController.text.trim().isNotEmpty ||
        _amountController.text.trim().isNotEmpty;
  }

  final List<Map<String, dynamic>> _icons = [
    {'name': 'savings', 'icon': PesaFlowIcons.savings},
    {'name': 'laptop', 'icon': PesaFlowIcons.laptop},
    {'name': 'flight', 'icon': PesaFlowIcons.flight},
    {'name': 'home', 'icon': PesaFlowIcons.home},
    {'name': 'car', 'icon': PesaFlowIcons.car},
    {'name': 'school', 'icon': PesaFlowIcons.school},
    {'name': 'heart', 'icon': PesaFlowIcons.heart},
    {'name': 'gift', 'icon': PesaFlowIcons.gift},
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = '#30D158';
    _selectedIcon = _icons.isNotEmpty ? _icons.first['name'] : 'savings';
    _selectedDate = DateTime.now().add(const Duration(days: 90));
    if (widget.goalId != null) _loadGoal();
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

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _nameError = null;
      _amountError = null;
    });

    bool hasError = false;

    if (_nameController.text.trim().isEmpty) {
      _nameError = 'Enter a goal name';
      hasError = true;
    }

    final targetVal = CurrencyFormatter.parseToCents(_amountController.text);
    if (targetVal <= 0) {
      _amountError = 'Enter a valid amount';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

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

      if (mounted) context.pop();
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
    final onSurface = theme.colorScheme.onSurface;

    InputDecoration inputDeco({
      required String label,
      String? hint,
      IconData? icon,
    }) {
      return context.inputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      );
    }

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await ModernDialog.show<bool>(
          context: context,
          title: const Text('Discard Changes?'),
          titleIcon: PesaFlowIcons.warning,
          iconColor: Colors.orange,
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
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: IosNavBar(
        title: widget.goalId != null ? 'Edit Goal' : 'New Goal',
        largeTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpacing16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GOAL DETAILS',
                style: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.45),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: kSpacing8),
              StaggeredFadeSlide(
                index: 0,
                child: GlassCard(
                  padding: const EdgeInsets.all(kSpacing16),
                  borderRadius: AppTheme.radiusCard,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: inputDeco(
                          label: 'Goal Title',
                          hint: 'e.g. Vacation to Zanzibar',
                          icon: PesaFlowIcons.title,
                        ).copyWith(errorText: _nameError),
                        onChanged: (_) => setState(() => _nameError = null),
                      ),
                      const SizedBox(height: kSpacing12),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: inputDeco(
                          label: 'Target Amount (Tsh)',
                          hint: 'e.g. 1500000',
                          icon: PesaFlowIcons.cash,
                        ).copyWith(errorText: _amountError),
                        onChanged: (_) => setState(() => _amountError = null),
                      ),
                      const SizedBox(height: kSpacing12),
                      ModernDateSelector(
                        labelText: 'Target Date',
                        value: _selectedDate,
                        prefixIcon: PesaFlowIcons.calendar,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime(2035),
                        onChanged: (d) => setState(() => _selectedDate = d),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: kSpacing20),

              Text(
                'THEME COLOR',
                style: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.45),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: kSpacing8),
              StaggeredFadeSlide(
                index: 1,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing16,
                    vertical: kSpacing14,
                  ),
                  borderRadius: AppTheme.radiusCard,
                  child: ModernColorPicker(
                    selectedColorHex: _selectedColor,
                    onColorChanged: (hex) {
                      setState(() => _selectedColor = hex);
                    },
                  ),
                ),
              ),
              const SizedBox(height: kSpacing16),

              Text(
                'GOAL ICON',
                style: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.45),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: kSpacing8),
              StaggeredFadeSlide(
                index: 2,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing16,
                    vertical: kSpacing14,
                  ),
                  borderRadius: AppTheme.radiusCard,
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _icons.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: kSpacing14),
                      itemBuilder: (context, index) {
                        final item = _icons[index];
                        final isSelected = _selectedIcon == item['name'];
                        final themeCol = hexToColor(_selectedColor);
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIcon = item['name']);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: isSelected ? 48 : 44,
                            height: isSelected ? 48 : 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? themeCol.withValues(alpha: 0.15)
                                  : theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? themeCol
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              item['icon'],
                              color: isSelected
                                  ? themeCol
                                  : onSurface.withValues(alpha: 0.6),
                              size: 22,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSpacing28),

              StaggeredFadeSlide(
                index: 3,
                child: SizedBox(
                  width: double.infinity,
                  height: kSpacing48,
                  child: TactileSpringContainer(
                    onTap: _isLoading ? null : _save,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            hexToColor(_selectedColor),
                            hexToColor(_selectedColor).withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: hexToColor(
                              _selectedColor,
                            ).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: kSpacing20,
                              width: kSpacing20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.goalId != null
                                  ? 'Update Goal'
                                  : 'Create Savings Goal',
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSpacing24),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
