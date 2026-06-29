import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:pesaflow/core/router/app_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/domain/sms/pending_review_notifier.dart';
import 'package:pesaflow/domain/sms/sms_processor.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/sms_review_dialog.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/data/repositories/subscription_repository.dart';
import 'package:pesaflow/services/budget_alert_service.dart';
import 'package:pesaflow/services/savings_reminder_service.dart';
import 'package:pesaflow/services/sms_background_service.dart';
import 'package:pesaflow/services/notification_service.dart';



void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: PesaFlowApp(),
    ),
  );
}

class PesaFlowApp extends ConsumerStatefulWidget {
  const PesaFlowApp({super.key});

  @override
  ConsumerState<PesaFlowApp> createState() => _PesaFlowAppState();
}

class _PesaFlowAppState extends ConsumerState<PesaFlowApp> with WidgetsBindingObserver {
  static const _notificationChannel = MethodChannel('pesaflow/notification_listener');
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register notification listener method channel handler
    _notificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsNotification') {
        final raw = call.arguments as String?;
        if (raw != null) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is! Map<String, dynamic>) return;
            await _handleSmsNotification(
              sender: decoded['sender'] as String? ?? '',
              body: decoded['body'] as String? ?? '',
            );
          } catch (e) {
            developer.log('Failed to decode SMS notification: $e', name: 'SmsNotification');
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(budgetRepositoryProvider).checkAndCloseExpiredPeriods();
      } catch (_) {
        // Silently handle — budgets may not exist yet
      }

      // Check onboarding status
      try {
        final completed = await ref.read(settingsRepositoryProvider).isOnboardingComplete();
        if (!completed) {
          appRouter.go('/onboarding');
          return;
        }
      } catch (e) {
        developer.log('Onboarding check failed: $e', name: 'AppLaunch');
      }

      // Request POST_NOTIFICATIONS permission (Android 13+)
      try {
        await _notificationChannel.invokeMethod('requestPostNotifications');
        developer.log('POST_NOTIFICATIONS permission requested', name: 'AppLaunch');
      } catch (e) {
        developer.log('POST_NOTIFICATIONS request failed: $e', name: 'AppLaunch');
      }

      // Initialize background SMS listeners and registration
      try {
        await ref.read(smsBackgroundServiceProvider).initialize();
        developer.log('Background SMS service initialized successfully', name: 'AppLaunch');
      } catch (e) {
        developer.log('Failed to initialize SMS background service: $e', name: 'AppLaunch');
      }

      // Process any SMS notifications captured while app was killed
      await _processPendingSms();

      // Check budget thresholds and send alerts if needed
      try {
        await ref.read(budgetAlertServiceProvider).checkAllBudgets();
      } catch (e) {
        developer.log('Budget alert check failed: $e', name: 'AppLaunch');
      }

      // Check savings reminder — alert if no saving activity in 7+ days
      try {
        await ref.read(savingsReminderServiceProvider).checkAndSendReminder();
      } catch (e) {
        developer.log('Savings reminder check failed: $e', name: 'AppLaunch');
      }

      // Check for upcoming subscription renewals
      try {
        final subRepo = ref.read(subscriptionRepositoryProvider);
        final notif = ref.read(notificationServiceProvider);
        final subs = await subRepo.getAll();
        await notif.checkSubscriptionRenewals(
          subs: subs
              .where((s) => s.status == 'active')
              .map((s) => (name: s.name, amountCents: s.amount, nextDueDate: s.nextDueDate))
              .toList(),
        );
      } catch (e) {
        developer.log('Subscription renewal check failed: $e', name: 'AppLaunch');
      }

      // Check if Notification Access is enabled; if not, prompt once
      await _checkNotificationAccess();

      // Trigger app lock if enabled
      await _triggerBiometricAuthIfNeeded();
    });
  }

  Future<void> _handleSmsNotification({required String sender, required String body}) async {
    if (sender.isEmpty || body.isEmpty) return;
    try {
      final processor = ref.read(smsProcessorProvider);
      await processor.processSms(sender, body, DateTime.now());
    } catch (e) {
      developer.log('Notification listener SMS processing failed: $e', name: 'SmsNotification');
    }
  }

  Future<void> _processPendingSms() async {
    try {
      final result = await _notificationChannel.invokeMethod<List<dynamic>>('getPendingSms');
      if (result == null || result.isEmpty) return;
      developer.log('Processing ${result.length} pending SMS from notification listener', name: 'SmsNotification');
      for (final raw in result) {
        if (raw is! String) continue;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) continue;
          await _handleSmsNotification(
            sender: decoded['sender'] as String? ?? '',
            body: decoded['body'] as String? ?? '',
          );
        } catch (e) {
          developer.log('Failed to process pending SMS: $e', name: 'SmsNotification');
        }
      }
      await _notificationChannel.invokeMethod('clearPendingSms');
      developer.log('Cleared pending SMS queue', name: 'SmsNotification');
    } catch (e) {
      developer.log('Pending SMS retrieval failed: $e', name: 'SmsNotification');
    }
  }

  Future<void> _checkNotificationAccess() async {
    if (!mounted) return;
    try {
      final dismissed = await ref.read(settingsRepositoryProvider).getSetting('notification_access_prompt_dismissed');
      if (dismissed == 'true') return;

      final enabled = await _notificationChannel.invokeMethod<bool>('isNotificationListenerEnabled');
      if (enabled == true) return;

      developer.log('Notification Access not enabled — prompting user', name: 'AppLaunch');
      if (!mounted) return;
      await ModernDialog.showCustom(
        context: context,
        barrierDismissible: false,
        child: Builder(
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Enable Notification Access'),
            content: const Text(
              'PesaFlow needs Notification Access to detect transaction SMS on Android 14+.\n\n'
              'Tap "Open Settings" and toggle PesaFlow ON in the list.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Remind later'),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(settingsRepositoryProvider).setSetting('notification_access_prompt_dismissed', 'true');
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                },
                child: const Text("Don't show again"),
              ),
              FilledButton(
                onPressed: () async {
                  await _notificationChannel.invokeMethod('openNotificationListenerSettings');
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      developer.log('Notification access check failed: $e', name: 'AppLaunch');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() {
        _isAuthenticated = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      _triggerBiometricAuthIfNeeded();
    }
  }

  Future<void> _triggerBiometricAuthIfNeeded() async {
    final lockEnabled = ref.read(appLockEnabledProvider).value ?? false;
    if (lockEnabled && !_isAuthenticated) {
      await _authenticate();
    }
  }

  Future<void> _authenticate() async {
    final localAuth = LocalAuthentication();
    try {
      final isSupported = await localAuth.isDeviceSupported();
      final canCheckBiometrics = await localAuth.canCheckBiometrics;
      if (!isSupported && !canCheckBiometrics) {
        setState(() {
          _isAuthenticated = true;
        });
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to unlock PesaFlow',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        setState(() {
          _isAuthenticated = true;
        });
      }
    } catch (e) {
      developer.log('Biometric authentication failed: $e', name: 'BiometricLock');
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF609F8A);

    final lightCs = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: accentColor,
    );
    final darkCs = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accentColor,
    );

    final lockEnabled = ref.watch(appLockEnabledProvider).value ?? false;
    final showLockOverlay = lockEnabled && !_isAuthenticated;
    final mode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'PesaFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromColorScheme(lightCs, Brightness.light),
      darkTheme: AppTheme.fromColorScheme(darkCs, Brightness.dark),
      themeMode: mode,
      routerConfig: appRouter,
      builder: (context, child) {
        final isLight = mode == ThemeMode.light ||
            (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final systemOverlay = isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlay.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemStatusBarContrastEnforced: false,
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ScrollConfiguration(
              behavior: CupertinoScrollBehavior(),
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  _PendingReviewOverlay(),
                  if (showLockOverlay)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.85),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery.sizeOf(context).width < 400 ? 16 : 32,
                                vertical: 32,
                              ),
                              child: Card(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Semantics(
                        label: 'App locked',
                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF609F8A).withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.lock_outline_rounded,
                                            color: Color(0xFF609F8A),
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      const Text(
                                        'PesaFlow Locked',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Authentication required to access offline data',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 32),
                                      FilledButton.icon(
                                        onPressed: _authenticate,
                                        icon: const Icon(Icons.fingerprint_rounded),
                                        label: const Text('Unlock App'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF609F8A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 14,
                                          ),
                                          minimumSize: const Size(200, 48),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Overlay widget that listens for pending SMS transactions needing
/// category assignment and shows a dialog immediately.
class _PendingReviewOverlay extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PendingReviewOverlay> createState() => _PendingReviewOverlayState();
}

class _PendingReviewOverlayState extends ConsumerState<_PendingReviewOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showReviewIfNeeded());
  }

  void _showReviewIfNeeded() {
    final pendingItem = ref.read(pendingReviewProvider);
    if (pendingItem != null && context.mounted) {
      ModernDialog.showCustom(
        context: context,
        barrierDismissible: false,
        child: SmsReviewDialog(item: pendingItem),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingReviewProvider, (prev, next) {
      if (next != null && prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ModernDialog.showCustom(
            context: context,
            barrierDismissible: false,
            child: SmsReviewDialog(item: next),
          );
        });
      }
    });
    return const SizedBox.shrink();
  }
}
