import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/glass_list_container.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/recurring/utils/affordability_calculator.dart';
import 'package:pesaflow/presentation/recurring/utils/recurring_schedule_helpers.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/services/notification_service.dart';

/// "Can I afford it?" view where users can type an item name, attach a photo,
/// and enter a price to evaluate affordability against balance, upcoming bills,
/// paydays, and budgets.
class AffordabilityCheckView extends ConsumerStatefulWidget {
  final List<RecurringTransaction> allRecurring;
  final int currentBalanceCents;

  const AffordabilityCheckView({
    super.key,
    required this.allRecurring,
    required this.currentBalanceCents,
  });

  @override
  ConsumerState<AffordabilityCheckView> createState() =>
      _AffordabilityCheckViewState();
}

class _AffordabilityCheckViewState
    extends ConsumerState<AffordabilityCheckView> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  String? _photoPath;
  bool _pickingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      final pickedPath = result.firstOrNull?.path;
      if (pickedPath == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final wishlistDir = Directory(p.join(appDir.path, 'wishlist_photos'));
      if (!await wishlistDir.exists()) {
        await wishlistDir.create(recursive: true);
      }
      final ext = p.extension(pickedPath);
      final destPath = p.join(
        wishlistDir.path,
        'item_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(pickedPath).copy(destPath);

      if (mounted) {
        PesaHaptics.light();
        setState(() => _photoPath = destPath);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Could not attach photo',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _saveCurrentCheck({
    required String itemName,
    required int priceCents,
    required String storeNote,
  }) async {
    final repo = ref.read(settingsRepositoryProvider);
    final existing =
        ref.read(savedAffordabilityChecksStreamProvider).asData?.value ?? [];
    final entry = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': itemName,
      'priceCents': priceCents,
      'store': storeNote,
      'photoPath': _photoPath,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final updated = [entry, ...existing];
    await repo.setSetting('saved_affordability_checks', jsonEncode(updated));
    if (mounted) {
      PesaHaptics.medium();
      CustomToast.show(
        context,
        message: 'Saved "$itemName" to wishlist',
        type: ToastType.success,
      );
    }
  }

  Future<void> _deleteSavedCheck(String id) async {
    final repo = ref.read(settingsRepositoryProvider);
    final existing =
        ref.read(savedAffordabilityChecksStreamProvider).asData?.value ?? [];
    final updated = existing.where((e) => e['id'] != id).toList();
    await repo.setSetting('saved_affordability_checks', jsonEncode(updated));
    PesaHaptics.light();
  }

  void _loadSavedCheck(Map<String, dynamic> item) {
    setState(() {
      _nameController.text = (item['title'] as String?) ?? '';
      final cents = (item['priceCents'] as int?) ?? 0;
      _priceController.text = cents > 0 ? (cents ~/ 100).toString() : '';
      _noteController.text = (item['store'] as String?) ?? '';
      _photoPath = item['photoPath'] as String?;
    });
    PesaHaptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // Compute remaining active budget headroom.
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final remainingBudgetCents = budgetsAsync.when(
      data: (budgets) => budgets.fold<int>(
        0,
        (sum, b) =>
            sum + (b.budget.amount - b.spentInPeriod).clamp(0, 1 << 62).toInt(),
      ),
      loading: () => 0,
      error: (_, _) => 0,
    );

    // Real 30-day average daily expense burn rate.
    final estimatedDailySpend =
        ref.watch(thirtyDayDailyBurnRateProvider).asData?.value ?? 0;
    final savedChecks =
        ref.watch(savedAffordabilityChecksStreamProvider).asData?.value ?? [];

    final priceCents = CurrencyFormatter.parseToCents(_priceController.text);
    final itemName = _nameController.text.trim().isEmpty
        ? 'Desired item'
        : _nameController.text.trim();
    final storeNote = _noteController.text.trim();

    final result = priceCents > 0
        ? evaluateAffordability(
            priceCents: priceCents,
            currentBalanceCents: widget.currentBalanceCents,
            allRecurring: widget.allRecurring,
            estimatedDailySpendCents: estimatedDailySpend,
            remainingBudgetHeadroomCents: remainingBudgetCents,
          )
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpacing16,
        kSpacing12,
        kSpacing16,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: kSpacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Can I afford it?',
                  style: context.ts(
                    24,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'enter an item, price & optional photo',
                  style: context.ts(
                    16,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.textMedium,
                  ),
                ),
              ],
            ),
          ),

          // Input Card
          PesaSurface.bleed(
            fill: theme.colorScheme.surfaceContainerHigh,
            radius: AppTheme.radiusDialog,
            padding: const EdgeInsets.all(kSpacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Photo attachment button / thumbnail
                    TactileSpringContainer(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                          border: Border.all(color: context.appColors.hairline),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _photoPath != null &&
                                File(_photoPath!).existsSync()
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(_photoPath!),
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _photoPath = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.squircleRadius(16),
                                          ),
                                        ),
                                        child: const Icon(
                                          PesaFlowIcons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PesaFlowIcons.upload,
                                    size: 18,
                                    color: context.appColors.textMedium,
                                  ),
                                  const SizedBox(height: kSpacing2),
                                  Text(
                                    'Photo',
                                    style: context.ts(
                                      10,
                                      fontWeight: FontWeight.w600,
                                      color: context.appColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: kSpacing12),
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                            textCapitalization: TextCapitalization.sentences,
                            style: context.ts(14, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'What do you want to buy?',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: kSpacing12,
                                vertical: kSpacing10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusInput,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: kSpacing8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _priceController,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: context.ts(
                                    14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: CurrencyFormatter.currencyPrefix,
                                    hintText: 'Price',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing12,
                                      vertical: kSpacing10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusInput,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: kSpacing8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _noteController,
                                  onChanged: (_) => setState(() {}),
                                  textCapitalization: TextCapitalization.words,
                                  style: context.ts(
                                    13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Store',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing10,
                                      vertical: kSpacing10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusInput,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (result != null) ...[
            const SizedBox(height: kSpacing14),
            _ResultCard(
              itemName: itemName,
              storeNote: storeNote,
              priceCents: priceCents,
              photoPath: _photoPath,
              result: result,
            ),
            const SizedBox(height: kSpacing14),
            _ActionButtonsRow(
              itemName: itemName,
              priceCents: priceCents,
              result: result,
            ),
            const SizedBox(height: kSpacing10),
            Center(
              child: TextButton.icon(
                onPressed: () => _saveCurrentCheck(
                  itemName: itemName,
                  priceCents: priceCents,
                  storeNote: storeNote,
                ),
                icon: const Icon(PesaFlowIcons.bookmark, size: 16),
                label: const Text('Save to Wishlist'),
              ),
            ),
          ],

          if (savedChecks.isNotEmpty) ...[
            const SizedBox(height: kSpacing16),
            Text(
              'SAVED CHECKS (${savedChecks.length})',
              style: context
                  .ts(
                    10,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.textMedium,
                  )
                  .copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: kSpacing8),
            GlassListContainer(
              child: Column(
                children: savedChecks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final id = (item['id'] as String?) ?? '';
                  final title = (item['title'] as String?) ?? 'Saved item';
                  final cents = (item['priceCents'] as int?) ?? 0;
                  final store = (item['store'] as String?) ?? '';
                  final thumb = item['photoPath'] as String?;
                  final itemResult = cents > 0
                      ? evaluateAffordability(
                          priceCents: cents,
                          currentBalanceCents: widget.currentBalanceCents,
                          allRecurring: widget.allRecurring,
                          estimatedDailySpendCents: estimatedDailySpend,
                          remainingBudgetHeadroomCents: remainingBudgetCents,
                        )
                      : null;
                  final badgeColor = switch (itemResult?.status) {
                    AffordabilityStatus.affordableToday ||
                    AffordabilityStatus.bestAfterPayday =>
                      context.appColors.incomeColor,
                    AffordabilityStatus.needsAdjustment =>
                      context.appColors.warningColor,
                    _ => context.appColors.expenseColor,
                  };
                  final badgeLabel = switch (itemResult?.status) {
                    AffordabilityStatus.affordableToday => 'Affordable',
                    AffordabilityStatus.bestAfterPayday => 'After payday',
                    AffordabilityStatus.needsAdjustment => 'Adjust',
                    _ => 'Not ready',
                  };

                  return Column(
                    children: [
                      TactileSpringContainer(
                        onTap: () => _loadSavedCheck(item),
                        child: Padding(
                          padding: const EdgeInsets.all(kSpacing12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: thumb != null &&
                                        File(thumb).existsSync()
                                    ? Image.file(
                                        File(thumb),
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(
                                        PesaFlowIcons.card,
                                        size: 18,
                                        color: context.appColors.textMedium,
                                      ),
                              ),
                              const SizedBox(width: kSpacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: context.ts(
                                        14,
                                        fontWeight: FontWeight.w700,
                                        color: onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      store.isNotEmpty
                                          ? '$store · ${CurrencyFormatter.formatCompact(cents)}'
                                          : CurrencyFormatter.formatCompact(
                                              cents,
                                            ),
                                      style: context.ts(
                                        12,
                                        color: context.appColors.textMedium,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kSpacing8,
                                  vertical: kSpacing2,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: context.ts(
                                    10,
                                    fontWeight: FontWeight.w700,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: kSpacing6),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  PesaFlowIcons.close,
                                  size: 16,
                                  color: context.appColors.textMedium,
                                ),
                                onPressed: () => _deleteSavedCheck(id),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (idx < savedChecks.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: context.appColors.hairline,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String itemName;
  final String storeNote;
  final int priceCents;
  final String? photoPath;
  final AffordabilityResult result;

  const _ResultCard({
    required this.itemName,
    required this.storeNote,
    required this.priceCents,
    required this.photoPath,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final statusColor = switch (result.status) {
      AffordabilityStatus.affordableToday ||
      AffordabilityStatus.bestAfterPayday => context.appColors.incomeColor,
      AffordabilityStatus.needsAdjustment => context.appColors.warningColor,
      AffordabilityStatus.notSupported => context.appColors.expenseColor,
    };

    return PesaSurface.bleed(
      fill: theme.colorScheme.surfaceContainerHigh,
      radius: AppTheme.radiusDialog,
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Preview Row
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoPath != null && File(photoPath!).existsSync()
                    ? Image.file(File(photoPath!), fit: BoxFit.cover)
                    : Icon(
                        PesaFlowIcons.card,
                        size: 22,
                        color: context.appColors.textMedium,
                      ),
              ),
              const SizedBox(width: kSpacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: context.ts(
                        15,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (storeNote.isNotEmpty)
                      Text(
                        storeNote,
                        style: context.ts(
                          12,
                          fontWeight: FontWeight.w500,
                          color: context.appColors.textMedium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: kSpacing2),
                    Text(
                      CurrencyFormatter.formatCents(priceCents),
                      style: context.ts(
                        18,
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: kSpacing14),
          Divider(height: 0.5, color: context.appColors.hairline),
          const SizedBox(height: kSpacing14),

          // Verdict Headline & Subtitle
          Text(
            result.headline,
            style: context.ts(
              22,
              fontWeight: FontWeight.w800,
              color: onSurface,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: kSpacing4),
          Text(
            result.subtitle,
            style: context.ts(
              13,
              fontWeight: FontWeight.w500,
              color: context.appColors.textMedium,
            ),
          ),
          const SizedBox(height: kSpacing16),

          // 3-bar Spare-Cash Milestone Chart
          Semantics(
            label:
                'Spare cash projection comparing ${CurrencyFormatter.formatCompact(priceCents)} against ${result.milestones.map((m) => '${m.label}: ${CurrencyFormatter.formatCompact(m.spareCents)}').join(', ')}',
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _AffordabilityBarChartPainter(
                  milestones: result.milestones,
                  priceCents: priceCents,
                  highlightColor: statusColor,
                  mutedBarColor: onSurface.withValues(alpha: 0.16),
                  thresholdColor: context.appColors.warningColor,
                  textStyle: context.ts(
                    11,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  mutedTextStyle: context.ts(
                    11,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.textMedium,
                  ),
                ),
              ),
            ),
          ),

          // Adjustment & Insight Suggestions
          if (result.suggestions.isNotEmpty) ...[
            const SizedBox(height: kSpacing14),
            Divider(height: 0.5, color: context.appColors.hairline),
            const SizedBox(height: kSpacing12),
            for (final suggestion in result.suggestions) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: kSpacing6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PesaFlowIcons.lightbulb,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: kSpacing8),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: context.ts(
                          12,
                          fontWeight: FontWeight.w500,
                          color: onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ActionButtonsRow extends ConsumerWidget {
  final String itemName;
  final int priceCents;
  final AffordabilityResult result;

  const _ActionButtonsRow({
    required this.itemName,
    required this.priceCents,
    required this.result,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final today = dateOnly(DateTime.now());
    final futureTarget = result.recommendedDate != null &&
            result.recommendedDate!.isAfter(today)
        ? result.recommendedDate!
        : null;

    final primaryBg = context.appColors.incomeColor;

    return Row(
      children: [
        Expanded(
          child: TactileSpringContainer(
            onTap: () {
              PesaHaptics.medium();
              context.push(
                Uri(
                  path: '/transactions/add',
                  queryParameters: {
                    'type': 'Expense',
                    'description': itemName,
                    'amount': priceCents.toString(),
                  },
                ).toString(),
              );
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                border: Border.all(color: context.appColors.hairline),
              ),
              child: Text(
                result.status == AffordabilityStatus.affordableToday
                    ? 'Log purchase'
                    : 'Buy anyway',
                style: context.ts(
                  14,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: kSpacing10),
        if (futureTarget != null &&
            result.status == AffordabilityStatus.bestAfterPayday)
          Expanded(
            child: TactileSpringContainer(
              onTap: () async {
                PesaHaptics.medium();
                await ref
                    .read(notificationServiceProvider)
                    .schedulePurchaseReminder(
                      itemName: itemName,
                      amountCents: priceCents,
                      targetDate: futureTarget,
                    );
                if (context.mounted) {
                  CustomToast.show(
                    context,
                    message:
                        'Reminder set for ${DateFormat('EEE d MMM').format(futureTarget)}',
                    type: ToastType.success,
                  );
                }
              },
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
                child: Text(
                  'Remind me ${DateFormat('EEE d').format(futureTarget)}',
                  style: context.ts(
                    14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: TactileSpringContainer(
              onTap: () {
                PesaHaptics.medium();
                context.push(
                  Uri(
                    path: '/savings-goals/add',
                    queryParameters: {
                      'name': itemName,
                      'target': priceCents.toString(),
                    },
                  ).toString(),
                );
              },
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
                child: Text(
                  'Save as Goal',
                  style: context.ts(
                    14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AffordabilityBarChartPainter extends CustomPainter {
  final List<SpareMilestone> milestones;
  final int priceCents;
  final Color highlightColor;
  final Color mutedBarColor;
  final Color thresholdColor;
  final TextStyle textStyle;
  final TextStyle mutedTextStyle;

  _AffordabilityBarChartPainter({
    required this.milestones,
    required this.priceCents,
    required this.highlightColor,
    required this.mutedBarColor,
    required this.thresholdColor,
    required this.textStyle,
    required this.mutedTextStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (milestones.isEmpty) return;

    const double topLabelSpace = 22;
    const double bottomLabelSpace = 24;
    final chartHeight =
        (size.height - topLabelSpace - bottomLabelSpace).clamp(24.0, size.height);
    final baselineY = topLabelSpace + chartHeight;

    int maxVal = priceCents;
    for (final m in milestones) {
      if (m.spareCents > maxVal) maxVal = m.spareCents;
    }
    if (maxVal <= 0) maxVal = 1;

    // Draw threshold dashed line at priceCents.
    final priceRatio = (priceCents / maxVal).clamp(0.0, 1.0);
    final thresholdY = baselineY - priceRatio * chartHeight;

    final dashPaint = Paint()
      ..color = thresholdColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;
    const double dashWidth = 4;
    const double dashGap = 4;
    double dx = 0;
    while (dx < size.width) {
      canvas.drawLine(
        Offset(dx, thresholdY),
        Offset((dx + dashWidth).clamp(0.0, size.width), thresholdY),
        dashPaint,
      );
      dx += dashWidth + dashGap;
    }

    // Price pill on left of dashed line
    final priceTp = TextPainter(
      text: TextSpan(
        text: CurrencyFormatter.formatCompact(priceCents),
        style: textStyle.copyWith(color: Colors.white, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        0,
        (thresholdY - 10).clamp(0.0, baselineY - 20),
        priceTp.width + 12,
        18,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(pillRect, Paint()..color = thresholdColor);
    priceTp.paint(
      canvas,
      Offset(pillRect.left + 6, pillRect.top + 2),
    );

    // Draw 3 milestone bars
    final count = milestones.length;
    final slotWidth = size.width / count;
    final barWidth = (slotWidth * 0.56).clamp(32.0, 68.0);

    for (int i = 0; i < count; i++) {
      final m = milestones[i];
      final centerX = slotWidth * i + slotWidth / 2;
      final clampedVal = m.spareCents.clamp(0, maxVal);
      final barHeight = (clampedVal / maxVal) * chartHeight;
      final effectiveBarHeight = barHeight < 6 ? 6.0 : barHeight;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          baselineY - effectiveBarHeight,
          barWidth,
          effectiveBarHeight,
        ),
        const Radius.circular(10),
      );

      final barColor = m.isHighlighted
          ? highlightColor.withValues(alpha: 0.35)
          : mutedBarColor;
      canvas.drawRRect(barRect, Paint()..color = barColor);

      // Spare label above bar (for positive future/highlighted bars)
      if (m.spareCents > 0 && (i > 0 || m.isHighlighted)) {
        final spareTp = TextPainter(
          text: TextSpan(
            text: '${CurrencyFormatter.formatCompact(m.spareCents)} spare',
            style: textStyle.copyWith(fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        spareTp.paint(
          canvas,
          Offset(
            (centerX - spareTp.width / 2).clamp(0.0, size.width - spareTp.width),
            (baselineY - effectiveBarHeight - 16).clamp(0.0, baselineY - 16),
          ),
        );
      }

      // Bottom axis label
      final axisTp = TextPainter(
        text: TextSpan(
          text: m.label,
          style: m.isHighlighted ? textStyle : mutedTextStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      axisTp.paint(
        canvas,
        Offset(
          (centerX - axisTp.width / 2).clamp(0.0, size.width - axisTp.width),
          baselineY + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AffordabilityBarChartPainter oldDelegate) {
    return oldDelegate.milestones != milestones ||
        oldDelegate.priceCents != priceCents ||
        oldDelegate.highlightColor != highlightColor;
  }
}
