import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/state/palette_provider.dart';
import 'package:pesaflow/presentation/state/global_search_provider.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';

class _PaletteAction {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String route;
  final List<String> keywords;
  final bool isDataResult;

  const _PaletteAction({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.route,
    this.keywords = const [],
    this.isDataResult = false,
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (label.toLowerCase().contains(q)) return true;
    if (keywords.any((k) => k.toLowerCase().contains(q))) return true;
    return false;
  }
}

const _actions = <_PaletteAction>[
  _PaletteAction(
    icon: PesaFlowIcons.dashboard,
    label: 'Go to Dashboard',
    route: '/',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.transactions,
    label: 'Record Expense',
    route: '/transactions/add',
    keywords: ['spend', 'pay', 'out', 'buy'],
  ),
  _PaletteAction(
    icon: Icons.arrow_downward_rounded,
    label: 'Record Income',
    route: '/transactions/add',
    keywords: ['salary', 'deposit', 'earn', 'receive'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.transfer,
    label: 'Transfer Money',
    route: '/transactions/add',
    keywords: ['move', 'send', 'shift'],
  ),
  _PaletteAction(
    icon: Icons.receipt_rounded,
    label: 'View Transactions',
    route: '/transactions',
    keywords: ['list', 'history'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.wallet,
    label: 'View Accounts',
    route: '/',
  ),
  _PaletteAction(
    icon: PesaFlowIcons.budgets,
    label: 'View Budgets',
    route: '/budgets',
    keywords: ['spending', 'limit'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.analytics,
    label: 'View Analytics',
    route: '/analytics',
    keywords: ['stats', 'charts', 'report'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.target,
    label: 'View Savings Goals',
    route: '/savings-goals',
    keywords: ['target', 'save'],
  ),
  _PaletteAction(
    icon: Icons.credit_score_rounded,
    label: 'View Loans',
    route: '/loans',
    keywords: ['debt', 'borrow'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.subscriptions,
    label: 'View Recurring & Bills',
    route: '/recurring',
    keywords: ['recurring', 'bills', 'renewal', 'subscriptions'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.add,
    label: 'Add Budget',
    route: '/budgets/add',
    keywords: ['create budget limit'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.add,
    label: 'Add Loan',
    route: '/loans/add',
    keywords: ['create borrow debt'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.add,
    label: 'Add Recurring Bill',
    route: '/recurring/add',
    keywords: ['create recurring bill', 'subscription'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.add,
    label: 'Add Savings Goal',
    route: '/savings-goals/add',
    keywords: ['create target save'],
  ),
  _PaletteAction(
    icon: PesaFlowIcons.settings,
    label: 'Settings',
    route: '/settings',
    keywords: ['preferences', 'config'],
  ),
  _PaletteAction(
    icon: Icons.message_rounded,
    label: 'SMS Review',
    route: '/sms-review',
    keywords: ['pending', 'unreviewed'],
  ),
];

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _selectedIndex = 0;
  List<_PaletteAction> _cachedDataResults = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    _animController.forward();
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        final query = ref.read(paletteQueryProvider);
        final results = _filtered(query);
        if (results.isEmpty) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % results.length;
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _selectedIndex =
                (_selectedIndex - 1 + results.length) % results.length;
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _select(results[_selectedIndex]);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  List<_PaletteAction> _filtered(String query) {
    final actions = _actions.where((a) => a.matches(query)).toList();
    if (_cachedDataResults.isNotEmpty) {
      return [...actions, ..._cachedDataResults];
    }
    return actions;
  }

  void _select(_PaletteAction action) {
    ref.read(paletteVisibilityProvider.notifier).hide();
    ref.read(paletteQueryProvider.notifier).clear();
    context.go(action.route);
  }

  void _dismiss() {
    ref.read(paletteVisibilityProvider.notifier).hide();
    ref.read(paletteQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
          ),
        )
        .toList();
    _cachedDataResults = dataResults;
    final results = _filtered(query);

    _selectedIndex = _selectedIndex.clamp(0, results.length - 1);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            onTap: _dismiss,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: LiquidGlassOverlay(
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 480,
                            maxHeight: 560,
                          ),
                          margin: const EdgeInsets.all(kSpacing24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xF01C1C1E)
                                : const Color(0xF0FFFFFF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.4 : 0.1,
                                ),
                                blurRadius: 40,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  kSpacing16,
                                  kSpacing16,
                                  kSpacing16,
                                  kSpacing12,
                                ),
                                child: Semantics(
                                  label: 'Search actions',
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _focusNode,
                                    autofocus: true,
                                    onChanged: (v) {
                                      ref
                                          .read(paletteQueryProvider.notifier)
                                          .update(v);
                                      setState(() => _selectedIndex = 0);
                                    },
                                    onSubmitted: (_) {
                                      if (results.isNotEmpty) {
                                        _select(results[_selectedIndex]);
                                      }
                                    },
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search actions...',
                                      prefixIcon: Icon(
                                        PesaFlowIcons.search,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                      suffixIcon: GestureDetector(
                                        onTap: _dismiss,
                                        child: Icon(
                                          PesaFlowIcons.close,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? const Color(0xFF2C2C2E)
                                          : const Color(0xFFF2F2F7),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (results.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(kSpacing24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        query.trim().length >= 2
                                            ? 'No results found'
                                            : 'No matching actions',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                      ),
                                      const SizedBox(height: kSpacing8),
                                      Text(
                                        query.trim().length >= 2
                                            ? 'Try searching transactions, budgets, goals, or loans'
                                            : 'Try: "Groceries", "Income", "MPESA"',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3),
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.fromLTRB(
                                      kSpacing8,
                                      0,
                                      kSpacing8,
                                      kSpacing8,
                                    ),
                                    itemCount: results.length,
                                    itemBuilder: (_, i) {
                                      final action = results[i];
                                      final selected = i == _selectedIndex;
                                      return StaggeredFadeSlide(
                                        index: i,
                                        child: Semantics(
                                          button: true,
                                          label: action.label,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () => _select(action),
                                              onHover: (_) => setState(
                                                () => _selectedIndex = i,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: kSpacing12,
                                                      vertical: kSpacing10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: isDark
                                                                  ? 0.2
                                                                  : 0.1,
                                                            )
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      action.icon,
                                                      size: 20,
                                                      color: action.isDataResult
                                                          ? theme
                                                                .colorScheme
                                                                .secondary
                                                          : selected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                    ),
                                                    const SizedBox(
                                                      width: kSpacing12,
                                                    ),
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
                                                            style: theme
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onSurface,
                                                                ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          if (action.subtitle !=
                                                              null) ...[
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              action.subtitle!,
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: theme
                                                                        .colorScheme
                                                                        .onSurface
                                                                        .withValues(
                                                                          alpha:
                                                                              0.5,
                                                                        ),
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
                                                    if (!action.isDataResult)
                                                      Text(
                                                        '/>',
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.3,
                                                                  ),
                                                              fontFamily:
                                                                  'monospace',
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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
            ),
          ),
        ),
      ),
    );
  }
}
