import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:telephony/telephony.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Account toggles
  final Map<String, bool> _accounts = {
    'M-Pesa': false,
    'Airtel Money': false,
    'Tigo Pesa': false,
    'NMB Bank': false,
    'CRDB Bank': false,
    'Cash Wallet': false,
  };

  final Map<String, String> _providers = {
    'M-Pesa': 'M-Pesa_TZ',
    'Airtel Money': 'AirtelMoney_TZ',
    'Tigo Pesa': 'TigoPesa_TZ',
    'NMB Bank': 'NMB',
    'CRDB Bank': 'CRDB',
    'Cash Wallet': '',
  };

  final Map<String, String> _types = {
    'M-Pesa': 'mobile_money',
    'Airtel Money': 'mobile_money',
    'Tigo Pesa': 'mobile_money',
    'NMB Bank': 'bank',
    'CRDB Bank': 'bank',
    'Cash Wallet': 'cash',
  };

  final Map<String, IconData> _icons = {
    'M-Pesa': Icons.phone_android_rounded,
    'Airtel Money': Icons.phone_android_rounded,
    'Tigo Pesa': Icons.phone_android_rounded,
    'NMB Bank': Icons.account_balance_rounded,
    'CRDB Bank': Icons.account_balance_rounded,
    'Cash Wallet': Icons.account_balance_wallet_rounded,
  };

  void _nextPage() async {
    if (_currentPage == 1) {
      try {
        await Telephony.instance.requestPhoneAndSmsPermissions;
      } catch (_) {}
    }
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _finish() async {
    // Create selected accounts
    final accountRepo = ref.read(accountRepositoryProvider);
    const uuid = Uuid();
    for (final entry in _accounts.entries) {
      if (entry.value) {
        final iconStr = _types[entry.key] == 'mobile_money' ? 'phone-android' : _types[entry.key] == 'bank' ? 'account-balance' : 'wallet';
        await accountRepo.createAccount(Account(
          id: uuid.v4(), name: entry.key, type: _types[entry.key]!,
          balance: 0, provider: _providers[entry.key]!.isNotEmpty ? _providers[entry.key] : null,
          icon: iconStr, sortOrder: 0, isArchived: false, createdAt: DateTime.now(),
        ));
      }
    }
    // Mark onboarding complete
    await ref.read(settingsRepositoryProvider).markOnboardingComplete();
    ref.invalidate(accountsStreamProvider);
    if (mounted) context.go('/');
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Progress dots
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _currentPage ? 24 : 8, height: 8,
              decoration: BoxDecoration(color: i == _currentPage ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(4)),
            ))),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _WelcomePage(theme: theme),
                _SmsPermissionPage(theme: theme),
                _AccountsPage(theme: theme, accounts: _accounts, icons: _icons, onToggle: (name, val) => setState(() => _accounts[name] = val)),
                _CompletePage(theme: theme),
              ],
            ),
          ),
          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              if (_currentPage > 0 && _currentPage < 3) TextButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('Back')),
              const Spacer(),
              if (_currentPage < 3) ElevatedButton(onPressed: _nextPage, child: const Text('Continue'))
              else ElevatedButton(onPressed: _finish, child: const Text('Start Tracking')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final ThemeData theme;
  const _WelcomePage({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.7)]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.account_balance_wallet_rounded, size: 64, color: Colors.white),
        ),
        const SizedBox(height: 32),
        Text('Welcome to PesaFlow', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text('Track your finances offline.\n100% private — data never leaves your device.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
      ]),
    );
  }
}

class _SmsPermissionPage extends StatelessWidget {
  final ThemeData theme;
  const _SmsPermissionPage({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.sms_rounded, size: 56, color: theme.colorScheme.primary)),
        const SizedBox(height: 32),
        Text('SMS Auto-Tracking', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text('PesaFlow can automatically read M-Pesa, Airtel Money, and bank SMS to log your transactions — no typing needed.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3))),
          child: Row(children: [
            Icon(Icons.lock_rounded, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('SMS data is processed locally and never sent anywhere.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          ]),
        ),
        const SizedBox(height: 16),
        Text('You can skip this and add transactions manually.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ]),
    );
  }
}

class _AccountsPage extends StatelessWidget {
  final ThemeData theme;
  final Map<String, bool> accounts;
  final Map<String, IconData> icons;
  final void Function(String, bool) onToggle;

  const _AccountsPage({
    required this.theme,
    required this.accounts,
    required this.icons,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Set Up Accounts',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the accounts you use. You can add more later.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const BouncingScrollPhysics(),
              children: accounts.entries.map((e) {
                final isSelected = e.value;
                return TactileSpringContainer(
                  onTap: () => onToggle(e.key, !isSelected),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.08)
                          : (theme.brightness == Brightness.dark
                              ? AppTheme.surfaceContainerDark
                              : AppTheme.surfaceLight),
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (theme.brightness == Brightness.dark
                                ? const Color(0x1DFFFFFF)
                                : const Color(0x15000000)),
                        width: isSelected ? 1.5 : 0.8,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withOpacity(0.12)
                                : (theme.brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icons[e.key],
                            color: isSelected ? theme.colorScheme.primary : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          e.key,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected
                                ? (theme.brightness == Brightness.dark ? Colors.white : theme.colorScheme.primary)
                                : (theme.brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Mini check bubble
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : Colors.grey,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 10, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletePage extends StatelessWidget {
  final ThemeData theme;
  const _CompletePage({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppTheme.incomeColor.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, size: 64, color: AppTheme.incomeColor)),
        const SizedBox(height: 32),
        Text('You\'re All Set!', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text('Your offline finance tracker is ready.\nStart recording transactions and take control of your money.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
      ]),
    );
  }
}

