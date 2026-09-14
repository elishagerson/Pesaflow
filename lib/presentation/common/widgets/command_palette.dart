import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/router/app_router.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/global_search_provider.dart';
import 'package:pesaflow/presentation/state/palette_provider.dart';

class _PaletteAction {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String route;
  final List<String> keywords;
  final bool isDataResult;
  final String category;

  const _PaletteAction({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.route,
    this.keywords = const [],
    this.isDataResult = false,
    this.category = 'Quick Actions',
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    if (label.toLowerCase().contains(q)) return true;
    if (subtitle != null && subtitle!.toLowerCase().contains(q)) return true;
    if (keywords.any((k) => k.toLowerCase().contains(q))) return true;
    return false;
  }
}

const _actions = <_PaletteAction>[
  // ── Quick Actions ──────────────────────────────────────────────────────────
  _PaletteAction(
    icon: PesaFlowIcons.expense,
    label: 'Record Expense',
    subtitle: 'Log money spent or bill paid',
    route: '/transactions/add?type=expense',
    keywords: ['spend', 'expense', 'buy', 'pay', 'out', 'cash', 'money'],
    category: 'Quick Actions',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.income,
    label: 'Record Income',
    subtitle: 'Log salary, deposit, or earnings',
    route: '/transactions/add?type=income',
    keywords: ['income', 'salary', 'deposit', 'earn', 'receive', 'in', 'money'],
    category: 'Quick Actions',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.transfer,
    label: 'Transfer Money',
    subtitle: 'Move funds between accounts',
    route: '/transactions/add?type=transfer',
    keywords: ['transfer', 'move', 'send', 'shift', 'withdraw'],
    category: 'Quick Actions',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.add,
    label: 'New Budget',
    subtitle: 'Set up category spending limit',
    route: '/budgets/add',
    keywords: ['budget', 'create', 'new', 'limit', 'cap'],
    category: 'Quick Actions',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.goal,
    label: 'New Savings Goal',
    subtitle: 'Create a savings target milestone',
    route: '/savings-goals/add',
    keywords: ['save', 'goal', 'target', 'new', 'fund'],
    category: 'Quick Actions',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.loans,
    label: 'New Loan',
    subtitle: 'Track money borrowed or lent',
    route: '/loans/add',
    keywords: ['loan', 'debt', 'borrow', 'lend', 'credit'],
    category: 'Quick Actions',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.subscriptions,
    label: 'New Recurring Bill',
    subtitle: 'Track recurring subscriptions & bills',
    route: '/recurring/add',
    keywords: ['recurring', 'bill', 'subscription', 'renewal', 'utility'],
    category: 'Quick Actions',
  ),

  // ── Navigation ─────────────────────────────────────────────────────────────
  _PaletteAction(
    icon: PesaFlowIcons.dashboard,
    label: 'Go to Dashboard',
    subtitle: 'Executive overview & live cash flow',
    route: '/',
    keywords: ['home', 'dashboard', 'overview', 'summary'],
    category: 'Navigation',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.transactions,
    label: 'View Transactions',
    subtitle: 'Search, filter, and audit history',
    route: '/transactions',
    keywords: ['transactions', 'history', 'list', 'ledger', 'all'],
    category: 'Navigation',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.budgets,
    label: 'View Budgets',
    subtitle: 'Monthly limits & envelope progress',
    route: '/budgets',
    keywords: ['budgets', 'spending', 'limits', 'progress'],
    category: 'Navigation',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.target,
    label: 'View Savings Goals',
    subtitle: 'Track progress toward financial targets',
    route: '/savings-goals',
    keywords: ['savings', 'goals', 'targets', 'emergency fund'],
    category: 'Navigation',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.loans,
    label: 'View Loans',
    subtitle: 'Outstanding balances & payoff projections',
    route: '/loans',
    keywords: ['loans', 'debts', 'borrowing', 'payoff'],
    category: 'Navigation',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.subscriptions,
    label: 'View Recurring & Bills',
    subtitle: 'Upcoming renewal calendar & schedules',
    route: '/recurring',
    keywords: ['recurring', 'bills', 'subscriptions', 'renewals'],
    category: 'Navigation',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.analytics,
    label: 'View Analytics',
    subtitle: 'Cash flow breakdowns & monthly trends',
    route: '/analytics',
    keywords: ['analytics', 'reports', 'charts', 'trends', 'stats', 'insights'],
    category: 'Navigation',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.sms,
    label: 'SMS Review',
    subtitle: 'Process detected telecom & bank SMS',
    route: '/sms-review',
    keywords: [
      'sms',
      'review',
      'pending',
      'mpesa',
      'selcom',
      'airtel',
      'crdb',
      'nmb',
    ],
    category: 'Navigation',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.settings,
    label: 'Settings',
    subtitle: 'Preferences, security, and CSV import',
    route: '/settings',
    keywords: [
      'settings',
      'preferences',
      'theme',
      'import',
      'export',
      'security',
      'lock',
    ],
    category: 'Navigation',
  ),
];

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  int _selectedIndex = 0;
  List<_PaletteAction> _cachedDataResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        final query = ref.read(paletteQueryProvider);
        final results = _filtered(query);
        if (results.isEmpty) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          PesaHaptics.selection();
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % results.length;
          });
          _scrollToIndex(_selectedIndex);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          PesaHaptics.selection();
          setState(() {
            _selectedIndex =
                (_selectedIndex - 1 + results.length) % results.length;
          });
          _scrollToIndex(_selectedIndex);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _select(results[_selectedIndex]);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          _dismiss();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemEstimateHeight = 58.0;
    final targetOffset = (index * itemEstimateHeight) - 120.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  List<_PaletteAction> _filtered(String query) {
    final actions = _actions.where((a) => a.matches(query)).toList();
    if (_cachedDataResults.isNotEmpty) {
      return [...actions, ..._cachedDataResults];
    }
    return actions;
  }

  void _select(_PaletteAction action) {
    PesaHaptics.selection();
    ref.read(paletteVisibilityProvider.notifier).hide();
    ref.read(paletteQueryProvider.notifier).clear();
    appRouter.go(action.route);
  }

  void _dismiss() {
    PesaHaptics.selection();
    ref.read(paletteVisibilityProvider.notifier).hide();
    ref.read(paletteQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(paletteQueryProvider);
    final searchResults = ref.watch(globalSearchProvider(query));
    final dataResults = (searchResults.asData?.value ?? [])
        .map(
          (r) => _PaletteAction(
            icon: r.icon,
            label: r.title,
            subtitle: r.subtitle,
            route: r.route,
            isDataResult: true,
            category: r.category,
          ),
        )
        .toList();
    _cachedDataResults = dataResults;
    final results = _filtered(query);

    _selectedIndex = _selectedIndex.clamp(
      0,
      results.isEmpty ? 0 : results.length - 1,
    );

    final groupedResults = <String, List<_PaletteAction>>{};
    for (final action in results) {
      groupedResults.putIfAbsent(action.category, () => []).add(action);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final paletteWidth = math.min(screenWidth - 32, 540.0);
    final paletteMaxHeight = math.min(screenHeight * 0.78, 580.0);

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap inside palette from dismissing
              child: Container(
                width: paletteWidth,
                constraints: BoxConstraints(maxHeight: paletteMaxHeight),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.28,
                    ),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Search Input Header ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                PesaFlowIcons.search,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _focusNode,
                                autofocus: true,
                                style: context.ts(
                                  16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type a command or search...',
                                  hintStyle: context.ts(
                                    15,
                                    color: context.appColors.textMedium,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (v) {
                                  if (v.isEmpty) {
                                    _debounceTimer?.cancel();
                                    ref
                                        .read(paletteQueryProvider.notifier)
                                        .clear();
                                    setState(() => _selectedIndex = 0);
                                  } else {
                                    _debounceTimer?.cancel();
                                    _debounceTimer = Timer(
                                      const Duration(milliseconds: 120),
                                      () {
                                        ref
                                            .read(paletteQueryProvider.notifier)
                                            .update(v);
                                        setState(() => _selectedIndex = 0);
                                      },
                                    );
                                  }
                                },
                                onSubmitted: (_) {
                                  if (results.isNotEmpty) {
                                    _select(results[_selectedIndex]);
                                  }
                                },
                              ),
                            ),
                            if (searchResults.isLoading)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                            else if (query.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  ref
                                      .read(paletteQueryProvider.notifier)
                                      .clear();
                                  setState(() => _selectedIndex = 0);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    PesaFlowIcons.close,
                                    size: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'ESC',
                                  style: context.ts(
                                    10,
                                    fontWeight: FontWeight.w700,
                                    color: context.appColors.textMedium,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Hairline divider
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.22,
                        ),
                      ),

                      // ── Results or Empty State ──
                      if (results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 36,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PesaFlowIcons.search,
                                  size: 22,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                query.trim().isNotEmpty
                                    ? 'No results found'
                                    : 'No matching actions',
                                style: context.ts(
                                  15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                query.trim().isNotEmpty
                                    ? 'Try searching for transactions, budgets, goals, or loans'
                                    : 'Try: "Expense", "Income", "Transfer", "Budget"',
                                style: context.ts(
                                  13,
                                  color: context.appColors.textMedium,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (query.trim().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(paletteQueryProvider.notifier)
                                        .clear();
                                  },
                                  icon: const Icon(
                                    PesaFlowIcons.clear,
                                    size: 14,
                                  ),
                                  label: const Text('Clear search'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        Flexible(
                          child: ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                            children: [
                              for (
                                var flatIndex = 0, entryIdx = 0;
                                entryIdx < groupedResults.entries.length;
                                entryIdx++
                              )
                                ...() {
                                  final entry = groupedResults.entries
                                      .elementAt(entryIdx);
                                  final category = entry.key;
                                  final categoryActions = entry.value;
                                  final items = <Widget>[];

                                  // Category Section Header with Count Pill
                                  items.add(
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        14,
                                        6,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            category.toUpperCase(),
                                            style: context.ts(
                                              11,
                                              color:
                                                  context.appColors.textMedium,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${categoryActions.length}',
                                              style: context.ts(
                                                10,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    context.appColors.textLow,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  // Action Rows
                                  for (final action in categoryActions) {
                                    final i = flatIndex++;
                                    final selected = i == _selectedIndex;

                                    items.add(
                                      StaggeredFadeSlide(
                                        index: i,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () => _select(action),
                                            onHover: (_) => setState(
                                              () => _selectedIndex = i,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? theme.colorScheme.primary
                                                          .withValues(
                                                            alpha: 0.10,
                                                          )
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: selected
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.25,
                                                            )
                                                      : Colors.transparent,
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      color: selected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : (action.isDataResult
                                                                ? theme
                                                                      .colorScheme
                                                                      .secondary
                                                                      .withValues(
                                                                        alpha:
                                                                            0.14,
                                                                      )
                                                                : theme
                                                                      .colorScheme
                                                                      .surfaceContainerHighest
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      )),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      action.icon,
                                                      size: 17,
                                                      color: selected
                                                          ? theme
                                                                .colorScheme
                                                                .onPrimary
                                                          : (action.isDataResult
                                                                ? theme
                                                                      .colorScheme
                                                                      .secondary
                                                                : theme
                                                                      .colorScheme
                                                                      .onSurfaceVariant),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          action.label,
                                                          style: context.ts(
                                                            14,
                                                            fontWeight: selected
                                                                ? FontWeight
                                                                      .w700
                                                                : FontWeight
                                                                      .w600,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        if (action.subtitle !=
                                                            null) ...[
                                                          const SizedBox(
                                                            height: 1.5,
                                                          ),
                                                          Text(
                                                            action.subtitle!,
                                                            style: context.ts(
                                                              12,
                                                              color: context
                                                                  .appColors
                                                                  .textMedium,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (selected)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 7,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            PesaFlowIcons
                                                                .arrowForward,
                                                            size: 10,
                                                            color: theme
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                            width: 3,
                                                          ),
                                                          Text(
                                                            'Select',
                                                            style: context.ts(
                                                              10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: theme
                                                                  .colorScheme
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  else
                                                    Icon(
                                                      PesaFlowIcons
                                                          .chevronRight,
                                                      size: 14,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.25,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return items;
                                }(),
                            ],
                          ),
                        ),

                      // ── Pro Footer Bar with Keyboard Shortcuts ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.20),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            _KeyHint(
                              theme: theme,
                              keys: const ['↑', '↓'],
                              label: 'Navigate',
                            ),
                            const SizedBox(width: 12),
                            _KeyHint(
                              theme: theme,
                              keys: const ['↵'],
                              label: 'Open',
                            ),
                            const SizedBox(width: 12),
                            _KeyHint(
                              theme: theme,
                              keys: const ['esc'],
                              label: 'Dismiss',
                            ),
                            const Spacer(),
                            Text(
                              '${results.length} ${results.length == 1 ? 'item' : 'items'}',
                              style: context.ts(
                                11,
                                fontWeight: FontWeight.w600,
                                color: context.appColors.textLow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final ThemeData theme;
  final List<String> keys;
  final String label;

  const _KeyHint({
    required this.theme,
    required this.keys,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in keys) ...[
          Container(
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.7,
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: Text(
              k,
              style: context.ts(
                10,
                fontWeight: FontWeight.w700,
                color: context.appColors.textMedium,
              ),
            ),
          ),
        ],
        const SizedBox(width: 3),
        Text(
          label,
          style: context.ts(
            11,
            fontWeight: FontWeight.w500,
            color: context.appColors.textLow,
          ),
        ),
      ],
    );
  }
}
