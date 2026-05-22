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
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

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

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
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

  IconData _getAccountIcon(String iconStr) {
    switch (iconStr) {
      case 'phone-android':
        return Icons.phone_android_rounded;
      case 'account-balance':
        return Icons.account_balance_rounded;
      case 'wallet':
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'briefcase':
        return Icons.work_rounded;
      case 'store':
        return Icons.storefront_rounded;
      case 'cart':
        return Icons.shopping_cart_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'zap':
        return Icons.electric_bolt_rounded;
      case 'phone':
        return Icons.phone_android_rounded;
      case 'heart':
        return Icons.favorite_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'film':
        return Icons.movie_rounded;
      case 'shopping-bag':
        return Icons.shopping_bag_rounded;
      case 'coffee':
        return Icons.coffee_rounded;
      case 'send':
        return Icons.send_rounded;
      case 'credit-card':
        return Icons.credit_card_rounded;
      case 'banknote':
        return Icons.payments_rounded;
      case 'piggy-bank':
        return Icons.savings_rounded;
      case 'arrow-left-right':
        return Icons.compare_arrows_rounded;
      case 'plus-circle':
      default:
        return Icons.add_circle_outline_rounded;
    }
  }

  IconData _getTrackerIcon(String iconName) {
    switch (iconName) {
      case 'briefcase':
        return Icons.work_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'payments':
        return Icons.payments_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return Colors.grey;
  }

  Widget _buildMonthlyOverview(WidgetRef ref, ThemeData theme) {
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final catsAsync = ref.watch(topCategoriesProvider);
    return totalsAsync.when(
      data: (totals) {
        final income = totals['income'] ?? 0;
        final expense = totals['expense'] ?? 0;
        if (income == 0 && expense == 0) return const SizedBox.shrink();
        return GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: AppTheme.radiusCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Overview',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  catsAsync.when(
                    data: (cats) {
                      if (cats.isEmpty)
                        return const SizedBox(width: 80, height: 80);
                      final colors = [
                        theme.colorScheme.primary,
                        const Color(0xFFF59E0B),
                        const Color(0xFF3B82F6),
                        const Color(0xFF8B5CF6),
                        const Color(0xFFEF4444),
                      ];
                      return SizedBox(
                        height: 80,
                        width: 80,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 1,
                            centerSpaceRadius: 25,
                            sections: List.generate(
                              cats.length,
                              (i) => PieChartSectionData(
                                value: cats[i].amount.toDouble(),
                                color: i < colors.length
                                    ? colors[i]
                                    : Colors.grey,
                                radius: 12,
                                showTitle: false,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const SizedBox(width: 80, height: 80),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Income',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            AmountText(
                              amountInCents: income,
                              type: AmountType.income,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Expense',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            AmountText(
                              amountInCents: expense,
                              type: AmountType.expense,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: theme.brightness == Brightness.dark
                              ? const Color(0x1FFFFFFF)
                              : const Color(0x1F000000),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              income >= expense ? 'Saved' : 'Deficit',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            AmountText(
                              amountInCents: (income - expense).abs(),
                              type: income >= expense
                                  ? AmountType.income
                                  : AmountType.expense,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ), // close Column, Expanded
                ],
              ), // close Row
            ],
          ), // close Column
        ); // close GlassCard
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBudgetRings(
    WidgetRef ref,
    ThemeData theme,
    BuildContext context,
  ) {
    final budgetsAsync = ref.watch(budgetProgressProvider);
    return budgetsAsync.when(
      data: (budgets) {
        if (budgets.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget Progress',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/budgets'),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: budgets.length,
                itemBuilder: (_, i) {
                  final bp = budgets[i];
                  final pct = bp.percentage.clamp(0.0, 1.0);
                  final catColor = _hexToColor(bp.category.color);
                  return TactileSpringContainer(
                    onTap: () => context.go('/budgets/${bp.budget.id}'),
                    child: GlassCard(
                      borderRadius: AppTheme.radiusCard,
                      margin: EdgeInsets.only(right: 12),
                      child: Container(
                        width: 90,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 56,
                              width: 56,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      startDegreeOffset: -90,
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 20,
                                      sections: [
                                        PieChartSectionData(
                                          value: pct * 100,
                                          color:
                                              bp.spentInPeriod >
                                                  (bp
                                                          .currentPeriod
                                                          ?.allocated ??
                                                      bp.budget.amount)
                                              ? AppTheme.expenseColor
                                              : catColor,
                                          radius: 6,
                                          showTitle: false,
                                        ),
                                        PieChartSectionData(
                                          value: (1.0 - pct) * 100,
                                          color: catColor.withOpacity(0.15),
                                          radius: 6,
                                          showTitle: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${(pct * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              bp.budget.name,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showWorkspaceSelectorSheet(BuildContext context, WidgetRef ref) {
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
                      _showAddTrackerDialog(context, ref);
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
                      final itemColor = _hexToColor(item.color);

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
                                  _getTrackerIcon(item.icon),
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

  void _showAddTrackerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String selectedIcon = 'briefcase';
    String selectedColorHex = '#7C3AED'; // Amethyst

    final iconsList = [
      'person',
      'briefcase',
      'home',
      'flight',
      'shopping_cart',
      'payments',
    ];
    final colorsList = [
      '#7C3AED', // Amethyst purple
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
                        _getTrackerIcon(ico),
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
                  final c = _hexToColor(col);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorth = ref.watch(netWorthProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final recentTransAsync = ref.watch(recentTransactionsStreamProvider);
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final reviewQueueAsync = ref.watch(reviewQueueStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Active tracker properties for dynamic aesthetic blending
    final activeTrackerAsync = ref.watch(activeTrackerProvider);
    final trackerColor = activeTrackerAsync.maybeWhen(
      data: (tracker) => tracker != null
          ? _hexToColor(tracker.color)
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
      overallPct = 0.35; // Beautiful fallback of 35%
    }

    final pendingReviewCount = reviewQueueAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final accounts = accountsAsync.value ?? [];
    final hasAccounts = accounts.isNotEmpty;
    final account1 = hasAccounts ? accounts[0] : null;
    final account2 = accounts.length > 1 ? accounts[1] : null;

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

                  // Center: Home Title
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '.',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                        ),
                      ),
                    ],
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

              // ── 2. "pesaflow cash" Balance Hero Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF121214), const Color(0xFF0A0A0B)]
                        : [Colors.white, const Color(0xFFF5F5F7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'flow',
                              style: TextStyle(
                                fontWeight: FontWeight.w300,
                                fontSize: 19,
                                color: isDark ? Colors.white : Colors.black,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        // Dynamic Spent Progress Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF)).withOpacity(0.12),
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
                                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    overallPct > 0.9
                                        ? const Color(0xFFFF453A)
                                        : (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${(overallPct * 100).round()}% SPENT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
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
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
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
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
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
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
                    ),
                    const SizedBox(height: 18),
                    // Individual Accounts List Section
                    if (account1 != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                account1.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          AmountText(
                            amountInCents: account1.balance,
                            useMonospace: false,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (account2 != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                account2.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          AmountText(
                            amountInCents: account2.balance,
                            useMonospace: false,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (account1 == null) ...[
                      Center(
                        child: Text(
                          'No active accounts. Tap Add Account below to start.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 3. High-Contrast Stark Action Buttons ──
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
                      onTap: () => _showAddAccountDialog(context, ref),
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
                  color: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF2F2F7),
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
                              _buildActiveParserBadge(isDark, 'Airtel'),
                              _buildActiveParserBadge(isDark, 'Halopesa'),
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

              // ── 5. Budget Health Score Card (Credit Score Vibe) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F10) : Colors.white,
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
                              Icons.health_and_safety_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'BUDGET HEALTH',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        // Dynamic Status Badge
                        (() {
                          final score = (1000 - (overallPct * 1000).round()).clamp(0, 1000);
                          String ratingLabel = 'Healthy';
                          Color ratingColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF);
                          if (score >= 800) {
                            ratingLabel = 'Excellent';
                            ratingColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF);
                          } else if (score >= 600) {
                            ratingLabel = 'Healthy';
                            ratingColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF);
                          } else if (score >= 400) {
                            ratingLabel = 'Moderate';
                            ratingColor = Colors.orange;
                          } else {
                            ratingLabel = 'Critical';
                            ratingColor = const Color(0xFFFF453A);
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: ratingColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              ratingLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: ratingColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        }()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Inner content Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Score Display
                        (() {
                          final score = (1000 - (overallPct * 1000).round()).clamp(0, 1000);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$score',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 48,
                                        color: isDark ? Colors.white : Colors.black,
                                        letterSpacing: -2,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '/ 1000',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Overall pacing score',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        }()),
                        // Progress circular indicator
                        SizedBox(
                          height: 72,
                          width: 72,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                ),
                              ),
                              CircularProgressIndicator(
                                value: (1.0 - overallPct),
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  overallPct > 0.8
                                      ? const Color(0xFFFF453A)
                                      : (overallPct > 0.5
                                          ? const Color(0xFFFF9F0A)
                                          : (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF))),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${((1.0 - overallPct) * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const Text(
                                    'LEFT',
                                    style: TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(height: 0.5, thickness: 0.5, color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000)),
                    const SizedBox(height: 12),
                    // Summary status message row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent ${(overallPct * 100).round()}% of allocated budget',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.update_rounded,
                              color: Colors.grey,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Updated just now',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Horizontal Scrollable Accounts Carousel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Accounts',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  accountsAsync.when(
                    data: (list) => Text(
                      '${list.length} active',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 105,
                child: accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return GlassCard(
                        onTap: () => _showAddAccountDialog(context, ref),
                        borderRadius: AppTheme.radiusCard,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_card_rounded,
                              color: Colors.grey,
                              size: 28,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'No accounts added yet. Tap to create one!',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return GlassCard(
                          onTap: () {}, // Tappable accounts if needed
                          borderRadius: AppTheme.radiusCard,
                          margin: EdgeInsets.only(right: 12.0),
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getAccountIcon(account.icon),
                                      size: 20,
                                      color: trackerColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        account.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.type.toUpperCase().replaceAll(
                                        '_',
                                        ' ',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    AmountText(
                                      amountInCents: account.balance,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) =>
                      Center(child: Text('Error loading accounts: $err')),
                ),
              ),
              const SizedBox(height: 28),

              // Monthly Overview Bento Card
              _buildMonthlyOverview(ref, theme),
              const SizedBox(height: 24),

              // Budget Progress Rings Bento Card
              _buildBudgetRings(ref, theme, context),
              const SizedBox(height: 24),

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
              const SizedBox(height: 6),
              recentTransAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
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
                            'No transactions recorded.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your offline financial logs will display here.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final item = transactions[index];
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
                        },
                        child: IosListRow(
                          onTap: () =>
                              context.go('/transactions/edit/${trans.id}'),
                          leading: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: _hexToColor(
                                item.category.color,
                              ).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getCategoryIcon(item.category.icon),
                              color: _hexToColor(item.category.color),
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

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM TACTILE SPRING INTERACTION CONTAINER
// ════════════════════════════════════════════════════════════════════════════
class TactileSpringContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;

  const TactileSpringContainer({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.96,
  });

  @override
  State<TactileSpringContainer> createState() => _TactileSpringContainerState();
}

class _TactileSpringContainerState extends State<TactileSpringContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
