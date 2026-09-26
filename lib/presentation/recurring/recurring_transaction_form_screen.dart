import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:pesaflow/core/theme/app_colors_theme.dart';
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
import 'package:pesaflow/data/repositories/recurring_transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/common/widgets/ios_date_picker_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/shake_widget.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Preset templates for recurring transactions (utilities, rent, subscriptions, income).
class _RecurringStarter {
  final String title;
  final String subtitle;
  final int amount; // in whole TSh
  final String type; // 'expense', 'income'
  final String
  frequency; // 'weekly', 'biweekly', 'monthly', 'quarterly', 'yearly'
  final int interval;
  final String categoryHint;
  final String keywords;
  final IconData icon;
  final Color accentColor;

  const _RecurringStarter({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.frequency,
    required this.interval,
    required this.categoryHint,
    required this.keywords,
    required this.icon,
    required this.accentColor,
  });
}

class RecurringTransactionFormScreen extends ConsumerStatefulWidget {
  final String? recurringId;

  const RecurringTransactionFormScreen({super.key, this.recurringId});

  @override
  ConsumerState<RecurringTransactionFormScreen> createState() =>
      _RecurringTransactionFormScreenState();
}

class _RecurringTransactionFormScreenState
    extends ConsumerState<RecurringTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _keywordsController = TextEditingController();

  String? _selectedAccountId;
  String? _selectedCategoryId;
  String _type = 'expense';
  String _frequency = 'monthly';
  DateTime _nextDate = DateTime.now();
  DateTime? _endDate;

  bool _isLoading = false;
  bool _isEditing = false;
  bool _shakeFields = false;

  static const List<_RecurringStarter> _starters = [
    _RecurringStarter(
      title: 'LUKU Electricity',
      subtitle: 'Monthly power tokens',
      amount: 50000,
      type: 'expense',
      frequency: 'monthly',
      interval: 1,
      categoryHint: 'utilities',
      keywords: 'luku, gecl, tanesco',
      icon: PesaFlowIcons.bolt,
      accentColor: Color(0xFFF59E0B),
    ),
    _RecurringStarter(
      title: 'DAWASA Water',
      subtitle: 'Clean water utility',
      amount: 25000,
      type: 'expense',
      frequency: 'monthly',
      interval: 1,
      categoryHint: 'utilities',
      keywords: 'dawasa',
      icon: PesaFlowIcons.personalCare,
      accentColor: Color(0xFF0284C7),
    ),
    _RecurringStarter(
      title: 'Fiber Internet',
      subtitle: 'Broadband / Wi-Fi',
      amount: 50000,
      type: 'expense',
      frequency: 'monthly',
      interval: 1,
      categoryHint: 'utilities',
      keywords: 'fiber, zuku, ttcl, airtel broadband',
      icon: PesaFlowIcons.wifi,
      accentColor: Color(0xFF6366F1),
    ),
    _RecurringStarter(
      title: 'Azam / DStv',
      subtitle: 'Cable & entertainment',
      amount: 35000,
      type: 'expense',
      frequency: 'monthly',
      interval: 1,
      categoryHint: 'entertainment',
      keywords: 'dstv, multichoice, azam',
      icon: PesaFlowIcons.digitalSubscriptions,
      accentColor: Color(0xFF8B5CF6),
    ),
    _RecurringStarter(
      title: 'House Rent',
      subtitle: 'Monthly/quarterly rent',
      amount: 300000,
      type: 'expense',
      frequency: 'monthly',
      interval: 1,
      categoryHint: 'housing',
      keywords: 'kodi, rent, landlord',
      icon: PesaFlowIcons.home,
      accentColor: Color(0xFF10B981),
    ),
    _RecurringStarter(
      title: 'Salary / Retainer',
      subtitle: 'Expected recurring income',
      amount: 1500000,
      type: 'income',
      frequency: 'monthly',
      interval: 1,
      categoryHint: 'salary',
      keywords: 'salary, mshahara, payroll',
      icon: PesaFlowIcons.income,
      accentColor: Color(0xFF059669),
    ),
  ];

  static const List<int> _amountIncrements = [
    10000,
    25000,
    50000,
    100000,
    500000,
  ];

  static const List<String> _frequencies = [
    'weekly',
    'biweekly',
    'monthly',
    'quarterly',
    'yearly',
  ];

  bool get _isDirty {
    if (_isLoading) return false;
    return _amountController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _selectedAccountId != null ||
        _selectedCategoryId != null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.recurringId != null) {
      _isEditing = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(recurringTransactionRepositoryProvider);
    final existing = await repo.getById(widget.recurringId!);
    if (existing == null || !mounted) return;
    setState(() {
      _selectedAccountId = existing.accountId;
      _selectedCategoryId = existing.categoryId;
      _amountController.text = (existing.amount ~/ 100).toString();
      _type = existing.type;
      _descriptionController.text = existing.description ?? '';
      _frequency = existing.frequency;
      _intervalController.text = existing.intervalValue.toString();
      _nextDate = existing.nextDate;
      _endDate = existing.endDate;
      _keywordsController.text = existing.merchantKeywords ?? '';
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  void _applyStarter(_RecurringStarter starter) {
    PesaHaptics.selection();
    setState(() {
      _descriptionController.text = starter.title;
      _amountController.text = starter.amount.toString();
      _type = starter.type;
      _frequency = starter.frequency;
      _intervalController.text = starter.interval.toString();
      _keywordsController.text = starter.keywords;
    });

    // Auto-match category from loaded categories
    final categories = ref.read(categoriesFutureProvider).asData?.value;
    if (categories != null && categories.isNotEmpty) {
      final hint = starter.categoryHint.toLowerCase();
      final match = categories.firstWhere(
        (c) =>
            c.type == starter.type &&
            (c.name.toLowerCase().contains(hint) ||
                hint.contains(c.name.toLowerCase())),
        orElse: () => categories.firstWhere(
          (c) => c.type == starter.type,
          orElse: () => categories.first,
        ),
      );
      setState(() => _selectedCategoryId = match.id);
    }

    CustomToast.show(
      context,
      message: 'Applied ${starter.title} starter',
      type: ToastType.success,
    );
  }

  void _incrementAmount(int delta) {
    PesaHaptics.selection();
    final current =
        int.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    final next = (current + delta).clamp(0, 1000000000);
    setState(() {
      _amountController.text = next.toString();
    });
  }

  void _clearAmount() {
    PesaHaptics.selection();
    setState(() {
      _amountController.clear();
    });
  }

  Future<void> _pickDate({required bool endDate}) async {
    final now = DateTime.now();
    final picked = await showIosDatePicker(
      context,
      initialDate: endDate
          ? (_endDate ?? now.add(const Duration(days: 365)))
          : (_nextDate.isBefore(now) ? now : _nextDate),
      firstDate: endDate ? _nextDate : DateTime(2020),
      lastDate: endDate
          ? now.add(const Duration(days: 365 * 10))
          : now.add(const Duration(days: 365 * 5)),
      title: endDate ? 'End Date' : 'Next Payment Date',
    );
    if (picked != null) {
      PesaHaptics.selection();
      setState(() {
        if (endDate) {
          _endDate = picked;
        } else {
          _nextDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _shakeFields = true);
      Future.delayed(MotionTokens.durationDelayedNav, () {
        if (mounted) setState(() => _shakeFields = false);
      });
      return;
    }
    if (_selectedAccountId == null) {
      CustomToast.show(
        context,
        message: 'Please select an account',
        type: ToastType.error,
      );
      return;
    }
    if (_selectedCategoryId == null) {
      CustomToast.show(
        context,
        message: 'Please select a category',
        type: ToastType.error,
      );
      return;
    }

    final amountCents = CurrencyFormatter.parseToCents(_amountController.text);
    if (amountCents <= 0) {
      CustomToast.show(
        context,
        message: 'Please enter a valid amount',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    final interval = int.tryParse(_intervalController.text) ?? 1;
    final activeTrackerId = ref.read(activeTrackerIdProvider);

    if (_isEditing) {
      final existing = await ref
          .read(recurringTransactionRepositoryProvider)
          .getById(widget.recurringId!);
      if (existing == null) return;
      final updated = existing.copyWith(
        accountId: _selectedAccountId,
        categoryId: Value(_selectedCategoryId),
        amount: amountCents,
        type: _type,
        description: Value(
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
        frequency: _frequency,
        intervalValue: interval,
        nextDate: _nextDate,
        endDate: Value(_endDate),
        merchantKeywords: Value(
          _keywordsController.text.trim().isEmpty
              ? null
              : _keywordsController.text.trim(),
        ),
        updatedAt: DateTime.now(),
      );
      try {
        await ref
            .read(recurringTransactionRepositoryProvider)
            .updateRecurringTransaction(updated);
        if (!mounted) return;
        CustomToast.show(
          context,
          message: 'Recurring flow updated',
          type: ToastType.success,
        );
        context.pop();
      } catch (e) {
        if (!mounted) return;
        CustomToast.show(
          context,
          message: 'Failed to update recurring transaction: $e',
          type: ToastType.error,
        );
      }
    } else {
      final recurringId = const Uuid().v4();
      final recurring = RecurringTransaction(
        id: recurringId,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId,
        amount: amountCents,
        type: _type,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        frequency: _frequency,
        intervalValue: interval,
        nextDate: _nextDate,
        endDate: _endDate,
        status: 'active',
        trackerId: activeTrackerId,
        merchantKeywords: _keywordsController.text.trim().isEmpty
            ? null
            : _keywordsController.text.trim(),
        totalPaid: 0,
        paymentCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      try {
        await ref
            .read(recurringTransactionRepositoryProvider)
            .createRecurringTransaction(recurring);
        if (!mounted) return;
        CustomToast.show(
          context,
          message: 'Recurring flow created',
          type: ToastType.success,
        );
        context.pop();
      } catch (e) {
        if (!mounted) return;
        CustomToast.show(
          context,
          message: 'Failed to create recurring transaction: $e',
          type: ToastType.error,
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAccountPicker(List<Account> accounts) {
    final theme = Theme.of(context);
    showSpringSheet(
      context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(
          kSpacing16,
          kSpacing8,
          kSpacing16,
          kSpacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: kSpacing16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Select Funding Account',
              style: context.ts(18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: kSpacing16),
            ...accounts.map((account) {
              final isSelected = account.id == _selectedAccountId;
              return TactileSpringContainer(
                onTap: () {
                  PesaHaptics.selection();
                  setState(() => _selectedAccountId = account.id);
                  Navigator.of(sheetContext).pop();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: kSpacing8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing16,
                    vertical: kSpacing12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.10)
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                )
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          PesaFlowIcons.card,
                          size: 20,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: kSpacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              style: context.ts(
                                15,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatCents(account.balance),
                              style: context.ts(
                                13,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          PesaFlowIcons.check,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(List<Category> categories) {
    final theme = Theme.of(context);
    final filtered = categories.where((c) => c.type == _type).toList();

    showSpringSheet(
      context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(
          kSpacing16,
          kSpacing8,
          kSpacing16,
          kSpacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: kSpacing16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Select Category',
              style: context.ts(18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: kSpacing16),
            filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: kSpacing24),
                    child: Text(
                      'No categories available for $_type',
                      style: context.ts(
                        14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: kSpacing10,
                    runSpacing: kSpacing10,
                    children: filtered.map((cat) {
                      final isSelected = cat.id == _selectedCategoryId;
                      final catColor = hexToColor(cat.color);

                      return TactileSpringContainer(
                        onTap: () {
                          PesaHaptics.selection();
                          setState(() => _selectedCategoryId = cat.id);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing12,
                            vertical: kSpacing10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? catColor.withValues(alpha: 0.18)
                                : theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? catColor
                                  : theme.colorScheme.outlineVariant.withValues(
                                      alpha: 0.3,
                                    ),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  getCategoryIcon(cat.icon),
                                  size: 16,
                                  color: catColor,
                                ),
                              ),
                              const SizedBox(width: kSpacing8),
                              Text(
                                cat.name,
                                style: context.ts(
                                  13,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: kSpacing6),
                                Icon(
                                  PesaFlowIcons.check,
                                  size: 16,
                                  color: catColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // Projection Computations
  int get _parsedAmount {
    return int.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
  }

  int get _monthlyImpact {
    final amount = _parsedAmount;
    final interval = (int.tryParse(_intervalController.text) ?? 1).clamp(
      1,
      999,
    );
    switch (_frequency) {
      case 'weekly':
        return ((amount * 52) / (12 * interval)).round();
      case 'biweekly':
        return ((amount * 26) / (12 * interval)).round();
      case 'quarterly':
        return (amount / (3 * interval)).round();
      case 'yearly':
        return (amount / (12 * interval)).round();
      case 'monthly':
      default:
        return (amount / interval).round();
    }
  }

  int get _annualImpact {
    final amount = _parsedAmount;
    final interval = (int.tryParse(_intervalController.text) ?? 1).clamp(
      1,
      999,
    );
    switch (_frequency) {
      case 'weekly':
        return ((amount * 52) / interval).round();
      case 'biweekly':
        return ((amount * 26) / interval).round();
      case 'quarterly':
        return ((amount * 4) / interval).round();
      case 'yearly':
        return (amount / interval).round();
      case 'monthly':
      default:
        return ((amount * 12) / interval).round();
    }
  }

  String get _cadenceHumanized {
    final interval = int.tryParse(_intervalController.text) ?? 1;
    final dayStr = DateFormat('d MMM').format(_nextDate);
    final weekdayStr = DateFormat('EEEE').format(_nextDate);

    switch (_frequency) {
      case 'weekly':
        return interval == 1
            ? 'Repeats weekly on $weekdayStr'
            : 'Repeats every $interval weeks on $weekdayStr';
      case 'biweekly':
        return 'Repeats every 2 weeks on $weekdayStr';
      case 'monthly':
        return interval == 1
            ? 'Repeats monthly on day ${_nextDate.day}'
            : 'Repeats every $interval months on day ${_nextDate.day}';
      case 'quarterly':
        return interval == 1
            ? 'Repeats quarterly (~$dayStr)'
            : 'Repeats every $interval quarters';
      case 'yearly':
        return interval == 1
            ? 'Repeats annually on $dayStr'
            : 'Repeats every $interval years on $dayStr';
      default:
        return 'Repeats $_frequency';
    }
  }

  DateTime _computeNextCycle(DateTime from, String frequency, int interval) {
    final safeInterval = interval.clamp(1, 999);
    switch (frequency) {
      case 'weekly':
        return from.add(Duration(days: 7 * safeInterval));
      case 'biweekly':
        return from.add(Duration(days: 14 * safeInterval));
      case 'quarterly':
        return DateTime(from.year, from.month + (3 * safeInterval), from.day);
      case 'yearly':
        return DateTime(from.year + safeInterval, from.month, from.day);
      case 'monthly':
      default:
        return DateTime(from.year, from.month + safeInterval, from.day);
    }
  }

  String get _upcomingCyclesStr {
    final interval = int.tryParse(_intervalController.text) ?? 1;
    final d1 = _nextDate;
    final d2 = _computeNextCycle(d1, _frequency, interval);
    final d3 = _computeNextCycle(d2, _frequency, interval);
    final f = DateFormat('d MMM');
    return '${f.format(d1)} → ${f.format(d2)} → ${f.format(d3)}';
  }

  static const _popularKeywords = [
    'luku',
    'gecl',
    'tanesco',
    'dawasa',
    'dstv',
    'azam',
    'zuku',
    'netflix',
    'spotify',
    'rent',
    'salary',
    'mshahara',
  ];

  String get _dueCountdownText {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(_nextDate.year, _nextDate.month, _nextDate.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Due Today';
    if (diff == 1) return 'Due Tomorrow';
    if (diff > 1) return 'In $diff days';
    if (diff == -1) return '1 day overdue';
    return '${diff.abs()} days overdue';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    final typeColor = _type == 'income'
        ? colors.incomeColor
        : _type == 'transfer'
        ? colors.transferColor
        : colors.expenseColor;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await ModernDialog.show<bool>(
          context: context,
          title: const Text('Discard Changes?'),
          titleIcon: PesaFlowIcons.warning,
          iconColor: colors.expenseColor,
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.expenseColor,
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
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            FloatingTopBar(
              title: _isEditing ? 'Edit Recurring Flow' : 'New Recurring Flow',
              padding: EdgeInsets.fromLTRB(
                kSpacing20,
                MediaQuery.paddingOf(context).top + kSpacing8,
                kSpacing20,
                kSpacing16,
              ),
              actions: _isEditing
                  ? [
                      TactileSpringContainer(
                        onTap: () async {
                          final confirm = await ModernDialog.show<bool>(
                            context: context,
                            title: const Text('Delete Recurring Flow?'),
                            titleIcon: PesaFlowIcons.warning,
                            iconColor: theme.colorScheme.error,
                            content: const Text(
                              'Are you sure you want to delete this recurring flow? Linked transaction history won\'t be affected.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: theme.colorScheme.onError,
                                ),
                                onPressed: () => Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                          if (confirm == true && mounted) {
                            final existing = await ref
                                .read(recurringTransactionRepositoryProvider)
                                .getById(widget.recurringId!);
                            if (existing == null || !mounted) return;
                            final recurringData = existing;

                            if (!context.mounted) return;
                            UndoDelete.show(
                              context: context,
                              entityName: 'Recurring Flow',
                              message: 'Recurring flow deleted',
                              onUndo: () async {
                                await ref
                                    .read(
                                      recurringTransactionRepositoryProvider,
                                    )
                                    .createRecurringTransaction(recurringData);
                                if (mounted) {
                                  ref.invalidate(
                                    recurringTransactionsStreamProvider,
                                  );
                                  ref.invalidate(
                                    dueRecurringTransactionsProvider,
                                  );
                                }
                              },
                              onDelete: () async {
                                try {
                                  await ref
                                      .read(
                                        recurringTransactionRepositoryProvider,
                                      )
                                      .deleteRecurringTransaction(
                                        widget.recurringId!,
                                      );
                                  if (context.mounted) {
                                    ref.invalidate(
                                      recurringTransactionsStreamProvider,
                                    );
                                    ref.invalidate(
                                      dueRecurringTransactionsProvider,
                                    );
                                    context.pop();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    CustomToast.show(
                                      context,
                                      message: 'Error: $e',
                                      type: ToastType.error,
                                    );
                                  }
                                }
                              },
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(kSpacing10),
                          decoration: BoxDecoration(
                            color: colors.expenseColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            PesaFlowIcons.delete,
                            size: 18,
                            color: colors.expenseColor,
                          ),
                        ),
                      ),
                    ]
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing16,
                  vertical: kSpacing8,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. STARTERS CAROUSEL (If creating new)
                      if (!_isEditing) ...[
                        _buildSectionHeader(
                          context,
                          title: 'QUICK STARTERS',
                          subtitle: 'Tap to autofill frequent bills & income',
                          icon: PesaFlowIcons.lightbulb,
                        ),
                        const SizedBox(height: kSpacing10),
                        _buildStartersCarousel(context),
                        const SizedBox(height: kSpacing20),
                      ],

                      // 2. HERO AMOUNT CARD & INCREMENTS
                      _buildSectionHeader(
                        context,
                        title: 'RECURRING AMOUNT',
                        subtitle: 'Expected amount per recurrence cycle',
                        icon: PesaFlowIcons.money,
                      ),
                      const SizedBox(height: kSpacing10),
                      _buildHeroAmountCard(context, typeColor),
                      const SizedBox(height: kSpacing20),

                      // 3. LIVE RECURRENCE & IMPACT PROJECTION
                      _buildProjectionCard(context, typeColor),
                      const SizedBox(height: kSpacing20),

                      // 4. FLOW TYPE SELECTOR
                      _buildSectionHeader(
                        context,
                        title: 'FLOW TYPE',
                        subtitle: 'Expense, expected income, or auto-transfer',
                        icon: PesaFlowIcons.transfer,
                      ),
                      const SizedBox(height: kSpacing10),
                      _buildTypeSelector(context, colors),
                      const SizedBox(height: kSpacing20),

                      // 5. DETAILS & IDENTIFIERS
                      _buildSectionHeader(
                        context,
                        title: 'DETAILS & IDENTIFICATION',
                        subtitle: 'Name and automated matching keywords',
                        icon: PesaFlowIcons.tag,
                      ),
                      const SizedBox(height: kSpacing10),
                      _buildDetailsCard(context),
                      const SizedBox(height: kSpacing20),

                      // 6. ACCOUNT & CATEGORY
                      _buildSectionHeader(
                        context,
                        title: 'ACCOUNT & CATEGORY',
                        subtitle: 'Source funding and financial tracking',
                        icon: PesaFlowIcons.card,
                      ),
                      const SizedBox(height: kSpacing10),
                      _buildAccountAndCategoryCard(
                        context,
                        accountsAsync,
                        categoriesAsync,
                      ),
                      const SizedBox(height: kSpacing20),

                      // 7. CADENCE & SCHEDULE
                      _buildSectionHeader(
                        context,
                        title: 'CADENCE & SCHEDULE',
                        subtitle: 'Recurrence frequency, intervals, and dates',
                        icon: PesaFlowIcons.calendar,
                      ),
                      const SizedBox(height: kSpacing10),
                      _buildCadenceCard(context),
                      const SizedBox(height: kSpacing32),

                      // 8. EXECUTIVE SUBMIT BUTTON
                      _buildSubmitButton(context),
                      const SizedBox(height: kSpacing32),
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

  // --- Sub-widgets & Builders ---

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: kSpacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: kSpacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.ts(
                    12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartersCarousel(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _starters.length,
        separatorBuilder: (_, _) => const SizedBox(width: kSpacing10),
        itemBuilder: (context, index) {
          final starter = _starters[index];
          return TactileSpringContainer(
            onTap: () => _applyStarter(starter),
            child: Container(
              width: 150,
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing12,
                vertical: kSpacing10,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: starter.accentColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          starter.icon,
                          size: 16,
                          color: starter.accentColor,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: starter.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          starter.type == 'income' ? 'Income' : 'Bill',
                          style: context.ts(
                            9,
                            fontWeight: FontWeight.w700,
                            color: starter.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        starter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.ts(
                          12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCents(starter.amount * 100),
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroAmountCard(BuildContext context, Color typeColor) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'TSh',
                    style: context.ts(
                      14,
                      fontWeight: FontWeight.w900,
                      color: typeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: kSpacing12),
              Expanded(
                child: ShakeWidget(
                  shaking: _shakeFields,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: context.ts(
                      26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: context.ts(
                        26,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter an amount';
                      }
                      final parsed = int.tryParse(
                        v.replaceAll(RegExp(r'[^0-9]'), ''),
                      );
                      if (parsed == null || parsed <= 0) {
                        return 'Amount must be greater than zero';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              if (_amountController.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear amount',
                  onPressed: _clearAmount,
                  icon: Icon(
                    PesaFlowIcons.close,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          // Quick increment chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ..._amountIncrements.map((inc) {
                  final label = inc >= 1000000
                      ? '+${inc ~/ 1000000}M'
                      : '+${inc ~/ 1000}K';
                  return Padding(
                    padding: const EdgeInsets.only(right: kSpacing8),
                    child: TactileSpringContainer(
                      onTap: () => _incrementAmount(inc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing12,
                          vertical: kSpacing6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          label,
                          style: context.ts(
                            12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                TactileSpringContainer(
                  onTap: _clearAmount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacing12,
                      vertical: kSpacing6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.expenseColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      'Clear',
                      style: context.ts(
                        12,
                        fontWeight: FontWeight.w700,
                        color: colors.expenseColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionCard(BuildContext context, Color typeColor) {
    final theme = Theme.of(context);
    final monthly = _monthlyImpact;
    final annual = _annualImpact;

    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  PesaFlowIcons.subscriptions,
                  size: 16,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: kSpacing10),
              Expanded(
                child: Text(
                  'RECURRING CADENCE & IMPACT',
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(color: typeColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _dueCountdownText,
                  style: context.ts(
                    10,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          Text(
            _cadenceHumanized,
            style: context.ts(
              15,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: kSpacing10),
          // 3-Cycle Schedule Preview
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing12,
              vertical: kSpacing8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(PesaFlowIcons.calendar, size: 14, color: typeColor),
                const SizedBox(width: kSpacing8),
                Text(
                  'Upcoming: ',
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    _upcomingCyclesStr,
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacing14),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: kSpacing14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EST. MONTHLY IMPACT',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        monthly > 0
                            ? CurrencyFormatter.formatCents(monthly * 100)
                            : 'Tsh 0',
                        style: context.ts(
                          18,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 36,
                width: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(width: kSpacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANNUAL COMMITMENT',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        annual > 0
                            ? CurrencyFormatter.formatCents(annual * 100)
                            : 'Tsh 0',
                        style: context.ts(
                          18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_endDate != null) ...[
            const SizedBox(height: kSpacing12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing10,
                vertical: kSpacing6,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
              ),
              child: Row(
                children: [
                  Icon(
                    PesaFlowIcons.calendar,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: kSpacing6),
                  Expanded(
                    child: Text(
                      'Active until ${DateFormat('d MMM yyyy').format(_endDate!)}',
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context, AppColorsTheme colors) {
    final theme = Theme.of(context);
    final options = [
      {'key': 'expense', 'label': 'Expense', 'color': colors.expenseColor},
      {'key': 'income', 'label': 'Income', 'color': colors.incomeColor},
      {'key': 'transfer', 'label': 'Transfer', 'color': colors.transferColor},
    ];

    return Container(
      padding: const EdgeInsets.all(kSpacing4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _type == opt['key'];
          final activeColor = opt['color'] as Color;

          return Expanded(
            child: TactileSpringContainer(
              onTap: () {
                PesaHaptics.selection();
                setState(() {
                  _type = opt['key'] as String;
                  _selectedCategoryId = null; // reset on type change
                });
              },
              child: AnimatedContainer(
                duration: MotionTokens.durationFast,
                padding: const EdgeInsets.symmetric(vertical: kSpacing10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: activeColor, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    opt['label'] as String,
                    style: context.ts(
                      13,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? activeColor
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShakeWidget(
            shaking: _shakeFields,
            child: TextFormField(
              controller: _descriptionController,
              decoration: context.inputDecoration(
                labelText: 'Flow Title / Description',
                hintText: 'e.g. Apartment Rent, Spotify, Wifi',
                prefixIcon: const Icon(PesaFlowIcons.edit, size: 18),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a title or description';
                }
                return null;
              },
            ),
          ),
          if (_type == 'expense' || _type == 'income') ...[
            const SizedBox(height: kSpacing16),
            TextFormField(
              controller: _keywordsController,
              decoration: context.inputDecoration(
                labelText: 'SMS Auto-Matching Keywords (optional)',
                hintText: 'e.g. luku, gecl, netflix (comma separated)',
                prefixIcon: const Icon(PesaFlowIcons.key, size: 18),
              ),
            ),
            const SizedBox(height: kSpacing8),
            Text(
              'Keywords link incoming provider SMS receipts directly to this recurring plan.',
              style: context.ts(
                11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            const SizedBox(height: kSpacing8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _popularKeywords.map((kw) {
                  final active = _keywordsController.text
                      .toLowerCase()
                      .contains(kw);
                  return Padding(
                    padding: const EdgeInsets.only(right: kSpacing6),
                    child: TactileSpringContainer(
                      onTap: () {
                        PesaHaptics.selection();
                        final current = _keywordsController.text.trim();
                        if (active) {
                          final cleaned = current
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.toLowerCase() != kw)
                              .join(', ');
                          _keywordsController.text = cleaned;
                        } else {
                          _keywordsController.text = current.isEmpty
                              ? kw
                              : '$current, $kw';
                        }
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                )
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                          border: Border.all(
                            color: active
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant.withValues(
                                    alpha: 0.25,
                                  ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (active) ...[
                              Icon(
                                PesaFlowIcons.check,
                                size: 12,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              kw,
                              style: context.ts(
                                11,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountAndCategoryCard(
    BuildContext context,
    AsyncValue<List<Account>> accountsAsync,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account Selector
          Text(
            'ACCOUNT',
            style: context.ts(
              11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpacing8),
          accountsAsync.when(
            data: (accounts) {
              final Account? selected =
                  accounts
                      .where((a) => a.id == _selectedAccountId)
                      .firstOrNull ??
                  accounts.firstOrNull;

              // Auto-assign first account if none set
              if (_selectedAccountId == null && accounts.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedAccountId == null) {
                    setState(() => _selectedAccountId = accounts.first.id);
                  }
                });
              }

              return TactileSpringContainer(
                onTap: accounts.isEmpty
                    ? null
                    : () => _showAccountPicker(accounts),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing14,
                    vertical: kSpacing12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                    border: Border.all(
                      color: _selectedAccountId != null
                          ? theme.colorScheme.primary.withValues(alpha: 0.4)
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          PesaFlowIcons.card,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: kSpacing10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected?.name ?? 'Select Account',
                              style: context.ts(
                                14,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (selected != null)
                              Text(
                                CurrencyFormatter.formatCents(selected.balance),
                                style: context.ts(
                                  12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        PesaFlowIcons.chevronDown,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(
              'Error loading accounts: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          const SizedBox(height: kSpacing16),

          // Category Selector
          Text(
            'CATEGORY',
            style: context.ts(
              11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpacing8),
          categoriesAsync.when(
            data: (categories) {
              final filtered = categories
                  .where((c) => c.type == _type)
                  .toList();
              final selectedCat =
                  categories
                      .where((c) => c.id == _selectedCategoryId)
                      .firstOrNull ??
                  filtered.firstOrNull ??
                  categories.firstOrNull;

              // Auto-assign first category if none set
              if (_selectedCategoryId == null && filtered.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedCategoryId == null) {
                    setState(() => _selectedCategoryId = filtered.first.id);
                  }
                });
              }

              final catColor = selectedCat != null
                  ? hexToColor(selectedCat.color)
                  : theme.colorScheme.primary;

              return TactileSpringContainer(
                onTap: () => _showCategoryPicker(categories),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing14,
                    vertical: kSpacing12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                    border: Border.all(
                      color: _selectedCategoryId != null
                          ? catColor.withValues(alpha: 0.5)
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          selectedCat != null
                              ? getCategoryIcon(selectedCat.icon)
                              : PesaFlowIcons.category,
                          size: 16,
                          color: catColor,
                        ),
                      ),
                      const SizedBox(width: kSpacing10),
                      Expanded(
                        child: Text(
                          selectedCat?.name ?? 'Select category',
                          style: context.ts(
                            14,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(
                        PesaFlowIcons.chevronDown,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(
              'Error loading categories: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCadenceCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Frequency Chips
          Text(
            'FREQUENCY',
            style: context.ts(
              11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpacing8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _frequencies.map((freq) {
                final isSelected = _frequency == freq;
                final label = freq[0].toUpperCase() + freq.substring(1);
                return Padding(
                  padding: const EdgeInsets.only(right: kSpacing8),
                  child: TactileSpringContainer(
                    onTap: () {
                      PesaHaptics.selection();
                      setState(() => _frequency = freq);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing14,
                        vertical: kSpacing8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        label,
                        style: context.ts(
                          12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: kSpacing16),

          // Interval row
          Row(
            children: [
              Expanded(
                child: Text(
                  'RECURRENCE INTERVAL',
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Decrease interval',
                    onPressed: () {
                      final val =
                          (int.tryParse(_intervalController.text) ?? 1) - 1;
                      if (val >= 1) {
                        PesaHaptics.selection();
                        setState(
                          () => _intervalController.text = val.toString(),
                        );
                      }
                    },
                    icon: Icon(
                      PesaFlowIcons.remove,
                      size: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: TextFormField(
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: context.ts(15, fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Increase interval',
                    onPressed: () {
                      final val =
                          (int.tryParse(_intervalController.text) ?? 1) + 1;
                      if (val <= 99) {
                        PesaHaptics.selection();
                        setState(
                          () => _intervalController.text = val.toString(),
                        );
                      }
                    },
                    icon: Icon(
                      PesaFlowIcons.add,
                      size: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),

          // Next Date Selector
          Text(
            'NEXT PAYMENT / RECEIPT DATE',
            style: context.ts(
              11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpacing8),
          TactileSpringContainer(
            onTap: () => _pickDate(endDate: false),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing14,
                vertical: kSpacing12,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PesaFlowIcons.calendar,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: kSpacing10),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, d MMMM yyyy').format(_nextDate),
                      style: context.ts(
                        14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    PesaFlowIcons.edit,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpacing16),

          // End Date Selector (Optional)
          Row(
            children: [
              Text(
                'END DATE (OPTIONAL)',
                style: context.ts(
                  11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (_endDate != null)
                TactileSpringContainer(
                  onTap: () {
                    PesaHaptics.selection();
                    setState(() => _endDate = null);
                  },
                  child: Text(
                    'Clear End Date',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.expenseColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: kSpacing8),
          TactileSpringContainer(
            onTap: () => _pickDate(endDate: true),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing14,
                vertical: kSpacing12,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PesaFlowIcons.calendar,
                    size: 18,
                    color: _endDate != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: kSpacing10),
                  Expanded(
                    child: Text(
                      _endDate != null
                          ? DateFormat('EEEE, d MMMM yyyy').format(_endDate!)
                          : 'No expiration set (continuous)',
                      style: context.ts(
                        14,
                        fontWeight: _endDate != null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _endDate != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _endDate != null ? PesaFlowIcons.edit : PesaFlowIcons.add,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    final theme = Theme.of(context);

    return TactileSpringContainer(
      onTap: _isLoading
          ? null
          : () {
              PesaHaptics.medium();
              _submit();
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: kSpacing16),
        decoration: BoxDecoration(
          color: _isLoading
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isLoading
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEditing ? PesaFlowIcons.check : PesaFlowIcons.add,
                    size: 18,
                    color: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    _isEditing
                        ? 'Update Recurring Flow'
                        : 'Create Recurring Flow',
                    textAlign: TextAlign.center,
                    style: context.ts(
                      16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
