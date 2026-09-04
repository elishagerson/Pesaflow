import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';

class LoanFormScreen extends ConsumerStatefulWidget {
  final String? loanId;
  const LoanFormScreen({this.loanId, super.key});

  @override
  ConsumerState<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends ConsumerState<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _senderController = TextEditingController();
  final _referenceController = TextEditingController();
  final _interestRateController = TextEditingController();
  DateTime _disbursedAt = DateTime.now();
  DateTime? _dueAt;
  Loan? _existingLoan;
  String? _selectedCategory;
  bool _isSaving = false;

  bool get _isDirty {
    return _amountController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _senderController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (widget.loanId != null) _loadExistingLoan();
  }

  Future<void> _loadExistingLoan() async {
    final loan = await ref
        .read(loanRepositoryProvider)
        .getLoanById(widget.loanId!);
    if (loan != null && mounted) {
      setState(() {
        _existingLoan = loan;
        _amountController.text = (loan.amount ~/ 100).toString();
        if (loan.description != null) {
          _descriptionController.text = loan.description!;
        }
        if (loan.sender != null) {
          _senderController.text = loan.sender!;
        }
        if (loan.reference != null) {
          _referenceController.text = loan.reference!;
        }
        _disbursedAt = loan.disbursedAt;
        _dueAt = loan.dueAt;
        _selectedCategory = loan.category;
        if (loan.interestRate != null) {
          _interestRateController.text = loan.interestRate.toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _senderController.dispose();
    _referenceController.dispose();
    _interestRateController.dispose();
    super.dispose();
  }

  static const _loanCategories = [
    'Personal',
    'Business',
    'Mortgage',
    'Car',
    'Education',
    'Medical',
    'Debt Consolidation',
    'Other',
  ];

  static const _categoryIcons = {
    'Personal': PesaFlowIcons.person,
    'Business': PesaFlowIcons.business,
    'Mortgage': PesaFlowIcons.home,
    'Car': PesaFlowIcons.car,
    'Education': PesaFlowIcons.school,
    'Medical': PesaFlowIcons.hospital,
    'Debt Consolidation': PesaFlowIcons.loans,
    'Other': PesaFlowIcons.more,
  };

  Future<void> _pickCategory() async {
    final selected = await showSpringSheet<String>(
      context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.fromLTRB(
            kSpacing16,
            kSpacing12,
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
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: kSpacing16),
              Text(
                'Loan Category',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: kSpacing4),
              Text(
                'Select a category for this loan',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: kSpacing16),
              ...(_loanCategories.map((cat) {
                final isSelected = _selectedCategory == cat;
                final icon = _categoryIcons[cat] ?? PesaFlowIcons.more;
                return Padding(
                  padding: const EdgeInsets.only(bottom: kSpacing6),
                  child: TactileSpringContainer(
                    onTap: () => context.pop(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing14,
                        vertical: kSpacing12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusInput,
                        ),
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                          const SizedBox(width: kSpacing12),
                          Expanded(
                            child: Text(
                              cat,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              PesaFlowIcons.check,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              })),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCategory = selected == 'Other' ? null : selected;
      });
    }
  }

  Future<void> _pickDate({required bool dueDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate
          ? (_dueAt ?? now.add(const Duration(days: 30)))
          : _disbursedAt,
      firstDate: dueDate ? _disbursedAt : DateTime(2020),
      lastDate: dueDate ? now.add(const Duration(days: 365 * 5)) : now,
    );
    if (picked != null) {
      setState(() {
        if (dueDate) {
          _dueAt = picked;
        } else {
          _disbursedAt = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final amountCents = CurrencyFormatter.parseToCents(_amountController.text);

    final activeTrackerId = ref.read(activeTrackerIdProvider);

    if (_existingLoan != null) {
      final paid = _existingLoan!.amount - _existingLoan!.remaining;
      final updatedRemaining = (amountCents - paid).clamp(0, amountCents);
      final updatedLoan = _existingLoan!.copyWith(
        amount: amountCents,
        remaining: updatedRemaining,
        description: _descriptionController.text.trim().isEmpty
            ? const Value(null)
            : Value(_descriptionController.text.trim()),
        sender: _senderController.text.trim().isEmpty
            ? const Value(null)
            : Value(_senderController.text.trim()),
        reference: _referenceController.text.trim().isEmpty
            ? const Value(null)
            : Value(_referenceController.text.trim()),
        disbursedAt: _disbursedAt,
        dueAt: _dueAt != null ? Value(_dueAt) : const Value(null),
        interestRate: double.tryParse(_interestRateController.text) != null
            ? Value(double.tryParse(_interestRateController.text))
            : const Value(null),
        category: _selectedCategory != null
            ? Value(_selectedCategory)
            : const Value(null),
        updatedAt: DateTime.now(),
      );
      try {
        await ref.read(loanRepositoryProvider).updateLoan(updatedLoan);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        CustomToast.show(
          context,
          message: 'Loan updated!',
          type: ToastType.success,
        );
        context.pop();
      } catch (e) {
        HapticFeedback.heavyImpact();
        if (!mounted) return;
        CustomToast.show(
          context,
          message: 'Failed to update loan: $e',
          type: ToastType.error,
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }
    final loanId = const Uuid().v4();
    final loan = Loan(
      id: loanId,
      amount: amountCents,
      remaining: amountCents,
      status: 'active',
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      sender: _senderController.text.trim().isEmpty
          ? null
          : _senderController.text.trim(),
      reference: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      disbursedAt: _disbursedAt,
      dueAt: _dueAt,
      interestRate: double.tryParse(_interestRateController.text),
      category: _selectedCategory,
      trackerId: activeTrackerId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      await ref.read(loanRepositoryProvider).createLoan(loan);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      CustomToast.show(
        context,
        message: 'Loan created!',
        type: ToastType.success,
      );
      context.pop();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Failed to create loan: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

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
        body: Column(
          children: [
            FloatingTopBar(
              title: _existingLoan != null ? 'Edit Loan' : 'Add Loan',
              forceWhite: true,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 8,
                20,
                16,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kSpacing16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StaggeredFadeSlide(
                        index: 0,
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter a valid amount';
                            }
                            final val = CurrencyFormatter.parseToCents(v);
                            if (val <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                          decoration: context.inputDecoration(
                            labelText: 'Loan Amount (Tsh)',
                            hintText: 'e.g. 100000',
                            prefixIcon: const Icon(
                              PesaFlowIcons.money,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      StaggeredFadeSlide(
                        index: 1,
                        child: TextFormField(
                          controller: _descriptionController,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter a description';
                            }
                            return null;
                          },
                          decoration: context.inputDecoration(
                            labelText: 'Description',
                            hintText: 'e.g. M-Pesa Loan, Bank Loan',
                            prefixIcon: const Icon(
                              PesaFlowIcons.edit,
                              size: 18,
                            ),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      StaggeredFadeSlide(
                        index: 2,
                        child: TextField(
                          controller: _senderController,
                          decoration: context.inputDecoration(
                            labelText: 'Lender / Source (optional)',
                            hintText: 'e.g. Vodacom, NMB Bank',
                            prefixIcon: const Icon(
                              PesaFlowIcons.person,
                              size: 18,
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      StaggeredFadeSlide(
                        index: 3,
                        child: TextField(
                          controller: _referenceController,
                          decoration: context.inputDecoration(
                            labelText: 'Reference (optional)',
                            hintText: 'e.g. loan reference number',
                            prefixIcon: const Icon(PesaFlowIcons.tag, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      StaggeredFadeSlide(
                        index: 4,
                        child: InkWell(
                          onTap: () => _pickDate(dueDate: false),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                          child: InputDecorator(
                            decoration: context.inputDecoration(
                              labelText: 'Disbursement Date',
                              prefixIcon: const Icon(
                                PesaFlowIcons.calendar,
                                size: 18,
                              ),
                            ),
                            child: Text(
                              '${_disbursedAt.day}/${_disbursedAt.month}/${_disbursedAt.year}',
                              style: TextStyle(color: onSurface),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      StaggeredFadeSlide(
                        index: 5,
                        child: TextFormField(
                          controller: _interestRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final rate = double.tryParse(v);
                            if (rate == null || rate < 0) {
                              return 'Enter a valid rate';
                            }
                            return null;
                          },
                          decoration: context.inputDecoration(
                            labelText: 'Interest Rate',
                            hintText: 'e.g. 18.5',
                            prefixIcon: const Icon(
                              PesaFlowIcons.percent,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      StaggeredFadeSlide(
                        index: 6,
                        child: InkWell(
                          onTap: () => _pickDate(dueDate: true),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                          child: InputDecorator(
                            decoration: context.inputDecoration(
                              labelText: 'Due Date (optional)',
                              prefixIcon: const Icon(
                                PesaFlowIcons.calendar,
                                size: 18,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _dueAt != null
                                      ? '${_dueAt!.day}/${_dueAt!.month}/${_dueAt!.year}'
                                      : 'Set due date',
                                  style: TextStyle(
                                    color: _dueAt != null
                                        ? onSurface
                                        : onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                if (_dueAt != null)
                                  GestureDetector(
                                    onTap: () => setState(() => _dueAt = null),
                                    child: Icon(
                                      PesaFlowIcons.close,
                                      size: 18,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      StaggeredFadeSlide(
                        index: 7,
                        child: InkWell(
                          onTap: _pickCategory,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                          child: InputDecorator(
                            decoration: context.inputDecoration(
                              labelText: 'Category (optional)',
                              prefixIcon: const Icon(
                                PesaFlowIcons.category,
                                size: 18,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedCategory ?? 'Select category',
                                  style: TextStyle(
                                    color: _selectedCategory != null
                                        ? onSurface
                                        : onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                Icon(
                                  PesaFlowIcons.chevronRight,
                                  size: 18,
                                  color: onSurface.withValues(alpha: 0.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing32),
                      StaggeredFadeSlide(
                        index: 8,
                        child: TactileSpringContainer(
                          onTap: _isSaving ? null : _submit,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: kSpacing16,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(
                                    alpha: _isSaving ? 0.6 : 1.0,
                                  ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusInput,
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: Center(
                                      child: SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    _existingLoan != null
                                        ? 'Update Loan'
                                        : 'Add Loan',
                                    textAlign: TextAlign.center,
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
                    ],
                  ),
                ),
              ), // SingleChildScrollView
            ), // Expanded
          ], // Column children
        ), // Column
      ), // Scaffold
    ); // PopScope
  }
}
