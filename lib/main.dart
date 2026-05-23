import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telephony/telephony.dart';
import 'dart:developer' as developer;
import 'package:pesaflow/core/router/app_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';

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
      } catch (e) {
        developer.log('Failed to request telephony permissions: $e', name: 'AppLaunch');
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
    );
  }
}
