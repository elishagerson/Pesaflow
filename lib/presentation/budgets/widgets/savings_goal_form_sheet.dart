import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class SavingsGoalFormSheet extends ConsumerStatefulWidget {
  final SavingsGoal? existingGoal;
  const SavingsGoalFormSheet({this.existingGoal, super.key});

  @override
  ConsumerState<SavingsGoalFormSheet> createState() => _SavingsGoalFormSheetState();
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
    {'name': 'savings', 'icon': Icons.savings_rounded},
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
      _amountController.text = (widget.existingGoal!.targetAmount ~/ 100).toString();
      _selectedColor = widget.existingGoal!.color;
      _selectedIcon = widget.existingGoal!.icon;
      _selectedDate = widget.existingGoal!.targetDate;
    } else {
      _selectedColor = _colors.first;
      _selectedIcon = _icons.first['name'];
      _selectedDate = DateTime.now().add(const Duration(days: 90)); // 3 months default
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(savingsGoalRepositoryProvider);
      final trackerId = ref.read(activeTrackerIdProvider);
      final targetVal = (int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) * 100;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceHighDark : AppTheme.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16, top: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingGoal != null ? 'Edit Savings Goal' : 'New Savings Goal',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Form fields
              IosListSection(
                header: 'GOAL DETAIL',
                rows: [
                  IosListRow(
                    title: TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        labelText: 'Goal Title',
                        hintText: 'e.g. Vacation to Zanzibar, Emergency Fund',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                  ),
                  IosListRow(
                    title: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 15, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Target Amount (Tsh)',
                        hintText: 'e.g. 1500000',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Target is required';
                        final val = int.tryParse(v) ?? 0;
                        if (val <= 0) return 'Must be greater than 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Picker section
              IosListSection(
                header: 'TARGET TIMELINE',
                rows: [
                  IosListRow(
                    title: const Text('Target Date', style: TextStyle(fontSize: 15)),
                    subtitle: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    trailing: const Icon(Icons.calendar_month_rounded, size: 20),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setState(() => _selectedDate = d);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // HSL visual color picker
              Text(
                'THEME COLOR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final colorHex = _colors[index];
                    final colorVal = hexToColor(colorHex);
                    final isSelected = _selectedColor == colorHex;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedColor = colorHex);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorVal,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colorVal.withOpacity(0.5),
                                    blurRadius: 8,
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
              const SizedBox(height: 16),

              // Icon grid selection
              Text(
                'GOAL ICON',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _icons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = _icons[index];
                    final isSelected = _selectedIcon == item['name'];
                    final themeCol = hexToColor(_selectedColor);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIcon = item['name']);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? themeCol.withOpacity(0.15)
                              : (isDark ? const Color(0xFF1C1C1E) : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? themeCol : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          item['icon'],
                          color: isSelected ? themeCol : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hexToColor(_selectedColor),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Text(
                          widget.existingGoal != null ? 'Update Goal' : 'Create Savings Goal',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
