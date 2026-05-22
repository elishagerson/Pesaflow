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

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String accountType = 'Cash'; // Default
    final balanceController = TextEditingController();
    String? phoneNumber;
    String? provider;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
              ),
              title: const Text('Add Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Name',
                        hintText: 'e.g. M-Pesa, Cash Wallet, NMB Savings',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: accountType,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text('Cash Wallet'),
                        ),
                        DropdownMenuItem(
                          value: 'Mobile Money',
                          child: Text('Mobile Money'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text('Bank Account'),
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: provider ?? 'M-Pesa_TZ',
                        decoration: const InputDecoration(
                          labelText: 'Carrier Provider',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'M-Pesa_TZ',
                            child: Text('Vodacom M-Pesa'),
                          ),
                          DropdownMenuItem(
                            value: 'TigoPesa_TZ',
                            child: Text('Tigo Pesa'),
                          ),
                          DropdownMenuItem(
                            value: 'AirtelMoney_TZ',
                            child: Text('Airtel Money'),
                          ),
                          DropdownMenuItem(
                            value: 'Halopesa_TZ',
                            child: Text('HaloPesa'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            provider = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g. 076XXXXXXX',
                        ),
                        onChanged: (val) {
                          phoneNumber = val;
                        },
                      ),
                    ],
                    if (accountType == 'Bank') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: provider ?? 'NMB',
                        decoration: const InputDecoration(
                          labelText: 'Bank Brand',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'NMB',
                            child: Text('NMB Bank'),
                          ),
                          DropdownMenuItem(
                            value: 'CRDB',
                            child: Text('CRDB Bank'),
                          ),
                          DropdownMenuItem(
                            value: 'NBC',
                            child: Text('NBC Bank'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            provider = val;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Initial Balance (Tsh)',
                        hintText: 'e.g. 150,000',
                      ),
                    ),
                  ],
                ),
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
          },
        );
      },
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
              ),
              title: const Text('New Workspace'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Workspace Name',
                        hintText: 'e.g. Side Gig, Paris Trip',
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
                ),
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
          },
        );
      },
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
              // ── 1. Elegant Lowercase 'home' Header (Mobbin inspired) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                      ),
                      if (activeTrackerAsync.value != null) ...[
                        const SizedBox(height: 2),
                        TactileSpringContainer(
                          onTap: () =>
                              _showWorkspaceSelectorSheet(context, ref),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 3.0,
                            ),
                            decoration: BoxDecoration(
                              color: trackerColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: trackerColor.withOpacity(0.2),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getTrackerIcon(
                                    activeTrackerAsync.value!.icon,
                                  ),
                                  color: trackerColor,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  trackerName.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: trackerColor,
                                    fontSize: 9,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: trackerColor,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      // Review Queue Bell trigger
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              size: 26,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            onPressed: () => context.push('/sms-review'),
                          ),
                          if (pendingReviewCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF453A),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$pendingReviewCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => context.go('/settings'),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: trackerColor.withOpacity(0.12),
                          child: Icon(
                            Icons.person_rounded,
                            color: trackerColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 2. "pesaflow cash" Balance Hero Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F10) : Colors.white,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'pesa',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'flow',
                              style: TextStyle(
                                fontWeight: FontWeight.w300,
                                fontSize: 18,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        // Dynamic spent ring
                        SizedBox(
                          height: 38,
                          width: 38,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: overallPct,
                                strokeWidth: 4,
                                backgroundColor:
                                    isDark ? Colors.white10 : Colors.black12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  overallPct > 0.9
                                      ? const Color(0xFFFF453A)
                                      : (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF)),
                                ),
                              ),
                              Icon(
                                Icons.pie_chart_rounded,
                                size: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AmountText(
                      amountInCents: netWorth,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 38,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 0.5,
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                    ),
                    const SizedBox(height: 14),
                    // Breakdown accounts
                    if (account1 != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${account1.name} balance',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isDark ? const Color(0x3300E5FF) : const Color(0x330A84FF),
                                width: 1.0,
                              ),
                              color: isDark ? const Color(0x0D00E5FF) : const Color(0x0D0A84FF),
                            ),
                            child: AmountText(
                              amountInCents: account1.balance,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (account2 != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${account2.name} balance',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isDark ? const Color(0x3300E5FF) : const Color(0x330A84FF),
                                width: 1.0,
                              ),
                              color: isDark ? const Color(0x0D00E5FF) : const Color(0x0D0A84FF),
                            ),
                            child: AmountText(
                              amountInCents: account2.balance,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (account1 == null) ...[
                      const Center(
                        child: Text(
                          'No active accounts. Tap Add Account below to start.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
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
                padding: const EdgeInsets.all(18.0),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.thumb_up_rounded,
                              color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Review SMS Alerts',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            pendingReviewCount > 0
                                ? '$pendingReviewCount pending'
                                : '0 pending',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: pendingReviewCount > 0
                                  ? const Color(0xFFFF9F0A)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Next: Categorize parsed bank & mobile money messages.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Parser active checkmark rows
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: isDark ? Colors.black : Colors.white,
                                size: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: isDark ? Colors.black : Colors.white,
                                size: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: isDark ? Colors.black : Colors.white,
                                size: 10,
                              ),
                            ),
                          ],
                        ),
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
                            child: Text(
                              "Let's go!",
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
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
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F10) : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'budget',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                ' health',
                                style: TextStyle(
                                  fontWeight: FontWeight.w300,
                                  fontSize: 14,
                                  color: isDark ? Colors.grey : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(1000 - (overallPct * 1000).round()).clamp(0, 1000)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 42,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                    ),
                    // Multi-colored Gradient Ring
                    SizedBox(
                      height: 70,
                      width: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05),
                            ),
                          ),
                          CircularProgressIndicator(
                            value: (1.0 - overallPct), // Score remaining budget
                            strokeWidth: 6,
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
                                  fontSize: 12,
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
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
