import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:pesaflow/core/router/app_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/domain/sms/pending_review_notifier.dart';
import 'package:pesaflow/domain/sms/sms_processor.dart';
import 'package:pesaflow/presentation/common/widgets/sms_review_dialog.dart';
import 'package:pesaflow/services/budget_alert_service.dart';
import 'package:pesaflow/services/savings_reminder_service.dart';
import 'package:pesaflow/services/sms_background_service.dart';

const _accentChannel = MethodChannel('pesaflow/system_accent');

const _greyFallback = 0xFF9E9E9E;

Future<int> _getSystemAccentColor() async {
  if (!Platform.isAndroid) return _greyFallback;
  try {
    final result = await _accentChannel.invokeMethod<int>('getAccentColor');
    if (result != null) return result & 0xFFFFFFFF;
  } catch (_) {}
  return _greyFallback;
}

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

class _PesaFlowAppState extends ConsumerState<PesaFlowApp> {
  static const _notificationChannel = MethodChannel('pesaflow/notification_listener');
  int _accentColor = _greyFallback;

  @override
  void initState() {
    super.initState();
    _loadAccentColor();

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
          } catch (_) {}
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
      } catch (_) {}

      // Check savings reminder — alert if no saving activity in 7+ days
      try {
        await ref.read(savingsReminderServiceProvider).checkAndSendReminder();
      } catch (_) {}

      // Check if Notification Access is enabled; if not, prompt once
      await _checkNotificationAccess();
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
        } catch (_) {}
      }
      await _notificationChannel.invokeMethod('clearPendingSms');
      developer.log('Cleared pending SMS queue', name: 'SmsNotification');
    } catch (e) {
      developer.log('Pending SMS retrieval failed: $e', name: 'SmsNotification');
    }
  }

  Future<void> _checkNotificationAccess() async {
    if (!context.mounted) return;
    try {
      final dismissed = await ref.read(settingsRepositoryProvider).getSetting('notification_access_prompt_dismissed');
      if (dismissed == 'true') return;

      final enabled = await _notificationChannel.invokeMethod<bool>('isNotificationListenerEnabled');
      if (enabled == true) return;

      developer.log('Notification Access not enabled — prompting user', name: 'AppLaunch');
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Notification Access'),
          content: const Text(
            'PesaFlow needs Notification Access to detect transaction SMS on Android 14+.\n\n'
            'Tap "Open Settings" and toggle PesaFlow ON in the list.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('Remind later'),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(settingsRepositoryProvider).setSetting('notification_access_prompt_dismissed', 'true');
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text("Don't show again"),
            ),
            FilledButton(
              onPressed: () async {
                await _notificationChannel.invokeMethod('openNotificationListenerSettings');
                Navigator.of(ctx).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } catch (e) {
      developer.log('Notification access check failed: $e', name: 'AppLaunch');
    }
  }

  Future<void> _loadAccentColor() async {
    final color = await _getSystemAccentColor();
    if (mounted) setState(() => _accentColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(_accentColor);

    final lightCs = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    );
    final darkCs = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accentColor,
    );

    return MaterialApp.router(
      title: 'PesaFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromColorScheme(lightCs, Brightness.light),
      darkTheme: AppTheme.fromColorScheme(darkCs, Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: CupertinoScrollBehavior(),
          child: Stack(
            children: [
              ?child,
              _PendingReviewOverlay(),
            ],
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
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final pendingItem = ref.watch(pendingReviewProvider);

    if (pendingItem != null && !_dialogOpen) {
      _dialogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => SmsReviewDialog(item: pendingItem),
        ).then((_) {
          _dialogOpen = false;
        }).catchError((_) {
          _dialogOpen = false;
        });
      });
    }

    return const SizedBox.shrink();
  }
}
