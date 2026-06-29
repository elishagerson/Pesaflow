import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
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
        if (loan.description != null)
          _descriptionController.text = loan.description!;
        if (loan.sender != null) _senderController.text = loan.sender!;
        if (loan.reference != null) _referenceController.text = loan.reference!;
        _disbursedAt = loan.disbursedAt;
        _dueAt = loan.dueAt;
        if (loan.interestRate != null)
          _interestRateController.text = loan.interestRate.toString();
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
    if (!_formKey.currentState!.validate()) return;

    final amountCents = CurrencyFormatter.parseToCents(_amountController.text);
    if (amountCents <= 0) return;
    final activeTrackerId = ref.read(activeTrackerIdProvider);

    if (_existingLoan != null) {
      final updatedRemaining = amountCents.clamp(0, _existingLoan!.remaining);
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
        updatedAt: DateTime.now(),
      );
      try {
        await ref.read(loanRepositoryProvider).updateLoan(updatedLoan);
        if (!mounted) return;
        context.pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update loan: $e')));
      }
    } else {
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
        trackerId: activeTrackerId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      try {
        await ref.read(loanRepositoryProvider).createLoan(loan);
        if (!mounted) return;
        context.pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create loan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputFill = isDark
        ? const Color(0xFF1B1C22)
        : const Color(0xFFF2F2F7);

    return Scaffold(
      appBar: AppBar(
        title: Text(_existingLoan != null ? 'Edit Loan' : 'Add Loan'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
                  decoration: InputDecoration(
                    labelText: 'Loan Amount (Tsh)',
                    hintText: 'e.g. 100000',
                    prefixIcon: const Icon(Icons.money_rounded, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Enter loan amount';
                    final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
                    final parsed = int.tryParse(cleaned);
                    if (parsed == null || parsed <= 0)
                      return 'Enter a valid amount';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: kSpacing16),
              StaggeredFadeSlide(
                index: 1,
                child: TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. M-Pesa Loan, Bank Loan',
                    prefixIcon: const Icon(PesaFlowIcons.edit, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
                  decoration: InputDecoration(
                    labelText: 'Lender / Source (optional)',
                    hintText: 'e.g. Vodacom, NMB Bank',
                    prefixIcon: const Icon(Icons.person_rounded, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
                  decoration: InputDecoration(
                    labelText: 'Reference (optional)',
                    hintText: 'e.g. loan reference number',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSpacing16),
              StaggeredFadeSlide(
                index: 4,
                child: InkWell(
                  onTap: () => _pickDate(dueDate: false),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Disbursement Date',
                      prefixIcon: const Icon(PesaFlowIcons.calendar, size: 18),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    child: Text(
                      '${_disbursedAt.day}/${_disbursedAt.month}/${_disbursedAt.year}',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSpacing16),
              StaggeredFadeSlide(
                index: 5,
                child: TextField(
                  controller: _interestRateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Interest Rate (optional)',
                    hintText: 'e.g. 18.5',
                    prefixIcon: const Icon(Icons.percent_rounded, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSpacing16),
              StaggeredFadeSlide(
                index: 6,
                child: InkWell(
                  onTap: () => _pickDate(dueDate: true),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Due Date (optional)',
                      prefixIcon: const Icon(PesaFlowIcons.calendar, size: 18),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
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
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[400]),
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
              const SizedBox(height: kSpacing32),
              StaggeredFadeSlide(
                index: 7,
                child: TactileSpringContainer(
                  onTap: _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: kSpacing16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _existingLoan != null ? 'Update Loan' : 'Add Loan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
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
