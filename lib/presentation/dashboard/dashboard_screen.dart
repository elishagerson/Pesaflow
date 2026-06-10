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
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_detail_sheet.dart';
import 'package:pesaflow/presentation/budgets/budget_list_screen.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:flutter/services.dart';

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

  Widget _buildActiveParserBadge(bool isDark, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. M-Pesa, Cash Wallet, NMB Savings',
                  prefixIcon: Icon(Icons.edit_rounded, size: 18),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              ModernDropdown<String>(
                labelText: 'Account Type',
                value: accountType,
                prefixIcon: Icons.wallet_rounded,
                items: const [
                  ModernDropdownItem(
                    value: 'Cash',
                    label: 'Cash Wallet',
                    icon: Icons.account_balance_wallet_rounded,
                    color: Color(0xFF30D158),
                    subtitle: 'Physical cash and local wallets',
                  ),
                  ModernDropdownItem(
                    value: 'Mobile Money',
                    label: 'Mobile Money',
                    icon: Icons.phone_android_rounded,
                    color: Color(0xFF0A84FF),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. 076XXXXXXX',
                    prefixIcon: Icon(Icons.phone_rounded, size: 18),
                  ),
                  onChanged: (val) {
                    phoneNumber = val;
                  },
                ),
              ],
              if (accountType == 'Bank') ...[
                const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Initial Balance (Tsh)',
                  hintText: 'e.g. 150,000',
                  prefixIcon: Icon(Icons.payments_rounded, size: 18),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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

            await ref
                .read(accountRepositoryProvider)
                .createAccount(newAccount);

            // Force Riverpod cache invalidation for accounts stream
            ref.invalidate(accountsStreamProvider);

            if (context.mounted) Navigator.of(context).pop();
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
      margin: const EdgeInsets.only(right: 12),
      elevation: CardElevation.low,
      accentColor: Color(int.parse(bp.category.color.replaceAll('#', '0xFF'))),
      onTap: () => context.go('/budgets/${bp.budget.id}'),
      padding: EdgeInsets.zero,
      child: Container(
        width: 105,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                          catColor.withOpacity(0.12),
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
              const SizedBox(height: 10),
              Text(
                bp.budget.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                remainingText,
                style: TextStyle(
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
            padding: const EdgeInsets.all(20),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions yet this month',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start automatic SMS synchronization or log transactions manually to view your financial charts here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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
          padding: const EdgeInsets.all(18),
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
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  // Compact Net Savings indicator badge
                  if (income > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: netSavings >= 0
                            ? (isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor).withOpacity(0.12)
                            : (isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        netSavings >= 0 ? '$savingsPct% SAVED' : '${savingsPct.abs()}% DEFICIT',
                        style: TextStyle(
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
              const SizedBox(height: 18),
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
                  const SizedBox(width: 12),
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
                                const SizedBox(width: 8),
                                const Text(
                                  'Income',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: income,
                              type: AmountType.income,
                              useMonospace: true,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                                const SizedBox(width: 8),
                                const Text(
                                  'Expense',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: expense,
                              type: AmountType.expense,
                              useMonospace: true,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000),
                        ),
                        const SizedBox(height: 8),
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
                                const SizedBox(width: 8),
                                Text(
                                  netSavings >= 0 ? 'Saved' : 'Deficit',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: netSavings.abs(),
                              type: netSavings >= 0 ? AmountType.income : AmountType.expense,
                              useMonospace: true,
                              style: const TextStyle(
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
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonCard(height: 120),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonCard(height: 120),
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
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
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
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(24),
                borderRadius: AppTheme.radiusCard,
                elevation: CardElevation.low,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.donut_large_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Budgets',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set spending targets for Food, Shopping, Transport, and more to monitor your limits automatically.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
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
            const SizedBox(height: 12),
            SizedBox(
              height: 124,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: budgets.length,
                itemBuilder: (_, i) {
                  final bp = budgets[i];
                  final pct = bp.percentage.clamp(0.0, 1.0);
                  final catColor = hexToColor(bp.category.color);
                  final catIcon = getCategoryIcon(bp.category.icon);
                  
                  return _buildSingleBudgetRing(
                    context: context,
                    bp: bp,
                    catColor: catColor,
                    catIcon: catIcon,
                    pct: pct,
                    theme: theme,
                    isDark: isDark,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonCard(height: 140),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
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
                ? (Icons.savings_rounded, 'It\'s been $days days since your last deposit — consider saving today.', const Color(0xFF30D158))
                : (Icons.check_circle_rounded, 'Last saved $days days ago.', const Color(0xFF30D158));

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: color.withOpacity(0.15), width: 0.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonCard(height: 80),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
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
                        'Savings Target',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ACTIVE EMERGENCY VAULT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(budgetActiveTabProvider.notifier).state = 1;
                      context.go('/budgets');
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SavingsGoalDetailSheet(goal: goal),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                                  color: goalColor.withOpacity(0.12),
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Saved ${CurrencyFormatter.formatCents(goal.currentAmount)} of ${CurrencyFormatter.formatCents(goal.targetAmount)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                            style: TextStyle(
                              color: goalColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Completed',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonCard(height: 100),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonCard(height: 100),
      ),
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

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
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
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
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
                      Navigator.pop(context);
                      _showAddTrackerDialog(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                          margin: const EdgeInsets.only(bottom: 8.0),
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? itemColor.withOpacity(0.08)
                                : (theme.brightness == Brightness.dark
                                      ? AppTheme.surfaceContainerDark
                                      : AppTheme.surfaceLight),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusCard,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? itemColor.withOpacity(0.3)
                                  : (theme.brightness == Brightness.dark
                                        ? const Color(0x1FFFFFFF)
                                        : const Color(0x1F000000)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10.0),
                                decoration: BoxDecoration(
                                  color: itemColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  getTrackerIcon(item.icon),
                                  color: itemColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
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
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: itemColor,
                                  size: 20,
                                ),
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
              const SizedBox(height: 20),
            ],
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
                decoration: const InputDecoration(
                  labelText: 'Workspace Name',
                  hintText: 'e.g. Side Gig, Paris Trip',
                  prefixIcon: Icon(Icons.edit_rounded, size: 18),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Icon',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: iconsList.map((ico) {
                  final isSel = selectedIcon == ico;
                  return GestureDetector(
                    onTap: () => setState(() => selectedIcon = ico),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? theme.colorScheme.primary.withOpacity(0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? theme.colorScheme.primary
                              : Colors.grey.withOpacity(0.2),
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
              const SizedBox(height: 20),
              const Text(
                'Select Color',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
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

            await ref
                .read(trackerRepositoryProvider)
                .createTracker(newTracker);
            ref.invalidate(allTrackersStreamProvider);

            // Set newly created tracker as active
            await ref
                .read(activeTrackerIdProvider.notifier)
                .setTrackerId(newTracker.id);

            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Create'),
        ),
      ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              trackerColor.withOpacity(0.24),
              const Color(0xFF09090A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              trackerColor,
              trackerColor.withOpacity(0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final Color heroTextColor = Colors.white;
    final Color heroSubColor = isDark ? Colors.grey[400]! : Colors.white.withOpacity(0.8);
    final Color pillBg = isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.18);
    final Color pillBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Elegant Top Bar (Mobbin inspired) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Account Avatar Settings Trigger
                  TactileSpringContainer(
                    onTap: () => context.go('/settings'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                              : [Colors.grey[200]!, Colors.grey[300]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      ),
                    ),
                  ),

                  // Center: PesaFlow Active Workspace Selector
                  TactileSpringContainer(
                    onTap: () => _showWorkspaceSelectorSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161618) : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isDark ? const Color(0x15FFFFFF) : const Color(0x0F000000),
                          width: 0.5,
                        ),
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
                          const SizedBox(width: 8),
                          Text(
                            trackerName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right: Notification Bell Trigger
                  TactileSpringContainer(
                    onTap: () => context.push('/sms-review'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161618) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0x15FFFFFF) : const Color(0x0F000000),
                              width: 0.5,
                            ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                                style: const TextStyle(
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
              const SizedBox(height: 16),
              
              // Salutation Greeting Section
              Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 20),

              // ── 2. "pesaflow cash" Floating Balance Hero Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: cardGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isDark ? trackerColor.withOpacity(0.3) : trackerColor.withOpacity(0.15),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: trackerColor.withOpacity(0.08),
                      blurRadius: 20,
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
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                                color: isDark ? const Color(0xFF00E5FF) : Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'flow',
                              style: TextStyle(
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
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
                              const SizedBox(width: 6),
                              Text(
                                '${(overallPct * 100).round()}% SPENT',
                                style: TextStyle(
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
                    const SizedBox(height: 22),
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
                        const SizedBox(width: 6),
                        Text(
                          'TOTAL NET WORTH',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: heroSubColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AmountText(
                      amountInCents: netWorth,
                      useMonospace: false,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 42,
                        color: heroTextColor,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: pillBorder,
                    ),
                    
                    // Dynamic scrolling Account Pills in the Balance Hero Card
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: 18),
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
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? trackerColor.withOpacity(0.35) : Colors.white)
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
                                      const SizedBox(width: 6),
                                      Text(
                                        account.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? (isDark ? Colors.white : trackerColor)
                                              : heroTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatCompact(account.balance),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? (isDark ? Colors.white.withOpacity(0.9) : trackerColor.withOpacity(0.9))
                                              : heroTextColor.withOpacity(0.8),
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
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'No active accounts. Tap Add Account below to start.',
                          style: TextStyle(color: heroSubColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 3. High-Contrast Action Buttons ──
              Row(
                children: [
                  Expanded(
                    child: TactileSpringContainer(
                      onTap: () => context.go('/transactions/add'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: isDark ? Colors.black : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Add transaction',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TactileSpringContainer(
                      onTap: () => _showAddAccountDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              color: isDark ? Colors.white : Colors.black,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Add account',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 4. SMS Review Queue Card (Setup Bonus Vibe) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
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
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.message_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SMS AUTO-TRACKING',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        // Pending Count Capsule
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: pendingReviewCount > 0
                                ? const Color(0xFFFF9F0A).withOpacity(0.12)
                                : (isDark ? Colors.white10 : Colors.black12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            pendingReviewCount > 0
                                ? '$pendingReviewCount PENDING'
                                : '0 PENDING',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: pendingReviewCount > 0
                                  ? const Color(0xFFFF9F0A)
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Review and categorize parsed mobile money & bank transactions automatically extracted from your SMS notifications.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Divider(height: 0.5, thickness: 0.5, color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000)),
                    const SizedBox(height: 14),
                    // Active Parsers and Action Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Active Parsers Chips
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildActiveParserBadge(isDark, 'M-Pesa'),
                              _buildActiveParserBadge(isDark, 'Tigo'),
                              _buildActiveParserBadge(isDark, 'Airtel'),
                              _buildActiveParserBadge(isDark, 'Selcom'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Action Button
                        TactileSpringContainer(
                          onTap: () => context.push('/sms-review'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Let's go",
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Monthly Overview Card (Donut Chart Revamp)
              _buildMonthlyOverview(theme),
              const SizedBox(height: 24),

              // Budget Progress Rings (Embedded category icons)
              _buildBudgetRings(theme, context),
              const SizedBox(height: 12),

              // Savings reminder card
              _buildSavingsReminder(theme),
              const SizedBox(height: 12),

              // Savings Goals Target Bento Box
              _buildSavingsGoalsDashboard(theme, context),
              const SizedBox(height: 12),

              // Recent Transactions Section
              Row(
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
              
              // Clear account filter chip row if _selectedAccountId is active
              if (_selectedAccountId != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 12.0),
                  child: Row(
                    children: [
                      InputChip(
                        label: Text(
                          'Filtered by: ${accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => Account(id: '', name: 'Account', type: '', balance: 0, icon: 'wallet', sortOrder: 0, isArchived: false, createdAt: DateTime.now())).name}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF00E5FF) : theme.colorScheme.primary,
                          ),
                        ),
                        backgroundColor: (isDark ? const Color(0xFF00E5FF) : theme.colorScheme.primary).withOpacity(0.08),
                        side: BorderSide(
                          color: (isDark ? const Color(0xFF00E5FF) : theme.colorScheme.primary).withOpacity(0.2),
                          width: 0.8,
                        ),
                        deleteIcon: Icon(
                          Icons.cancel_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFF00E5FF) : theme.colorScheme.primary,
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
                const SizedBox(height: 6),
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
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
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
                                .withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions found.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedAccountId == null
                                ? 'Your offline financial logs will display here.'
                                : 'No activity recorded for this specific account.',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
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

                      return Dismissible(
                        key: Key(trans.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
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
                        child: IosListRow(
                          onTap: () =>
                              context.go('/transactions/edit/${trans.id}'),
                          leading: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: hexToColor(
                                item.category.color,
                              ).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              getCategoryIcon(item.category.icon),
                              color: hexToColor(item.category.color),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            trans.description.isNotEmpty
                                ? trans.description
                                : item.category.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                item.account.name,
                                style: TextStyle(
                                  color: trackerColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                trans.createdAt.toString().substring(0, 10),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          trailing: AmountText(
                            amountInCents: trans.amount,
                            type: amtType,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'monospace',
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
            ],
          ),
        ),
      ),
    );
  }
}

