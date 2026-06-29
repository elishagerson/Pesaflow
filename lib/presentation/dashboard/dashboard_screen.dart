import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/data/repositories/tracker_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/frequency_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/spacing.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedAccountId;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildActiveParserBadge(ThemeData theme, bool isDark, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpacing8, vertical: kSpacing4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0x10FFFFFF) : const Color(0x10000000),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 10,
            color: const Color(0xFF609F8A),
          ),
          const SizedBox(width: kSpacing4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    String accountType = 'Cash'; // Default
    final balanceController = TextEditingController();
    String? phoneNumber;
    String? provider;

    ModernDialog.show(
      context: context,
      title: const Text('Add Account'),
      titleIcon: Icons.account_balance_wallet_rounded,
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. M-Pesa, Cash Wallet, NMB Savings',
                  prefixIcon: Icon(Icons.edit_rounded, size: 18),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: kSpacing16),
              ModernDropdown<String>(
                labelText: 'Account Type',
                value: accountType,
                prefixIcon: Icons.wallet_rounded,
                items: const [
                  ModernDropdownItem(
                    value: 'Cash',
                    label: 'Cash Wallet',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppTheme.transferColorDark,
                    subtitle: 'Physical cash and local wallets',
                  ),
                  ModernDropdownItem(
                    value: 'Mobile Money',
                    label: 'Mobile Money',
                    icon: Icons.phone_android_rounded,
                    color: Color(0xFF609F8A),
                    subtitle: 'M-Pesa, Tigo Pesa, Airtel Money, etc.',
                  ),
                  ModernDropdownItem(
                    value: 'Bank',
                    label: 'Bank Account',
                    icon: Icons.account_balance_rounded,
                    color: Color(0xFFFF9F0A),
                    subtitle: 'NMB, CRDB, NBC, and other banks',
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      accountType = val;
                      if (accountType == 'Mobile Money') {
                        provider = 'M-Pesa_TZ';
                      } else if (accountType == 'Bank') {
                        provider = 'NMB';
                      } else {
                        provider = null;
                      }
                    });
                  }
                },
              ),
              if (accountType == 'Mobile Money') ...[
                const SizedBox(height: kSpacing16),
                ModernDropdown<String>(
                  labelText: 'Carrier Provider',
                  value: provider ?? 'M-Pesa_TZ',
                  prefixIcon: Icons.phone_iphone_rounded,
                  items: const [
                    ModernDropdownItem(
                      value: 'M-Pesa_TZ',
                      label: 'Vodacom M-Pesa',
                      icon: Icons.offline_bolt_rounded,
                      color: Colors.redAccent,
                      subtitle: 'Vodacom Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'TigoPesa_TZ',
                      label: 'Tigo Pesa',
                      icon: Icons.offline_bolt_rounded,
                      color: Colors.blueAccent,
                      subtitle: 'Tigo Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'AirtelMoney_TZ',
                      label: 'Airtel Money',
                      icon: Icons.offline_bolt_rounded,
                      color: Colors.red,
                      subtitle: 'Airtel Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'Halopesa_TZ',
                      label: 'HaloPesa',
                      icon: Icons.offline_bolt_rounded,
                      color: Colors.orangeAccent,
                      subtitle: 'Halotel Mobile Money service',
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      provider = val;
                    });
                  },
                ),
                const SizedBox(height: kSpacing16),
                TextField(
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. 076XXXXXXX',
                    prefixIcon: Icon(Icons.phone_rounded, size: 18),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    phoneNumber = val;
                  },
                ),
              ],
              if (accountType == 'Bank') ...[
                const SizedBox(height: kSpacing16),
                ModernDropdown<String>(
                  labelText: 'Bank Brand',
                  value: provider ?? 'NMB',
                  prefixIcon: Icons.account_balance_rounded,
                  items: const [
                    ModernDropdownItem(
                      value: 'NMB',
                      label: 'NMB Bank',
                      icon: Icons.account_balance_rounded,
                      color: Colors.blue,
                      subtitle: 'National Microfinance Bank',
                    ),
                    ModernDropdownItem(
                      value: 'CRDB',
                      label: 'CRDB Bank',
                      icon: Icons.account_balance_rounded,
                      color: Colors.green,
                      subtitle: 'CRDB Bank Plc',
                    ),
                    ModernDropdownItem(
                      value: 'NBC',
                      label: 'NBC Bank',
                      icon: Icons.account_balance_rounded,
                      color: Colors.cyan,
                      subtitle: 'National Bank of Commerce',
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      provider = val;
                    });
                  },
                ),
              ],
              const SizedBox(height: kSpacing16),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Initial Balance (Tsh)',
                  hintText: 'e.g. 150,000',
                  prefixIcon: Icon(Icons.payments_rounded, size: 18),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) return;

            final rawAmount = balanceController.text;
            final cleanAmount = rawAmount.replaceAll(
              RegExp(r'[^0-9.]'),
              '',
            );
            final parsedDouble = double.tryParse(cleanAmount) ?? 0.0;
            final int cents = (parsedDouble * 100).round();

            String iconName = 'wallet';
            if (accountType == 'Mobile Money') {
              iconName = 'phone-android';
            } else if (accountType == 'Bank') {
              iconName = 'account-balance';
            }

            final newAccount = Account(
              id: const Uuid().v4(),
              name: nameController.text.trim(),
              type: accountType.toLowerCase().replaceAll(' ', '_'),
              balance: cents,
              provider: provider,
              phoneNumber: phoneNumber,
              icon: iconName,
              sortOrder: 0,
              isArchived: false,
              createdAt: DateTime.now(),
            );

            try {
              await ref
                  .read(accountRepositoryProvider)
                  .createAccount(newAccount);

              // Force Riverpod cache invalidation for accounts stream
              ref.invalidate(accountsStreamProvider);

              if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to create account: $e')),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }


  String _formatCompact(int amountInCents) {
    final double value = amountInCents / 100.0;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildSingleBudgetRing({
    required BuildContext context,
    required BudgetWithProgress bp,
    required Color catColor,
    required IconData catIcon,
    required double pct,
    required ThemeData theme,
    required bool isDark,
  }) {
    final remainingCents = (bp.currentPeriod?.allocated ?? bp.budget.amount) - bp.spentInPeriod;
    final remainingText = remainingCents >= 0
        ? '${_formatCompact(remainingCents)} left'
        : '${_formatCompact(remainingCents.abs())} over';
    final remainingColor = remainingCents >= 0
        ? (isDark ? Colors.grey[400] : Colors.grey[600])
        : AppTheme.expenseColor;

    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      margin: const EdgeInsets.only(right: kSpacing12),
      elevation: CardElevation.low,
      accentColor: hexToColor(bp.category.color),
      onTap: () => context.go('/budgets/${bp.budget.id}'),
      padding: EdgeInsets.zero,
      child: Container(
        width: 105,
        padding: const EdgeInsets.symmetric(horizontal: kSpacing8, vertical: kSpacing12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 56,
                width: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring background track
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 4.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          catColor.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    // Progress ring foreground filled track
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 5.5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          remainingCents < 0 ? AppTheme.expenseColor : catColor,
                        ),
                      ),
                    ),
                    // Centered Category Icon
                    Icon(
                      catIcon,
                      color: remainingCents < 0 ? AppTheme.expenseColor : catColor,
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpacing10),
              Text(
                bp.budget.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpacing4),
              Text(
                remainingText,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: remainingColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildMonthlyOverview(ThemeData theme) {
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final isDark = theme.brightness == Brightness.dark;
    
    return totalsAsync.when(
      data: (totals) {
        final income = totals['income'] ?? 0;
        final expense = totals['expense'] ?? 0;
        
        if (income == 0 && expense == 0) {
          return GlassCard(
            padding: const EdgeInsets.all(kSpacing20),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: kSpacing16),
                Text(
                  'No transactions yet this month',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: kSpacing8),
                Text(
                  'Start automatic SMS synchronization or log transactions manually to view your financial charts here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Calculate dynamic donut percentages
        final double total = (income + expense).toDouble();
        final double incomePct = total > 0 ? (income / total) * 100 : 50;
        final double expensePct = total > 0 ? (expense / total) * 100 : 50;
        
        final netSavings = income - expense;
        final savingsPct = income > 0 ? (netSavings / income * 100).round() : 0;

        return GlassCard(
          padding: const EdgeInsets.all(kSpacing18),
          borderRadius: AppTheme.radiusCard,
          elevation: CardElevation.medium,
          accentColor: theme.colorScheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Overview',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'THIS MONTH',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  // Compact Net Savings indicator badge
                  if (income > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: kSpacing8, vertical: kSpacing4),
                      decoration: BoxDecoration(
                        color: netSavings >= 0
                            ? (isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor).withValues(alpha: 0.12)
                            : (isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        netSavings >= 0 ? '$savingsPct% SAVED' : '${savingsPct.abs()}% DEFICIT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: netSavings >= 0
                              ? (isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor)
                              : (isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: kSpacing18),
              Row(
                children: [
                  // Donut Pie Chart (Income vs Expense)
                  SizedBox(
                    height: 84,
                    width: 84,
                    child: PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 2,
                        centerSpaceRadius: 26,
                        sections: [
                          PieChartSectionData(
                            value: incomePct,
                            color: isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor,
                            radius: 10,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: expensePct,
                            color: isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor,
                            radius: 10,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpacing12),
                  // Metrics
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Income row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: kSpacing8),
                                Text(
                                  'Income',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: income,
                              type: AmountType.income,
                              useMonospace: true,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing8),
                        // Expense row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: kSpacing8),
                                Text(
                                  'Expense',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: expense,
                              type: AmountType.expense,
                              useMonospace: true,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing8),
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000),
                        ),
                        const SizedBox(height: kSpacing8),
                        // Net Balance row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: netSavings >= 0
                                        ? (isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor)
                                        : (isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: kSpacing8),
                                Text(
                                  netSavings >= 0 ? 'Saved' : 'Deficit',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: netSavings.abs(),
                              type: netSavings >= 0 ? AmountType.income : AmountType.expense,
                              useMonospace: true,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 120),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 120),
      ),
    );
  }

  Widget _buildSmsReviewCard(ThemeData theme, bool isDark, int pendingReviewCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceHighDark : AppTheme.bgLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
          width: 0.5,
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
                  Icon(Icons.message_rounded, size: 14, color: const Color(0xFF609F8A)),
                  const SizedBox(width: kSpacing6),
                  Text('SMS AUTO-TRACKING', style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  )),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: kSpacing8, vertical: kSpacing4),
                decoration: BoxDecoration(
                  color: pendingReviewCount > 0
                      ? const Color(0xFFFF9F0A).withValues(alpha: 0.12)
                      : (isDark ? Colors.white10 : Colors.black12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  pendingReviewCount > 0 ? '$pendingReviewCount PENDING' : '0 PENDING',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 8, fontWeight: FontWeight.w900,
                    color: pendingReviewCount > 0 ? const Color(0xFFFF9F0A) : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing10),
          Text(
            'Review parsed mobile money & bank transactions from your SMS.',
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, height: 1.3,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: kSpacing14),
          Divider(height: 0.5, thickness: 0.5, color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000)),
          const SizedBox(height: kSpacing10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4, runSpacing: 4,
                  children: [
                    _buildActiveParserBadge(theme, isDark, 'M-Pesa'),
                    _buildActiveParserBadge(theme, isDark, 'Tigo'),
                    _buildActiveParserBadge(theme, isDark, 'Airtel'),
                    _buildActiveParserBadge(theme, isDark, 'Selcom'),
                  ],
                ),
              ),
              const SizedBox(width: kSpacing8),
              TactileSpringContainer(
                onTap: () => context.push('/sms-review'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: kSpacing12, vertical: kSpacing6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Let's go", style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold, fontSize: 11,
                      )),
                      const SizedBox(width: kSpacing2),
                      Icon(Icons.chevron_right_rounded, size: 12,
                        color: isDark ? Colors.white : Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRings(ThemeData theme, BuildContext context) {
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final isDark = theme.brightness == Brightness.dark;
    
    return budgetsAsync.when(
      data: (budgets) {
        if (budgets.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'LIMITS & SPENDING',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/budgets/add'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Budget'),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing8),
              GlassCard(
                padding: const EdgeInsets.all(kSpacing24),
                borderRadius: AppTheme.radiusCard,
                elevation: CardElevation.low,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(kSpacing14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.donut_large_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: kSpacing16),
                    Text(
                      'No Active Budgets',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: kSpacing8),
                    Text(
                      'Set spending targets for Food, Shopping, Transport, and more to monitor your limits automatically.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredFadeSlide(
              index: 5,
              child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Progress',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'LIMITS & SPENDING',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/budgets'),
                  child: const Text('See All'),
                ),
              ],
            ),
            ),
            const SizedBox(height: kSpacing12),
            SizedBox(
              height: 132,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: budgets.length,
                itemBuilder: (_, i) {
                  final bp = budgets[i];
                  final pct = bp.percentage.clamp(0.0, 1.0);
                  final catColor = hexToColor(bp.category.color);
                  final catIcon = getCategoryIcon(bp.category.icon);
                  
                  return StaggeredFadeSlide(
                    index: i,
                    child: _buildSingleBudgetRing(
                      context: context,
                      bp: bp,
                      catColor: catColor,
                      catIcon: catIcon,
                      pct: pct,
                      theme: theme,
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 140),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 140),
      ),
    );
  }

  Widget _buildSavingsReminder(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final daysSinceLastSaveAsync = ref.watch(daysSinceLastSaveProvider);

    return daysSinceLastSaveAsync.when(
      data: (days) {
        if (days < 0) return const SizedBox.shrink();
        if (days < 5) return const SizedBox.shrink();

        final (icon, message, color) = days >= 14
            ? (Icons.warning_rounded, 'It\'s been $days days since you saved — set aside some money today!', Colors.orange)
            : days >= 7
                ? (Icons.savings_rounded, 'It\'s been $days days since your last deposit — consider saving today.', AppTheme.transferColorDark)
                : (Icons.check_circle_rounded, 'Last saved $days days ago.', AppTheme.transferColorDark);

        return Container(
          padding: const EdgeInsets.all(kSpacing14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: kSpacing12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white.withValues(alpha: 0.7) : theme.colorScheme.onSurface.withValues(alpha: 0.87),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 80),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 80),
      ),
    );
  }

  Widget _buildSavingsGoalsDashboard(ThemeData theme, BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);

    return savingsGoalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) return const SizedBox.shrink();

        final goal = goals.first;
        final goalColor = hexToColor(goal.color);
        final pct = goal.targetAmount > 0 
            ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
            : 0.0;
        final percentInt = (pct * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Savings Target',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ACTIVE EMERGENCY VAULT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/savings-goals');
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push('/savings-goals/${goal.id}');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(kSpacing16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: isDark ? const Color(0x12FFFFFF) : const Color(0x1F000000),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 52,
                        width: 52,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(PieChartData(
                              startDegreeOffset: -90,
                              sectionsSpace: 0,
                              centerSpaceRadius: 18,
                              sections: [
                                PieChartSectionData(
                                  value: pct * 100,
                                  color: goalColor,
                                  radius: 4,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: (1.0 - pct) * 100,
                                  color: goalColor.withValues(alpha: 0.12),
                                  radius: 4,
                                  showTitle: false,
                                ),
                              ],
                            )),
                            Icon(
                              goal.icon == 'savings' 
                                  ? Icons.savings_rounded 
                                  : goal.icon == 'laptop' 
                                      ? Icons.laptop_chromebook_rounded 
                                      : goal.icon == 'flight' 
                                          ? Icons.flight_takeoff_rounded 
                                          : goal.icon == 'home' 
                                              ? Icons.home_rounded 
                                              : goal.icon == 'car' 
                                                  ? Icons.directions_car_rounded 
                                                  : goal.icon == 'school' 
                                                      ? Icons.school_rounded 
                                                      : goal.icon == 'heart' 
                                                          ? Icons.favorite_rounded 
                                                          : Icons.savings_rounded,
                              color: goalColor,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: kSpacing16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: kSpacing4),
                            Text(
                              'Saved ${CurrencyFormatter.formatCents(goal.currentAmount)} of ${CurrencyFormatter.formatCents(goal.targetAmount)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$percentInt%',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: goalColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: kSpacing2),
                          Text(
                            'Completed',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 100),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 100),
      ),
    );
  }

  Widget _buildLoanOverview(ThemeData theme, BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final activeLoansAsync = ref.watch(activeLoansStreamProvider);
    final netWorth = ref.watch(netWorthProvider);
    final recentLoanCountAsync = ref.watch(recentLoanActivityProvider);
    final paidLoansCountAsync = ref.watch(paidLoansCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loans',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'DEBT OVERVIEW',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                paidLoansCountAsync.when(
                  data: (count) => count > 0
                      ? Padding(
                          padding: const EdgeInsets.only(right: kSpacing8),
                          child: Text(
                            '$count paid',
                            style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF609F8A), fontWeight: FontWeight.w600),
                          ),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                TextButton(
                  onPressed: () => context.go('/loans'),
                  child: const Text('See All'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: kSpacing12),
        activeLoansAsync.when(
          data: (activeLoans) {
            if (activeLoans.isEmpty) {
              return Column(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/loans'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(kSpacing20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF609F8A).withValues(alpha: 0.1),
                            const Color(0xFF609F8A).withValues(alpha: 0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: const Color(0xFF609F8A).withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF609F8A).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF609F8A), size: 22),
                          ),
                          const SizedBox(width: kSpacing14),
                          Expanded(
                            child: Text(
                              'No active debt. Keep it that way.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  // Paid history hint
                  paidLoansCountAsync.when(
                    data: (paidCount) => paidCount > 0
                        ? Padding(
                            padding: const EdgeInsets.only(top: kSpacing8),
                            child: GestureDetector(
                              onTap: () => context.go('/loans'),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(kSpacing12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                  border: Border.all(
                                    color: const Color(0xFF609F8A).withValues(alpha: 0.15),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.history_rounded, size: 16, color: const Color(0xFF609F8A)),
                                    const SizedBox(width: kSpacing8),
                                    Text(
                                      '$paidCount loan${paidCount == 1 ? '' : 's'} paid off',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              );
            }

            final totalOutstanding = activeLoans.fold<int>(0, (sum, l) => sum + l.remaining);
            final debtRatio = netWorth > 0 ? totalOutstanding / netWorth : 999.0;
            final severityLevel = debtRatio > 1.0
                ? 'CRITICAL'
                : debtRatio > 0.5
                    ? 'HIGH'
                    : debtRatio > 0.2
                        ? 'MODERATE'
                        : 'LOW';
            final severityColor = debtRatio > 1.0
                ? const Color(0xFFE53935)
                : debtRatio > 0.5
                    ? const Color(0xFFFF6B35)
                    : debtRatio > 0.2
                        ? const Color(0xFFFF9F0A)
                        : const Color(0xFF609F8A);

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(kSpacing16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        severityColor.withValues(alpha: 0.15),
                        severityColor.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: severityColor.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing10),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              debtRatio > 0.5 ? Icons.warning_rounded : Icons.trending_up_rounded,
                              color: severityColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: kSpacing14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyFormatter.formatCents(totalOutstanding),
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: kSpacing2),
                                Text(
                                  '$severityLevel DEBT BURDEN',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: severityColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: kSpacing10, vertical: kSpacing4),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${activeLoans.length} loan${activeLoans.length == 1 ? '' : 's'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: severityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: severityColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (debtRatio.clamp(0.0, 1.0)),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            severityColor,
                                            severityColor.withValues(alpha: 0.6),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(debtRatio * 100).round()}% of net worth',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: severityColor,
                            ),
                          ),
                          Text(
                            netWorth > 0
                                ? 'Net worth: ${CurrencyFormatter.formatCents(netWorth)}'
                                : 'Net worth: ${CurrencyFormatter.formatCents(netWorth)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSpacing8),
                // Loan burden warning
                recentLoanCountAsync.when(
                  data: (count) => count >= 3
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: kSpacing8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(kSpacing12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF6B35).withValues(alpha: 0.1),
                                  const Color(0xFFFF6B35).withValues(alpha: 0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                              border: Border.all(
                                color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(kSpacing6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.speed_rounded, color: Color(0xFFFF6B35), size: 16),
                                ),
                                const SizedBox(width: kSpacing10),
                                Expanded(
                                  child: Text(
                                    '$count active loans in 3 months — consider reducing new borrowing',
                                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                ...activeLoans.take(2).map((loan) {
                  final ratio = loan.amount > 0 ? loan.remaining / loan.amount : 1.0;
                  final loanSeverity = ratio > 0.7 ? const Color(0xFFE53935) : ratio > 0.4 ? const Color(0xFFFF9F0A) : const Color(0xFF609F8A);
                  return GestureDetector(
                    onTap: () => context.go('/loans/${loan.id}'),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: kSpacing8),
                      padding: const EdgeInsets.all(kSpacing14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: loanSeverity.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(kSpacing6),
                                decoration: BoxDecoration(
                                  color: loanSeverity.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  ratio > 0.5 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: loanSeverity,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: kSpacing10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loan.description ?? 'Loan',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${ratio > 0.5 ? '⚠' : ''} ${(ratio * 100).round()}% unpaid',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: loanSeverity,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatCents(loan.remaining),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: loanSeverity,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: kSpacing10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: loanSeverity.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: ratio.clamp(0.0, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                loanSeverity,
                                                loanSeverity.withValues(alpha: 0.5),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                    );
                  }),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showWorkspaceSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final trackersAsync = ref.watch(allTrackersStreamProvider);
        final activeTrackerId = ref.watch(activeTrackerIdProvider);

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: LiquidGlassOverlay(
              child: Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? const Color(0xF01C1C1E) : const Color(0xF0F2F2F7),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: kSpacing20, vertical: kSpacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: kSpacing20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Workspaces',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _showAddTrackerDialog(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing16),
              trackersAsync.when(
                data: (trackersList) {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: trackersList.length,
                    itemBuilder: (context, index) {
                      final item = trackersList[index];
                      final isSelected = item.id == activeTrackerId;
                      final itemColor = hexToColor(item.color);

                      return TactileSpringContainer(
                        onTap: () {
                          ref
                              .read(activeTrackerIdProvider.notifier)
                              .setTrackerId(item.id);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: kSpacing8),
                          padding: const EdgeInsets.all(kSpacing16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? itemColor.withValues(alpha: 0.08)
                                : (theme.brightness == Brightness.dark
                                      ? AppTheme.surfaceContainerDark
                                      : AppTheme.surfaceLight),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusCard,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? itemColor.withValues(alpha: 0.3)
                                  : (theme.brightness == Brightness.dark
                                        ? const Color(0x1FFFFFFF)
                                        : const Color(0x1F000000)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(kSpacing10),
                                decoration: BoxDecoration(
                                  color: itemColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  getTrackerIcon(item.icon),
                                  color: itemColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: kSpacing14),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected ? itemColor : null,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                color: isSelected ? itemColor : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                onPressed: () {
                                  _showManageTrackerDialog(context, item, activeTrackerId, trackersList);
                                },
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: kSpacing8),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: itemColor,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading workspaces: $err'),
              ),
              const SizedBox(height: kSpacing20),
            ],
          ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddTrackerDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedIcon = 'briefcase';
    String selectedColorHex = '#0A84FF'; // Light blue

    final iconsList = [
      'person',
      'briefcase',
      'home',
      'flight',
      'shopping_cart',
      'payments',
    ];
    final colorsList = [
      '#0A84FF', // Light Blue
      '#4F46E5', // Indigo
      '#F43F5E', // Rose
      '#F59E0B', // Amber
      '#059669', // Emerald
      '#06B6D4', // Cyan
    ];

    ModernDialog.show(
      context: context,
      title: const Text('New Workspace'),
      titleIcon: Icons.grid_view_rounded,
      content: StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Workspace Name',
                  hintText: 'e.g. Side Gig, Paris Trip',
                  prefixIcon: Icon(Icons.edit_rounded, size: 18),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: kSpacing20),
              Text(
                'Select Icon',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: kSpacing8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: iconsList.map((ico) {
                  final isSel = selectedIcon == ico;
                  return GestureDetector(
                    onTap: () => setState(() => selectedIcon = ico),
                    child: Container(
                      padding: const EdgeInsets.all(kSpacing8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? theme.colorScheme.primary
                              : Colors.grey.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        getTrackerIcon(ico),
                        color: isSel
                            ? theme.colorScheme.primary
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: kSpacing20),
              Text(
                'Select Color',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: kSpacing8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: colorsList.map((col) {
                  final isSel = selectedColorHex == col;
                  final c = hexToColor(col);
                  return GestureDetector(
                    onTap: () => setState(() => selectedColorHex = col),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: kSpacing20, vertical: kSpacing12),
          ),
          onPressed: () async {
            if (nameController.text.trim().isEmpty) return;

            final newTracker = Tracker(
              id: const Uuid().v4(),
              name: nameController.text.trim(),
              icon: selectedIcon,
              color: selectedColorHex,
              isArchived: false,
              createdAt: DateTime.now(),
            );

            try {
              await ref
                  .read(trackerRepositoryProvider)
                  .createTracker(newTracker);
              ref.invalidate(allTrackersStreamProvider);

              // Set newly created tracker as active
              await ref
                  .read(activeTrackerIdProvider.notifier)
                  .setTrackerId(newTracker.id);

              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to create workspace: $e')),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _showManageTrackerDialog(
    BuildContext context,
    Tracker tracker,
    String activeTrackerId,
    List<Tracker> trackersList,
  ) {
    final nameController = TextEditingController(text: tracker.name);
    String selectedIcon = tracker.icon;
    String selectedColorHex = tracker.color;
    final canDelete = trackersList.length > 1;

    final iconsList = [
      'person',
      'briefcase',
      'home',
      'flight',
      'shopping_cart',
      'payments',
    ];
    final colorsList = [
      '#0A84FF', // Light Blue
      '#4F46E5', // Indigo
      '#F43F5E', // Rose
      '#F59E0B', // Amber
      '#059669', // Emerald
      '#06B6D4', // Cyan
    ];

    ModernDialog.show(
      context: context,
      title: const Text('Edit Workspace'),
      titleIcon: Icons.edit_rounded,
      content: StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Workspace Name',
                  hintText: 'e.g. Side Gig, Paris Trip',
                  prefixIcon: Icon(Icons.edit_rounded, size: 18),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: kSpacing20),
              Text(
                'Select Icon',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: kSpacing8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: iconsList.map((ico) {
                  final isSel = selectedIcon == ico;
                  return GestureDetector(
                    onTap: () => setState(() => selectedIcon = ico),
                    child: Container(
                      padding: const EdgeInsets.all(kSpacing8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? theme.colorScheme.primary
                              : Colors.grey.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        getTrackerIcon(ico),
                        color: isSel
                            ? theme.colorScheme.primary
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: kSpacing20),
              Text(
                'Select Color',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: kSpacing8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: colorsList.map((col) {
                  final isSel = selectedColorHex == col;
                  final c = hexToColor(col);
                  return GestureDetector(
                    onTap: () => setState(() => selectedColorHex = col),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
      actions: [
        if (canDelete)
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _confirmDeleteTracker(context, tracker, activeTrackerId, trackersList);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: kSpacing20, vertical: kSpacing12),
          ),
          onPressed: () async {
            if (nameController.text.trim().isEmpty) return;

            final updatedTracker = tracker.copyWith(
              name: nameController.text.trim(),
              icon: selectedIcon,
              color: selectedColorHex,
            );

            try {
              await ref
                  .read(trackerRepositoryProvider)
                  .updateTracker(updatedTracker);
              ref.invalidate(allTrackersStreamProvider);
              ref.invalidate(activeTrackerProvider);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update workspace: $e')),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _confirmDeleteTracker(
    BuildContext context,
    Tracker tracker,
    String activeTrackerId,
    List<Tracker> trackersList,
  ) {
    final theme = Theme.of(context);
    ModernDialog.show(
      context: context,
      title: const Text('Delete Workspace?'),
      titleIcon: Icons.warning_amber_rounded,
      content: Text(
        'Are you sure you want to delete "${tracker.name}"? This will permanently delete all transactions and savings goals in this workspace.',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              if (tracker.id == activeTrackerId) {
                final anotherTracker = trackersList.firstWhere((t) => t.id != tracker.id);
                await ref
                    .read(activeTrackerIdProvider.notifier)
                    .setTrackerId(anotherTracker.id);
              }
              await ref
                  .read(trackerRepositoryProvider)
                  .deleteTracker(tracker.id);
              ref.invalidate(allTrackersStreamProvider);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete workspace: $e')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _buildSubscriptionsDashboard(ThemeData theme, BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final subsAsync = ref.watch(subscriptionsStreamProvider);
    final dueAsync = ref.watch(dueSubscriptionsProvider);
    final totals = ref.watch(subscriptionTotalsProvider);
    final upcoming = ref.watch(upcomingRenewalsProvider);

        return subsAsync.when(
      data: (subscriptions) {
        if (subscriptions.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subscriptions',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'TRACK RECURRING SERVICES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.push('/subscriptions'),
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing8),
              GestureDetector(
                onTap: () => context.push('/subscriptions'),
                child: GlassCard(
                  borderRadius: AppTheme.radiusCard,
                  elevation: CardElevation.low,
                  padding: const EdgeInsets.all(kSpacing20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(kSpacing12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.subscriptions_rounded, color: theme.colorScheme.primary, size: 24),
                      ),
                      const SizedBox(width: kSpacing16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Track your subscriptions',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: kSpacing4),
                            Text(
                              'Log recurring payments like streaming, utility bills, or gym memberships to get ahead of renewals.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        final due = dueAsync.asData?.value ?? [];
        final active = subscriptions.where((s) => s.status == 'active').toList();
        final categories = ref.read(categoriesFutureProvider).asData?.value ?? [];

        Color? catColor(String? catId) {
          if (catId == null) return null;
          final cat = categories.where((c) => c.id == catId).firstOrNull;
          return cat != null ? hexToColor(cat.color) : null;
        }

        // Upcoming renewals already shown in timeline — exclude from active tiles
        final upcomingIds = upcoming.map((s) => s.id).toSet();
        final remaining = active.where((s) => !upcomingIds.contains(s.id)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscriptions',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${active.length} ACTIVE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (due.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: kSpacing10, vertical: kSpacing4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${due.length} due',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFF6B35),
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => context.push('/subscriptions'),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: kSpacing8),

            // ── Hero total card ──
            if (totals.monthly > 0)
              GlassCard(
                borderRadius: AppTheme.radiusCard,
                elevation: CardElevation.medium,
                padding: const EdgeInsets.all(kSpacing16),
                margin: const EdgeInsets.only(bottom: kSpacing12),
                child: Column(
                  children: [
                    Text(
                      '${CurrencyFormatter.formatCents(totals.monthly)}/mo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: kSpacing8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _cycleChip(theme, '${_fmtShort(totals.daily)}/day', isDark),
                        const SizedBox(width: kSpacing8),
                        _cycleChip(theme, '${_fmtShort(totals.weekly)}/wk', isDark),
                        const SizedBox(width: kSpacing8),
                        _cycleChip(theme, '${_fmtShort(totals.yearly)}/yr', isDark),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Upcoming renewals ──
            if (upcoming.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: kSpacing8),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    const SizedBox(width: kSpacing6),
                    Text(
                      'UPCOMING RENEWALS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              ...upcoming.take(3).map((sub) => Padding(
                padding: const EdgeInsets.only(bottom: kSpacing6),
                child: GlassCard(
                  borderRadius: AppTheme.radiusCard,
                  elevation: CardElevation.low,
                  padding: const EdgeInsets.symmetric(horizontal: kSpacing14, vertical: kSpacing10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: due.contains(sub) ? const Color(0xFFFF6B35) : (catColor(sub.categoryId) ?? const Color(0xFF609F8A)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: kSpacing10),
                      Expanded(
                        child: Text(
                          sub.name,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(sub.nextDueDate),
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(width: kSpacing8),
                      AmountText(
                        amountInCents: sub.amount,
                        type: AmountType.expense,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: kSpacing4),
            ],

            // ── Remaining subscription tiles (excluding those in upcoming) ──
            ...remaining.take(3).map((sub) => Padding(
              padding: const EdgeInsets.only(bottom: kSpacing8),
              child: GlassCard(
                borderRadius: AppTheme.radiusCard,
                elevation: CardElevation.low,
                padding: const EdgeInsets.symmetric(horizontal: kSpacing14, vertical: kSpacing12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(kSpacing8),
                      decoration: BoxDecoration(
                        color: (catColor(sub.categoryId) ?? const Color(0xFF609F8A)).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.subscriptions_rounded,
                        size: 14,
                        color: catColor(sub.categoryId) ?? const Color(0xFF609F8A),
                      ),
                    ),
                    const SizedBox(width: kSpacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (catColor(sub.categoryId) != null) ...[
                                Container(width: 6, height: 6, decoration: BoxDecoration(color: catColor(sub.categoryId), shape: BoxShape.circle)),
                                const SizedBox(width: kSpacing6),
                              ],
                              Expanded(
                                child: Text(
                                  sub.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: kSpacing2),
                          Text(
                            frequencyLabel(sub.frequency, sub.intervalValue),
                            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    AmountText(
                      amountInCents: sub.amount,
                      type: AmountType.expense,
                      useMonospace: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _cycleChip(ThemeData theme, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpacing8, vertical: kSpacing4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}';
  }

  /// Formats cents as a compact number without "Tsh" prefix.
  String _fmtShort(int cents) {
    if (cents <= 0) return '0';
    final raw = CurrencyFormatter.formatCents(cents);
    return raw.startsWith('Tsh ') ? raw.substring(4) : raw;
  }

  Widget _buildUpcomingRecurring(ThemeData theme, BuildContext context) {
    final recurringAsync = ref.watch(dueRecurringTransactionsProvider);

    return recurringAsync.when(
      data: (recurring) {
        if (recurring.isEmpty) return const SizedBox.shrink();

        final limited = recurring.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Payments',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'RECURRING',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/recurring'),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: kSpacing8),
            ...limited.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: kSpacing8),
              child: GlassCard(
                borderRadius: AppTheme.radiusCard,
                elevation: CardElevation.low,
                padding: const EdgeInsets.symmetric(horizontal: kSpacing14, vertical: kSpacing12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(kSpacing8),
                      decoration: BoxDecoration(
                        color: (r.type == 'income' ? const Color(0xFF609F8A) : const Color(0xFFE53935)).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        r.type == 'income' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 14,
                        color: r.type == 'income' ? const Color(0xFF609F8A) : const Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(width: kSpacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.description ?? r.frequency,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: kSpacing2),
                          Text(
                            '${r.frequency} · ${r.nextDate.day}/${r.nextDate.month}',
                            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    AmountText(
                      amountInCents: r.amount,
                      type: r.type == 'income' ? AmountType.income : AmountType.expense,
                      useMonospace: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final netWorth = ref.watch(netWorthProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final recentTransAsync = ref.watch(recentTransactionsStreamProvider);
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final reviewQueueAsync = ref.watch(reviewQueueStreamProvider);
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final daysSinceLastSaveAsync = ref.watch(daysSinceLastSaveProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final showReminder = daysSinceLastSaveAsync.maybeWhen(
      data: (days) => days >= 5,
      orElse: () => false,
    );

    final showSavingsGoals = savingsGoalsAsync.maybeWhen(
      data: (goals) => goals.isNotEmpty,
      orElse: () => false,
    );

    // Active tracker properties for dynamic aesthetic blending
    final activeTrackerAsync = ref.watch(activeTrackerProvider);
    final trackerColor = activeTrackerAsync.maybeWhen(
      data: (tracker) => tracker != null
          ? hexToColor(tracker.color)
          : theme.colorScheme.primary,
      orElse: () => theme.colorScheme.primary,
    );
    final trackerName = activeTrackerAsync.maybeWhen(
      data: (tracker) => tracker != null ? tracker.name : 'Personal',
      orElse: () => 'Personal',
    );

    // Calculate budget overall spent percentage
    final budgets = budgetsAsync.value ?? [];
    double overallPct = 0.0;
    if (budgets.isNotEmpty) {
      double totalSpent = 0;
      double totalAllocated = 0;
      for (final bp in budgets) {
        totalSpent += bp.spentInPeriod;
        totalAllocated += bp.currentPeriod?.allocated ?? bp.budget.amount;
      }
      if (totalAllocated > 0) {
        overallPct = (totalSpent / totalAllocated).clamp(0.0, 1.0);
      }
    } else {
      // Dynamic fallback if no budgets are set: compute spent vs income from actual transactions!
      final totals = totalsAsync.value;
      if (totals != null) {
        final income = totals['income'] ?? 0;
        final expense = totals['expense'] ?? 0;
        if (income > 0) {
          overallPct = (expense / income).clamp(0.0, 1.0);
        } else if (expense > 0) {
          overallPct = 1.0; // Has expenses but no income logged -> 100% spent
        } else {
          overallPct = 0.0; // Fresh app startup, no transactions -> 0% spent
        }
      } else {
        overallPct = 0.0;
      }
    }

    final pendingReviewCount = reviewQueueAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final accounts = accountsAsync.value ?? [];

    // Dynamic Balance card color properties matching HIG/M3 design brief
    final cardGradient = isDark
        ? LinearGradient(
            colors: [
              trackerColor.withValues(alpha: 0.24),
              const Color(0xFF09090A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              trackerColor,
              trackerColor.withValues(alpha: 0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final Color heroTextColor = Colors.white;
    final Color heroSubColor = isDark ? Colors.grey[400]! : Colors.white.withValues(alpha: 0.8);
    final Color pillBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.18);
    final Color pillBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF);

    return Scaffold(
      appBar: IosNavBar(
        title: _getGreeting(),
        largeTitle: true,
        leading: TactileSpringContainer(
          onTap: () => _showWorkspaceSelectorSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: kSpacing14, vertical: kSpacing8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: trackerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: kSpacing8),
                Text(
                  trackerName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: kSpacing4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TactileSpringContainer(
            onTap: () => context.go('/settings'),
            child: Container(
              padding: const EdgeInsets.all(kSpacing10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: isDark ? Colors.white : Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: kSpacing8),
          TactileSpringContainer(
            onTap: () => context.push('/sms-review'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (pendingReviewCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: kSpacing4, vertical: kSpacing2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF453A),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isDark ? Colors.black : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$pendingReviewCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(top: false, child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthlyTotalsProvider);
            ref.invalidate(netWorthProvider);
            ref.invalidate(accountsStreamProvider);
            ref.invalidate(budgetProgressProvider);
            ref.invalidate(recentTransactionsStreamProvider);
            ref.invalidate(reviewQueueStreamProvider);
            ref.invalidate(savingsGoalsStreamProvider);
          },
          child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 4.0,
            bottom: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── 2. Balance Hero Card — "Your Money" ──
              StaggeredFadeSlide(
                index: 0,
                child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(kSpacing24),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          colors: [
                            trackerColor.withValues(alpha: 0.15),
                            const Color(0xFF0F1013),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : cardGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isDark ? trackerColor.withValues(alpha: 0.25) : trackerColor.withValues(alpha: 0.12),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? trackerColor.withValues(alpha: 0.12) : trackerColor.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand & Budget Gauge Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'pesa',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                                color: isDark ? const Color(0xFF609F8A) : Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'flow',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w300,
                                fontSize: 19,
                                color: heroTextColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        // Dynamic Spent Progress Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: kSpacing10, vertical: kSpacing4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                height: 12,
                                width: 12,
                                child: CircularProgressIndicator(
                                  value: overallPct,
                                  strokeWidth: 2,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    overallPct > 0.9
                                        ? const Color(0xFFFF453A)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: kSpacing6),
                              Text(
                                '${(overallPct * 100).round()}% SPENT',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: heroTextColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacing24),
                    // Title Label & Main Value
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: kSpacing6),
                        Text(
                          _selectedAccountId != null
                              ? (accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first).name.toUpperCase())
                              : 'TOTAL NET WORTH',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: heroSubColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacing8),
                    AmountText(
                      amountInCents: _selectedAccountId != null
                          ? (accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first).balance)
                          : netWorth,
                      useMonospace: false,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 42,
                        color: heroTextColor,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: kSpacing24),
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: pillBorder,
                    ),
                    
                    // Dynamic scrolling Account Pills in the Balance Hero Card
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: kSpacing18),
                      SizedBox(
                        height: 36,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: accounts.length,
                          itemBuilder: (context, index) {
                            final account = accounts[index];
                            final isSelected = _selectedAccountId == account.id;
                            
                            return Padding(
                              padding: EdgeInsets.only(
                                right: 8.0,
                                left: index == 0 ? 2.0 : 0.0,
                              ),
                              child: TactileSpringContainer(
                                onTap: () {
                                  setState(() {
                                    if (_selectedAccountId == account.id) {
                                      _selectedAccountId = null; // Clear filter
                                    } else {
                                      _selectedAccountId = account.id; // Apply filter
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: kSpacing14,
                                    vertical: kSpacing6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? trackerColor.withValues(alpha: 0.35) : Colors.white)
                                        : pillBg,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: isSelected
                                          ? (isDark ? trackerColor : Colors.white)
                                          : pillBorder,
                                      width: isSelected ? 1.5 : 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        getAccountIcon(account.icon),
                                        size: 14,
                                        color: isSelected
                                            ? (isDark ? Colors.white : trackerColor)
                                            : heroTextColor,
                                      ),
                                      const SizedBox(width: kSpacing6),
                                      Text(
                                        account.name,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? (isDark ? Colors.white : trackerColor)
                                              : heroTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing8),
                                      Text(
                                        _formatCompact(account.balance),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? (isDark ? Colors.white.withValues(alpha: 0.9) : trackerColor.withValues(alpha: 0.9))
                                              : heroTextColor.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: kSpacing18),
                      Center(
                        child: Text(
                          'No active accounts. Tap Add Account below to start.',
                          style: theme.textTheme.bodySmall?.copyWith(color: heroSubColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ),
              const SizedBox(height: kSpacing16),

              // ── 3. High-Contrast Action Buttons ──
              StaggeredFadeSlide(
                index: 1,
                child: Row(
                children: [
                  Expanded(
                    child: TactileSpringContainer(
                      onTap: () => context.go('/transactions/add'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: kSpacing16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B1C22).withValues(alpha: 0.8) : Colors.black,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark ? trackerColor.withValues(alpha: 0.4) : Colors.black,
                            width: 1.0,
                          ),
                          boxShadow: isDark ? [
                            BoxShadow(
                              color: trackerColor.withValues(alpha: 0.15),
                              blurRadius: 10,
                              spreadRadius: 0.5,
                            )
                          ] : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: isDark ? trackerColor : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: kSpacing6),
                            Text(
                              'Add transaction',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isDark ? trackerColor : Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpacing12),
                  Expanded(
                    child: TactileSpringContainer(
                      onTap: () => _showAddAccountDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: kSpacing16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B1C22).withValues(alpha: 0.8) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark ? const Color(0x10FFFFFF) : const Color(0x0F000000),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              color: isDark ? Colors.white : Colors.black,
                              size: 18,
                            ),
                            const SizedBox(width: kSpacing6),
                            Text(
                              'Add account',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
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
              const SizedBox(height: kSpacing20),

              // ── 3. Monthly Overview — "How your money moved" ──
              StaggeredFadeSlide(
                index: 2,
                child: _buildMonthlyOverview(theme),
              ),
              const SizedBox(height: kSpacing20),

              // ── 4. Recent Activity — "The transactions behind it" ──
              StaggeredFadeSlide(
                index: 3,
                child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Activity',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.go('/transactions');
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              ),
              
              // Clear account filter chip row if _selectedAccountId is active
              if (_selectedAccountId != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: kSpacing4, bottom: kSpacing12),
                  child: Row(
                    children: [
                      InputChip(
                        label: Text(
                          'Filtered by: ${accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => Account(id: '', name: 'Account', type: '', balance: 0, icon: 'wallet', sortOrder: 0, isArchived: false, createdAt: DateTime.now())).name}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                        deleteIcon: Icon(
                          Icons.cancel_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedAccountId = null;
                          });
                        },
                        onPressed: () {
                          setState(() {
                            _selectedAccountId = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: kSpacing12),
              ],

              recentTransAsync.when(
                data: (transactions) {
                  // Client-side dynamic filtering of recent transactions by account
                  final filteredTransactions = _selectedAccountId == null
                      ? transactions
                      : transactions
                          .where((t) => t.transaction.accountId == _selectedAccountId)
                          .toList();

                  if (filteredTransactions.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: kSpacing40),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? AppTheme.surfaceContainerDark
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        border: Border.all(
                          color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: kSpacing12),
                          Text(
                            'No transactions found.',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: kSpacing4),
                          Text(
                            _selectedAccountId == null
                                ? 'Your offline financial logs will display here.'
                                : 'No activity recorded for this specific account.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final item = filteredTransactions[index];
                      final trans = item.transaction;

                      AmountType amtType = AmountType.neutral;
                      if (trans.type.toLowerCase() == 'income') {
                        amtType = AmountType.income;
                      } else if (trans.type.toLowerCase() == 'expense' ||
                          trans.type.toLowerCase() == 'airtime' ||
                          trans.type.toLowerCase() == 'fee') {
                        amtType = AmountType.expense;
                      }

                      return StaggeredFadeSlide(
                        index: index,
                        child: Dismissible(
                          key: Key(trans.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: kSpacing20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusCard,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) async {
                            await ref
                                .read(transactionRepositoryProvider)
                                .deleteTransaction(trans.id);
                            ref.invalidate(recentTransactionsStreamProvider);
                            ref.invalidate(accountsStreamProvider);
                            ref.invalidate(netWorthProvider);
                            ref.invalidate(monthlyTotalsProvider);
                          },
                          child: TactileSpringContainer(
                            onTap: () => context.push('/transactions/${trans.id}'),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: kSpacing6),
                            padding: const EdgeInsets.all(kSpacing16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1B1C22).withValues(alpha: 0.65)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0x10FFFFFF) : const Color(0x0F000000),
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Category Icon Container (Squircle Style)
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: hexToColor(item.category.color).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      getCategoryIcon(item.category.icon),
                                      color: hexToColor(item.category.color),
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: kSpacing14),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trans.description.isNotEmpty ? trans.description : item.category.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: kSpacing4),
                                      Row(
                                        children: [
                                          Text(
                                            item.account?.name ?? 'Offline',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: kSpacing8),
                                          Text(
                                            trans.createdAt.toString().substring(0, 10),
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: kSpacing12),
                                // Amount
                                AmountText(
                                  amountInCents: trans.amount,
                                  type: amtType,
                                  showDecimals: true,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: amtType == AmountType.income
                                        ? AppTheme.transferColorDark
                                        : (amtType == AmountType.expense ? const Color(0xFFFF453A) : theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) =>
                    Center(child: Text('Error loading activity: $err')),
              ),

              // ── 5. Budget Progress — "Your Financial Targets" ──
              _buildBudgetRings(theme, context),

              if (showSavingsGoals) ...[
                const SizedBox(height: kSpacing20),
                StaggeredFadeSlide(
                  index: 4,
                  child: _buildSavingsGoalsDashboard(theme, context),
                ),
              ],

              if (showReminder) ...[
                const SizedBox(height: kSpacing20),
                StaggeredFadeSlide(
                  index: 5,
                  child: _buildSavingsReminder(theme),
                ),
              ],

              const SizedBox(height: kSpacing20),

              // ── 6. Upcoming Payments — "Subscriptions" ──
              StaggeredFadeSlide(
                index: 6,
                child: _buildSubscriptionsDashboard(theme, context),
              ),

              // ── 7. Upcoming Payments — "Recurring" ──
              _buildUpcomingRecurring(theme, context),

              const SizedBox(height: kSpacing20),

              // ── 8. Loan / Debt Overview ──
              StaggeredFadeSlide(
                index: 7,
                child: _buildLoanOverview(theme, context),
              ),

              const SizedBox(height: kSpacing20),

              // ── 9. SMS Auto-Tracking — "How it works" ──
              StaggeredFadeSlide(
                index: 8,
                child: _buildSmsReviewCard(theme, isDark, pendingReviewCount),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

