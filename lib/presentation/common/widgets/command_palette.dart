import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/state/palette_provider.dart';

class _PaletteAction {
  final IconData icon;
  final String label;
  final String route;
  final List<String> keywords;

  const _PaletteAction({
    required this.icon,
    required this.label,
    required this.route,
    this.keywords = const [],
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
  _PaletteAction(icon: Icons.dashboard_rounded, label: 'Go to Dashboard', route: '/'),
  _PaletteAction(icon: Icons.receipt_long_rounded, label: 'Record Expense', route: '/transactions/add', keywords: ['spend', 'pay', 'out', 'buy']),
  _PaletteAction(icon: Icons.arrow_downward_rounded, label: 'Record Income', route: '/transactions/add', keywords: ['salary', 'deposit', 'earn', 'receive']),
  _PaletteAction(icon: Icons.swap_horiz_rounded, label: 'Transfer Money', route: '/transactions/add', keywords: ['move', 'send', 'shift']),
  _PaletteAction(icon: Icons.receipt_rounded, label: 'View Transactions', route: '/transactions', keywords: ['list', 'history']),
  _PaletteAction(icon: Icons.account_balance_wallet_rounded, label: 'View Accounts', route: '/'),
  _PaletteAction(icon: Icons.pie_chart_rounded, label: 'View Budgets', route: '/budgets', keywords: ['spending', 'limit']),
  _PaletteAction(icon: Icons.analytics_rounded, label: 'View Analytics', route: '/analytics', keywords: ['stats', 'charts', 'report']),
  _PaletteAction(icon: Icons.track_changes_rounded, label: 'View Savings Goals', route: '/savings-goals', keywords: ['target', 'save']),
  _PaletteAction(icon: Icons.credit_score_rounded, label: 'View Loans', route: '/loans', keywords: ['debt', 'borrow']),
  _PaletteAction(icon: Icons.subscriptions_rounded, label: 'View Subscriptions', route: '/subscriptions', keywords: ['recurring', 'bills', 'renewal']),
  _PaletteAction(icon: Icons.add_circle_rounded, label: 'Add Budget', route: '/budgets/add', keywords: ['create budget limit']),
  _PaletteAction(icon: Icons.add_circle_rounded, label: 'Add Loan', route: '/loans/add', keywords: ['create borrow debt']),
  _PaletteAction(icon: Icons.add_circle_rounded, label: 'Add Subscription', route: '/subscriptions/add', keywords: ['create recurring bill']),
  _PaletteAction(icon: Icons.add_circle_rounded, label: 'Add Savings Goal', route: '/savings-goals/add', keywords: ['create target save']),
  _PaletteAction(icon: Icons.settings_rounded, label: 'Settings', route: '/settings', keywords: ['preferences', 'config']),
  _PaletteAction(icon: Icons.message_rounded, label: 'SMS Review', route: '/sms-review', keywords: ['pending', 'unreviewed']),
];

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero).animate(_fadeAnimation);
    _animController.forward();
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
    return _actions.where((a) => a.matches(query)).toList();
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
    final results = _filtered(query);

    _selectedIndex = _selectedIndex.clamp(0, results.length - 1);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.4),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
                  margin: const EdgeInsets.all(kSpacing24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(kSpacing16, kSpacing16, kSpacing16, kSpacing12),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          onChanged: (v) {
                            ref.read(paletteQueryProvider.notifier).update(v);
                            setState(() => _selectedIndex = 0);
                          },
                          onSubmitted: (_) {
                            if (results.isNotEmpty) _select(results[_selectedIndex]);
                          },
                          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Search actions...',
                            prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            suffixIcon: GestureDetector(
                              onTap: _dismiss,
                              child: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      if (results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(kSpacing24),
                          child: Text('No matching actions', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        )
                      else
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(kSpacing8, 0, kSpacing8, kSpacing8),
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final action = results[i];
                              final selected = i == _selectedIndex;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _select(action),
                                  onHover: (_) => setState(() => _selectedIndex = i),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: kSpacing12, vertical: kSpacing10),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(action.icon, size: 20, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                        const SizedBox(width: kSpacing12),
                                        Expanded(
                                          child: Text(action.label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
                                        ),
                                        Text('/>', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.3), fontFamily: 'monospace')),
                                      ],
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
    );
  }
}
