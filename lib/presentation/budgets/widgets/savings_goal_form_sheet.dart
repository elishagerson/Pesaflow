import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/presentation/common/widgets/modern_date_selector.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
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

  final List<String> _colors = [
    '#30D158', // Emerald
    '#0A84FF', // Sapphire
    '#BF5AF2', // Amethyst
    '#FF9F0A', // Amber
    '#FF453A', // Ruby
    '#64D2FF', // Turquoise
    '#FFD60A', // Gold
  ];

  final List<Map<String, dynamic>> _icons = [
    {'name': 'savings', 'icon': PesaFlowIcons.savings},
    {'name': 'laptop', 'icon': Icons.laptop_chromebook_rounded},
    {'name': 'flight', 'icon': Icons.flight_takeoff_rounded},
    {'name': 'home', 'icon': Icons.home_rounded},
    {'name': 'car', 'icon': Icons.directions_car_rounded},
    {'name': 'school', 'icon': Icons.school_rounded},
    {'name': 'heart', 'icon': Icons.favorite_rounded},
    {'name': 'gift', 'icon': Icons.card_giftcard_rounded},
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
      _selectedColor = _colors.isNotEmpty ? _colors.first : '#30D158';
      _selectedIcon = _icons.isNotEmpty ? _icons.first['name'] : 'savings';
      _selectedDate = DateTime.now().add(
        const Duration(days: 90),
      ); // 3 months default
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate())
      return;

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

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputFill = isDark
        ? const Color(0xFF1B1C22)
        : const Color(0xFFF2F2F7);

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
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: LiquidGlassOverlay(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xF01C1C1E) : const Color(0xF0F2F2F7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 16,
              right: 16,
              top: 8,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top drag indicator
                    Center(
                      child: Container(
                        width: 38,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16, top: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),

                    // Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.existingGoal != null
                              ? 'Edit Savings Goal'
                              : 'New Savings Goal',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PesaFlowIcons.close,
                              size: 20,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Details Section ──
                    Text(
                      'GOAL DETAILS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StaggeredFadeSlide(
                      index: 0,
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderRadius: AppTheme.radiusCard,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: inputDeco(
                                label: 'Goal Title',
                                hint: 'e.g. Vacation to Zanzibar',
                                icon: Icons.title_rounded,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Title is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: inputDeco(
                                label: 'Target Amount (Tsh)',
                                hint: 'e.g. 1500000',
                                icon: PesaFlowIcons.cash,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Target is required';
                                final val = int.tryParse(v) ?? 0;
                                if (val <= 0) return 'Must be greater than 0';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            ModernDateSelector(
                              labelText: 'Target Date',
                              value: _selectedDate,
                              prefixIcon: PesaFlowIcons.calendar,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime(2035),
                              onChanged: (d) =>
                                  setState(() => _selectedDate = d),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Theme Color Section ──
                    Text(
                      'THEME COLOR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StaggeredFadeSlide(
                      index: 1,
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        borderRadius: AppTheme.radiusCard,
                        child: SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _colors.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final colorHex = _colors[index];
                              final colorVal = hexToColor(colorHex);
                              final isSelected = _selectedColor == colorHex;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedColor = colorHex);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  width: isSelected ? 44 : 38,
                                  height: isSelected ? 44 : 38,
                                  decoration: BoxDecoration(
                                    color: colorVal,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            width: 3,
                                          )
                                        : Border.all(
                                            color: colorVal.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 1,
                                          ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: colorVal.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Icon Section ──
                    Text(
                      'GOAL ICON',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StaggeredFadeSlide(
                      index: 2,
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        borderRadius: AppTheme.radiusCard,
                        child: SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _icons.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 14),
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
                                        : (isDark
                                              ? const Color(0xFF1C1C1E)
                                              : Colors.grey[100]),
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
                                        : (isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600]),
                                    size: 22,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Action Button ──
                    StaggeredFadeSlide(
                      index: 3,
                      child: TactileSpringContainer(
                        onTap: _isLoading ? null : _save,
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                hexToColor(_selectedColor),
                                hexToColor(
                                  _selectedColor,
                                ).withValues(alpha: 0.8),
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
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.existingGoal != null
                                      ? 'Update Goal'
                                      : 'Create Savings Goal',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
