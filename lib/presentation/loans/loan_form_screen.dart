import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/common/widgets/ios_date_picker_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/shake_widget.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class _LoanStarter {
  final String title;
  final String lender;
  final String category;
  final int defaultAmountCents;
  final int termDays;
  final double? interestRate;
  final Color color;
  final IconData icon;

  const _LoanStarter({
    required this.title,
    required this.lender,
    required this.category,
    required this.defaultAmountCents,
    required this.termDays,
    this.interestRate,
    required this.color,
    required this.icon,
  });
}

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
  bool _shakeFields = false;

  static const List<_LoanStarter> _starters = [
    _LoanStarter(
      title: 'M-Pesa Songesha',
      lender: 'Vodacom M-Pesa',
      category: 'Personal',
      defaultAmountCents: 5000000, // 50,000 Tsh
      termDays: 30,
      interestRate: 5.0,
      color: Color(0xFFE21A2C),
      icon: PesaFlowIcons.offline,
    ),
    _LoanStarter(
      title: 'Tigo Nivushe',
      lender: 'Tigo Pesa',
      category: 'Personal',
      defaultAmountCents: 10000000, // 100,000 Tsh
      termDays: 30,
      interestRate: 6.0,
      color: Color(0xFF0066B3),
      icon: PesaFlowIcons.offline,
    ),
    _LoanStarter(
      title: 'Airtel Timiza',
      lender: 'Airtel Money',
      category: 'Personal',
      defaultAmountCents: 5000000, // 50,000 Tsh
      termDays: 30,
      interestRate: 5.5,
      color: Color(0xFFED1C24),
      icon: PesaFlowIcons.offline,
    ),
    _LoanStarter(
      title: 'NMB Salary Advance',
      lender: 'NMB Bank',
      category: 'Personal',
      defaultAmountCents: 50000000, // 500,000 Tsh
      termDays: 90,
      interestRate: 12.0,
      color: Color(0xFF003DA5),
      icon: PesaFlowIcons.loans,
    ),
    _LoanStarter(
      title: 'CRDB Personal Credit',
      lender: 'CRDB Bank',
      category: 'Personal',
      defaultAmountCents: 150000000, // 1,500,000 Tsh
      termDays: 180,
      interestRate: 14.0,
      color: Color(0xFF0284C7),
      icon: PesaFlowIcons.loans,
    ),
    _LoanStarter(
      title: 'Family / SACCOS',
      lender: 'Family / SACCOS',
      category: 'Personal',
      defaultAmountCents: 20000000, // 200,000 Tsh
      termDays: 60,
      interestRate: null,
      color: Color(0xFF10B981),
      icon: PesaFlowIcons.person,
    ),
  ];

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

  static const _quickLenders = [
    'Vodacom',
    'Tigo',
    'Airtel',
    'NMB',
    'CRDB',
    'NBC',
    'Family',
    'SACCOS',
  ];

  bool get _isDirty {
    return _amountController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _senderController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_rebuildOnInput);
    _interestRateController.addListener(_rebuildOnInput);
    if (widget.loanId != null) {
      _loadExistingLoan();
    }
  }

  void _rebuildOnInput() {
    if (mounted) setState(() {});
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

  void _applyStarter(_LoanStarter starter) {
    PesaHaptics.selection();
    setState(() {
      _amountController.text = (starter.defaultAmountCents ~/ 100).toString();
      _descriptionController.text = starter.title;
      _senderController.text = starter.lender;
      _selectedCategory = starter.category;
      if (starter.interestRate != null) {
        _interestRateController.text = starter.interestRate.toString();
      } else {
        _interestRateController.clear();
      }
      _dueAt = _disbursedAt.add(Duration(days: starter.termDays));
    });
  }

  void _appendAmount(int cents) {
    PesaHaptics.selection();
    final current = CurrencyFormatter.parseToCents(_amountController.text);
    final total = current + cents;
    _amountController.text = (total ~/ 100).toString();
    setState(() {});
  }

  void _clearAmount() {
    PesaHaptics.selection();
    _amountController.clear();
    setState(() {});
  }

  void _setTermDays(int days) {
    PesaHaptics.selection();
    setState(() {
      _dueAt = _disbursedAt.add(Duration(days: days));
    });
  }

  Future<void> _pickDate({required bool dueDate}) async {
    final now = DateTime.now();
    final picked = await showIosDatePicker(
      context,
      initialDate: dueDate
          ? (_dueAt ?? now.add(const Duration(days: 30)))
          : _disbursedAt,
      firstDate: dueDate ? _disbursedAt : DateTime(2020),
      lastDate: dueDate ? now.add(const Duration(days: 365 * 10)) : now,
      title: dueDate ? 'Due Date' : 'Disbursement Date',
    );
    if (picked != null && mounted) {
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
    if (!_formKey.currentState!.validate()) {
      setState(() => _shakeFields = true);
      PesaHaptics.error();
      Future.delayed(MotionTokens.durationDelayedNav, () {
        if (mounted) setState(() => _shakeFields = false);
      });
      return;
    }

    setState(() => _isSaving = true);
    final amountCents = CurrencyFormatter.parseToCents(_amountController.text);
    final activeTrackerId = ref.read(activeTrackerIdProvider);

    final desc = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : (_senderController.text.trim().isNotEmpty
              ? '${_senderController.text.trim()} Loan'
              : 'Personal Loan');

    if (_existingLoan != null) {
      final paid = _existingLoan!.amount - _existingLoan!.remaining;
      final updatedRemaining = (amountCents - paid).clamp(0, amountCents);
      final updatedLoan = _existingLoan!.copyWith(
        amount: amountCents,
        remaining: updatedRemaining,
        description: Value(desc),
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
        PesaHaptics.success();
        CustomToast.show(
          context,
          message: 'Loan updated successfully!',
          type: ToastType.success,
        );
        context.pop();
      } catch (e) {
        PesaHaptics.error();
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
      description: desc,
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
      PesaHaptics.success();
      CustomToast.show(
        context,
        message: 'Loan created successfully!',
        type: ToastType.success,
      );
      context.pop();
    } catch (e) {
      PesaHaptics.error();
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
    final isEditing = _existingLoan != null;

    final amountCents = CurrencyFormatter.parseToCents(_amountController.text);
    final rate = double.tryParse(_interestRateController.text);
    final interestCents = (rate != null && rate > 0 && amountCents > 0)
        ? (amountCents * (rate / 100)).round()
        : 0;
    final totalPayoffCents = amountCents + interestCents;

    int? termDays;
    if (_dueAt != null) {
      termDays = math.max(1, _dueAt!.difference(_disbursedAt).inDays);
    }

    int? monthlyInstallmentCents;
    if (totalPayoffCents > 0 && termDays != null) {
      final months = math.max(1.0, termDays / 30.0);
      monthlyInstallmentCents = (totalPayoffCents / months).round();
    }

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
        body: Column(
          children: [
            FloatingTopBar(
              title: isEditing ? 'Edit Loan' : 'New Loan',
              padding: EdgeInsets.fromLTRB(
                kSpacing20,
                MediaQuery.paddingOf(context).top + kSpacing8,
                kSpacing20,
                kSpacing16,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  kSpacing16,
                  kSpacing4,
                  kSpacing16,
                  kSpacing32,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 1. Starters Carousel (Only in create mode) ──
                      if (!isEditing) ...[
                        _buildSectionHeader(
                          title: 'QUICK STARTERS',
                          subtitle: 'Tap a popular Tanzanian lending preset',
                        ),
                        const SizedBox(height: kSpacing10),
                        _buildStartersCarousel(),
                        const SizedBox(height: kSpacing20),
                      ],

                      // ── 2. Hero Amount Input Card ──
                      _buildHeroAmountCard(theme, onSurface),
                      const SizedBox(height: kSpacing16),

                      // ── 3. Live Payoff & Projection Card ──
                      _buildLiveProjectionCard(
                        theme: theme,
                        onSurface: onSurface,
                        amountCents: amountCents,
                        interestCents: interestCents,
                        totalPayoffCents: totalPayoffCents,
                        rate: rate,
                        termDays: termDays,
                        monthlyInstallmentCents: monthlyInstallmentCents,
                      ),
                      const SizedBox(height: kSpacing20),

                      // ── 4. Card: Lender & Purpose Details ──
                      _buildCard(
                        theme: theme,
                        title: 'LENDER & PURPOSE',
                        children: [
                          _buildQuickLenderChips(theme),
                          const SizedBox(height: kSpacing12),
                          ShakeWidget(
                            shaking: _shakeFields,
                            child: TextFormField(
                              controller: _descriptionController,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  if (_senderController.text.trim().isEmpty) {
                                    return 'Enter a description or lender name';
                                  }
                                }
                                return null;
                              },
                              decoration: context.inputDecoration(
                                labelText: 'Loan Purpose / Description',
                                hintText:
                                    'e.g. M-Pesa Songesha, Working Capital',
                                prefixIcon: const Icon(
                                  PesaFlowIcons.edit,
                                  size: 18,
                                ),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          const SizedBox(height: kSpacing12),
                          TextField(
                            controller: _senderController,
                            decoration: context.inputDecoration(
                              labelText: 'Lender / Facility Name (Optional)',
                              hintText: 'e.g. Vodacom, NMB Bank, John Doe',
                              prefixIcon: const Icon(
                                PesaFlowIcons.person,
                                size: 18,
                              ),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: kSpacing12),
                          TextField(
                            controller: _referenceController,
                            decoration: context.inputDecoration(
                              labelText:
                                  'Reference / Account Number (Optional)',
                              hintText: 'e.g. LN-829103, Contract No.',
                              prefixIcon: const Icon(
                                PesaFlowIcons.tag,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing16),

                      // ── 5. Card: Category & Schedule ──
                      _buildCard(
                        theme: theme,
                        title: 'CATEGORY & REPAYMENT SCHEDULE',
                        children: [
                          _buildCategorySelector(theme),
                          const SizedBox(height: kSpacing16),
                          _buildTermDurationChips(theme),
                          const SizedBox(height: kSpacing16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateTile(
                                  theme: theme,
                                  label: 'Disbursed',
                                  date: _disbursedAt,
                                  onTap: () => _pickDate(dueDate: false),
                                ),
                              ),
                              const SizedBox(width: kSpacing12),
                              Expanded(
                                child: _buildDateTile(
                                  theme: theme,
                                  label: 'Due Date',
                                  date: _dueAt,
                                  onTap: () => _pickDate(dueDate: true),
                                  onClear: _dueAt != null
                                      ? () => setState(() => _dueAt = null)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing16),

                      // ── 6. Card: Interest Rate & Surcharges ──
                      _buildCard(
                        theme: theme,
                        title: 'INTEREST & FEES',
                        children: [
                          _buildInterestPresetsRow(theme, rate),
                          const SizedBox(height: kSpacing12),
                          TextFormField(
                            controller: _interestRateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final parsed = double.tryParse(v);
                              if (parsed == null || parsed < 0) {
                                return 'Enter a valid rate (e.g. 10)';
                              }
                              return null;
                            },
                            decoration: context.inputDecoration(
                              labelText: 'Interest Rate (%) (Optional)',
                              hintText: 'e.g. 10.0',
                              prefixIcon: const Icon(
                                PesaFlowIcons.percent,
                                size: 18,
                              ),
                              suffixIcon: rate != null && rate > 0
                                  ? Container(
                                      margin: const EdgeInsets.only(
                                        right: kSpacing12,
                                        top: kSpacing8,
                                        bottom: kSpacing8,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing8,
                                        vertical: kSpacing4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.appColors.expenseColor
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusPill,
                                        ),
                                      ),
                                      child: Text(
                                        '+${CurrencyFormatter.formatCents(interestCents)}',
                                        style: context.ts(
                                          11,
                                          fontWeight: FontWeight.w700,
                                          color: context.appColors.expenseColor,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing28),

                      // ── 7. Executive Action Button ──
                      TactileSpringContainer(
                        onTap: _isSaving ? null : _submit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: kSpacing16,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: _isSaving ? 0.6 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: _isSaving
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isEditing
                                          ? PesaFlowIcons.check
                                          : PesaFlowIcons.add,
                                      size: 18,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                    const SizedBox(width: kSpacing8),
                                    Text(
                                      isEditing ? 'Update Loan' : 'Record Loan',
                                      style: context.ts(
                                        15,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
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

  // ─────────────────────────────────────────────────────────────
  // Helper Widgets
  // ─────────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.ts(
            11,
            fontWeight: FontWeight.w800,
            color: context.appColors.textMedium,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: context.ts(12, color: context.appColors.textLow)),
      ],
    );
  }

  Widget _buildStartersCarousel() {
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
              width: 146,
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing12,
                vertical: kSpacing10,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(
                  color: starter.color.withValues(alpha: 0.28),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: starter.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCompact,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          starter.icon,
                          size: 16,
                          color: starter.color,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: starter.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          '${starter.termDays}d',
                          style: context.ts(
                            10,
                            fontWeight: FontWeight.w700,
                            color: starter.color,
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
                        style: context.ts(12, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        CurrencyFormatter.formatCents(
                          starter.defaultAmountCents,
                        ),
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textMedium,
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

  Widget _buildHeroAmountCard(ThemeData theme, Color onSurface) {
    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRINCIPAL AMOUNT',
                style: context.ts(
                  11,
                  fontWeight: FontWeight.w800,
                  color: context.appColors.textMedium,
                  letterSpacing: 0.6,
                ),
              ),
              if (_amountController.text.isNotEmpty)
                TactileSpringContainer(
                  onTap: _clearAmount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacing8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      'Clear',
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.textLow,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: kSpacing10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing12,
                  vertical: kSpacing8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'TSh',
                  style: context.ts(
                    16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
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
                      color: onSurface,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter an amount';
                      }
                      final cents = CurrencyFormatter.parseToCents(v);
                      if (cents <= 0) {
                        return 'Amount must be greater than 0';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAmountChip('+50K', () => _appendAmount(5000000)),
                const SizedBox(width: kSpacing6),
                _buildAmountChip('+100K', () => _appendAmount(10000000)),
                const SizedBox(width: kSpacing6),
                _buildAmountChip('+500K', () => _appendAmount(50000000)),
                const SizedBox(width: kSpacing6),
                _buildAmountChip('+1M', () => _appendAmount(100000000)),
                const SizedBox(width: kSpacing6),
                _buildAmountChip('+5M', () => _appendAmount(500000000)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountChip(String label, VoidCallback onTap) {
    return TactileSpringContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing10,
          vertical: kSpacing6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: context.ts(
            11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveProjectionCard({
    required ThemeData theme,
    required Color onSurface,
    required int amountCents,
    required int interestCents,
    required int totalPayoffCents,
    required double? rate,
    required int? termDays,
    required int? monthlyInstallmentCents,
  }) {
    final hasAmount = amountCents > 0;
    final primaryColor = theme.colorScheme.primary;
    final expenseColor = context.appColors.expenseColor;

    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        border: Border.all(
          color: primaryColor.withValues(alpha: hasAmount ? 0.35 : 0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: hasAmount ? primaryColor : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    'LIVE LOAN PROJECTION',
                    style: context.ts(
                      10,
                      fontWeight: FontWeight.w800,
                      color: hasAmount
                          ? primaryColor
                          : context.appColors.textLow,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              if (_dueAt != null && termDays != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'Due in $termDays days',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Total Payoff: ',
                style: context.ts(
                  13,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textMedium,
                ),
              ),
              Text(
                CurrencyFormatter.formatCents(totalPayoffCents),
                style: context.ts(
                  20,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          // Split visual bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: math.max(1, amountCents),
                    child: Container(color: primaryColor),
                  ),
                  if (interestCents > 0)
                    Expanded(
                      flex: interestCents,
                      child: Container(color: expenseColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpacing12),
          // Timeline visual
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing12,
              vertical: kSpacing8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        PesaFlowIcons.calendar,
                        size: 13,
                        color: primaryColor,
                      ),
                      const SizedBox(width: kSpacing4),
                      Expanded(
                        child: Text(
                          'Disbursed: ${DateFormat('d MMM yyyy').format(_disbursedAt)}',
                          style: context.ts(
                            11,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.textMedium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpacing6),
                  child: Icon(
                    PesaFlowIcons.arrowForward,
                    size: 11,
                    color: context.appColors.textLow,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        PesaFlowIcons.schedule,
                        size: 13,
                        color: _dueAt != null ? expenseColor : primaryColor,
                      ),
                      const SizedBox(width: kSpacing4),
                      Expanded(
                        child: Text(
                          _dueAt != null
                              ? 'Due: ${DateFormat('d MMM yyyy').format(_dueAt!)}'
                              : 'No due date',
                          style: context.ts(
                            11,
                            fontWeight: FontWeight.w700,
                            color: _dueAt != null
                                ? onSurface
                                : context.appColors.textLow,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Principal',
                    style: context.ts(11, color: context.appColors.textLow),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(amountCents),
                    style: context.ts(12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Interest (${rate != null && rate > 0 ? '$rate%' : '0%'})',
                    style: context.ts(11, color: context.appColors.textLow),
                  ),
                  Text(
                    interestCents > 0
                        ? '+${CurrencyFormatter.formatCents(interestCents)}'
                        : 'None',
                    style: context.ts(
                      12,
                      fontWeight: FontWeight.w700,
                      color: interestCents > 0 ? expenseColor : onSurface,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Est. Monthly',
                    style: context.ts(11, color: context.appColors.textLow),
                  ),
                  Text(
                    monthlyInstallmentCents != null
                        ? '~${CurrencyFormatter.formatCents(monthlyInstallmentCents)}'
                        : (hasAmount
                              ? CurrencyFormatter.formatCents(totalPayoffCents)
                              : '—'),
                    style: context.ts(12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.ts(
              11,
              fontWeight: FontWeight.w800,
              color: context.appColors.textMedium,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: kSpacing12),
          ...children,
        ],
      ),
    );
  }

  static const _lenderBrandColors = {
    'Vodacom': Color(0xFFE21A2C),
    'Tigo': Color(0xFF0066B3),
    'Airtel': Color(0xFFED1C24),
    'NMB': Color(0xFF003DA5),
    'CRDB': Color(0xFF0066B3),
    'NBC': Color(0xFF003366),
    'Family': Color(0xFF10B981),
    'SACCOS': Color(0xFF059669),
  };

  Widget _buildInterestPresetsRow(ThemeData theme, double? currentRate) {
    const presets = [
      {'label': '0% Free', 'rate': 0.0},
      {'label': '5% Songesha', 'rate': 5.0},
      {'label': '10% Advance', 'rate': 10.0},
      {'label': '14% Bank Loan', 'rate': 14.0},
      {'label': '18% Commercial', 'rate': 18.0},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((item) {
          final r = item['rate'] as double;
          final isSelected =
              currentRate != null && (currentRate - r).abs() < 0.01;
          final label = item['label'] as String;

          return Padding(
            padding: const EdgeInsets.only(right: kSpacing6),
            child: TactileSpringContainer(
              onTap: () {
                PesaHaptics.selection();
                setState(() {
                  _interestRateController.text = r == 0.0 ? '0' : r.toString();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing10,
                  vertical: kSpacing6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.25,
                          ),
                  ),
                ),
                child: Text(
                  label,
                  style: context.ts(
                    11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
    );
  }

  Widget _buildQuickLenderChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _quickLenders.map((lender) {
          final isSelected = _senderController.text.contains(lender);
          final brandColor =
              _lenderBrandColors[lender] ?? theme.colorScheme.primary;

          return Padding(
            padding: const EdgeInsets.only(right: kSpacing6),
            child: TactileSpringContainer(
              onTap: () {
                PesaHaptics.selection();
                setState(() {
                  _senderController.text = lender;
                  if (_descriptionController.text.isEmpty) {
                    _descriptionController.text = '$lender Loan';
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing10,
                  vertical: kSpacing6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? brandColor.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: isSelected
                        ? brandColor
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: brandColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: kSpacing6),
                    Text(
                      lender,
                      style: context.ts(
                        11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? brandColor
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _loanCategories.map((cat) {
          final isSelected = (_selectedCategory ?? 'Personal') == cat;
          final icon = _categoryIcons[cat] ?? PesaFlowIcons.more;
          final primary = theme.colorScheme.primary;

          return Padding(
            padding: const EdgeInsets.only(right: kSpacing8),
            child: TactileSpringContainer(
              onTap: () {
                PesaHaptics.selection();
                setState(() {
                  _selectedCategory = cat == 'Other' ? null : cat;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing12,
                  vertical: kSpacing8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isSelected
                        ? primary
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected
                          ? primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: kSpacing6),
                    Text(
                      cat,
                      style: context.ts(
                        12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTermDurationChips(ThemeData theme) {
    const terms = [
      {'label': '14 Days', 'days': 14},
      {'label': '30 Days', 'days': 30},
      {'label': '60 Days', 'days': 60},
      {'label': '90 Days', 'days': 90},
      {'label': '6 Months', 'days': 180},
      {'label': '1 Year', 'days': 365},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TERM DURATION PRESETS',
          style: context.ts(
            10,
            fontWeight: FontWeight.w700,
            color: context.appColors.textLow,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: kSpacing8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: terms.map((item) {
              final days = item['days'] as int;
              final label = item['label'] as String;
              final isCurrent =
                  _dueAt != null &&
                  _dueAt!.difference(_disbursedAt).inDays == days;

              return Padding(
                padding: const EdgeInsets.only(right: kSpacing6),
                child: TactileSpringContainer(
                  onTap: () => _setTermDays(days),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacing10,
                      vertical: kSpacing6,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.2,
                              ),
                      ),
                    ),
                    child: Text(
                      label,
                      style: context.ts(
                        11,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isCurrent
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
      ],
    );
  }

  Widget _buildDateTile({
    required ThemeData theme,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final onSurface = theme.colorScheme.onSurface;
    final dateStr = date != null
        ? DateFormat('d MMM yyyy').format(date)
        : 'Set date';

    return TactileSpringContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing12,
          vertical: kSpacing12,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              PesaFlowIcons.calendar,
              size: 16,
              color: date != null
                  ? theme.colorScheme.primary
                  : onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: kSpacing8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.ts(10, color: context.appColors.textLow),
                  ),
                  Text(
                    dateStr,
                    style: context.ts(
                      13,
                      fontWeight: date != null
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: date != null
                          ? onSurface
                          : onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  PesaFlowIcons.close,
                  size: 16,
                  color: onSurface.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
