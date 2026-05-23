import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telephony/telephony.dart';
import 'dart:developer' as developer;
import 'package:pesaflow/core/router/app_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/domain/sms/pending_review_notifier.dart';
import 'package:pesaflow/presentation/common/widgets/sms_review_dialog.dart';
import 'package:pesaflow/services/sms_background_service.dart';

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
  @override
  void initState() {
    super.initState();
    // Check and close expired budget periods on app launch
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

      try {
        // Request SMS and Phone permissions on startup for automation
        final bool? granted = await Telephony.instance.requestPhoneAndSmsPermissions;
        developer.log('Telephony permissions prompt on launch: granted=$granted', name: 'AppLaunch');
        if (granted != true) {
          developer.log('SMS automation disabled: permissions not granted', name: 'AppLaunch');
        }
      } catch (e) {
        developer.log('Failed to request telephony permissions: $e', name: 'AppLaunch');
      }

      try {
        // Initialize background SMS listeners and registration
        await ref.read(smsBackgroundServiceProvider).initialize();
        developer.log('Background SMS service initialized successfully', name: 'AppLaunch');
      } catch (e) {
        developer.log('Failed to initialize SMS background service: $e', name: 'AppLaunch');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PesaFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // Pending SMS review dialog overlay
            _PendingReviewOverlay(),
          ],
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
        });
      });
    }

    return const SizedBox.shrink();
  }
}
