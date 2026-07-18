import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/services/sms_background_service.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/data/seed/demo_seeder.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _smsPermissionGranted = false;

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
    'M-Pesa': PesaFlowIcons.cash,
    'Airtel Money': PesaFlowIcons.cash,
    'Tigo Pesa': PesaFlowIcons.cash,
    'NMB Bank': PesaFlowIcons.loans,
    'CRDB Bank': PesaFlowIcons.loans,
    'Cash Wallet': PesaFlowIcons.wallet,
  };

  void _nextPage() async {
    if (_currentPage == 1) {
      try {
        final statuses = await [Permission.sms, Permission.phone].request();
        final granted =
            statuses[Permission.sms]?.isGranted == true &&
            statuses[Permission.phone]?.isGranted == true;
        if (mounted) setState(() => _smsPermissionGranted = granted);
      } catch (e) {
        developer.log('Permission request failed: $e', name: 'Onboarding');
      }
    }
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish({bool seedDemo = false}) async {
    try {
      if (seedDemo) {
        final db = ref.read(databaseProvider);
        await DemoSeeder(db).seedDemoData();
      } else {
        final accountRepo = ref.read(accountRepositoryProvider);
        const uuid = Uuid();
        for (final entry in _accounts.entries) {
          if (entry.value) {
            final accType = _types[entry.key] ?? 'mobile_money';
            final iconStr = accType == 'mobile_money'
                ? 'phone-android'
                : accType == 'bank'
                ? 'account-balance'
                : 'wallet';
            final provider = _providers[entry.key];
            await accountRepo.createAccount(
              Account(
                id: uuid.v4(),
                name: entry.key,
                type: accType,
                balance: 0,
                provider: (provider != null && provider.isNotEmpty)
                    ? provider
                    : null,
                icon: iconStr,
                sortOrder: 0,
                isArchived: false,
                createdAt: DateTime.now(),
              ),
            );
          }
        }
      }
      await ref.read(settingsRepositoryProvider).markOnboardingComplete();
      ref.invalidate(accountsStreamProvider);
      try {
        await ref.read(smsBackgroundServiceProvider).initialize();
        developer.log(
          'Background SMS service initialized successfully from onboarding',
          name: 'Onboarding',
        );
      } catch (e) {
        developer.log(
          'Failed to initialize SMS background service: $e',
          name: 'Onboarding',
        );
      }
      if (mounted) context.go('/');
    } catch (e) {
      developer.log(
        'Onboarding account creation failed: $e',
        name: 'Onboarding',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize setup: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Progress dots
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: kSpacing16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: kSpacing4),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(theme: theme),
                  _SmsPermissionPage(
                    theme: theme,
                    permissionGranted: _smsPermissionGranted,
                  ),
                  _AccountsPage(
                    theme: theme,
                    accounts: _accounts,
                    icons: _icons,
                    onToggle: (name, val) =>
                        setState(() => _accounts[name] = val),
                  ),
                  _CompletePage(theme: theme),
                ],
              ),
            ),
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(kSpacing24),
              child: _currentPage == 3
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TactileSpringContainer(
                          onTap: () => _finish(seedDemo: true),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              vertical: kSpacing14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Explore with Demo Data',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing12),
                        TactileSpringContainer(
                          onTap: () => _finish(seedDemo: false),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              vertical: kSpacing14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outline,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Start Fresh',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        if (_currentPage > 0)
                          TextButton(
                            onPressed: () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        TactileSpringContainer(
                          onTap: _nextPage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        if (_currentPage < 3)
          Positioned(
            top: kSpacing8,
            right: kSpacing4,
            child: TextButton(
              onPressed: _finish,
              child: Text(
                'Skip',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
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

class _WelcomePage extends StatelessWidget {
  final ThemeData theme;
  const _WelcomePage({required this.theme});
  @override
  Widget build(BuildContext context) {
    return StaggeredFadeSlide(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(kSpacing28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PesaFlowIcons.wallet,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: kSpacing32),
            Text(
              'Welcome to PesaFlow',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpacing16),
            Text(
              'Track your finances offline.\n100% private — data never leaves your device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsPermissionPage extends StatelessWidget {
  final ThemeData theme;
  final bool permissionGranted;
  const _SmsPermissionPage({
    required this.theme,
    this.permissionGranted = false,
  });
  @override
  Widget build(BuildContext context) {
    return StaggeredFadeSlide(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sms_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (permissionGranted)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(kSpacing4),
                      decoration: BoxDecoration(
                        color: context.appColors.incomeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: kSpacing32),
            Text(
              'SMS Auto-Tracking',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpacing16),
            Text(
              'PesaFlow can automatically read M-Pesa, Airtel Money, and bank SMS to log your transactions — no typing needed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: kSpacing24),
            Container(
              padding: const EdgeInsets.all(kSpacing16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppTheme.surfaceContainerDark
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PesaFlowIcons.lock,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: kSpacing12),
                  Expanded(
                    child: Text(
                      'SMS data is processed locally and never sent anywhere.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kSpacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  permissionGranted
                      ? PesaFlowIcons.success
                      : PesaFlowIcons.info,
                  size: 14,
                  color: permissionGranted
                      ? context.appColors.incomeColor
                      : Colors.grey,
                ),
                const SizedBox(width: kSpacing6),
                Text(
                  permissionGranted
                      ? 'SMS Permission Granted'
                      : 'You can also add transactions manually without SMS.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: permissionGranted
                        ? context.appColors.incomeColor
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: kSpacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: kSpacing24),
          StaggeredFadeSlide(
            index: 0,
            child: Text(
              'Set Up Accounts',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: kSpacing8),
          StaggeredFadeSlide(
            index: 1,
            child: Text(
              'Select the accounts you use. You can add more later.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: kSpacing24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const BouncingScrollPhysics(),
              children: accounts.entries.toList().asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final isSelected = e.value;
                return StaggeredFadeSlide(
                  index: 2 + i,
                  child: TactileSpringContainer(
                    onTap: () => onToggle(e.key, !isSelected),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : (theme.brightness == Brightness.dark
                                  ? AppTheme.surfaceContainerDark
                                  : AppTheme.surfaceLight),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.08,
                                ),
                          width: isSelected ? 1.5 : 0.8,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.06,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.all(kSpacing16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    )
                                  : (theme.brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icons[e.key],
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: kSpacing12),
                          Text(
                            e.key,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall!
                                .copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? (theme.brightness == Brightness.dark
                                            ? Colors.white
                                            : theme.colorScheme.primary)
                                      : (theme.brightness == Brightness.dark
                                            ? Colors.grey[300]
                                            : Colors.grey[700]),
                                ),
                          ),
                          const SizedBox(height: kSpacing8),
                          // Mini check bubble
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.grey,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 10,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    ),
  ),
);
  }
}


class _CompletePage extends StatelessWidget {
  final ThemeData theme;
  const _CompletePage({required this.theme});
  @override
  Widget build(BuildContext context) {
    return StaggeredFadeSlide(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(kSpacing24),
              decoration: BoxDecoration(
                color: context.appColors.incomeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PesaFlowIcons.success,
                size: 64,
                color: context.appColors.incomeColor,
              ),
            ),
            const SizedBox(height: kSpacing32),
            Text(
              'You\'re All Set!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpacing16),
            Text(
              'Your offline finance tracker is ready.\nStart recording transactions and take control of your money.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
