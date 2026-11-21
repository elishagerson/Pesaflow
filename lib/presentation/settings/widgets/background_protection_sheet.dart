import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

/// Opens a bottom sheet guiding users on how to protect PesaFlow from
/// aggressive OEM battery killers (Tecno, Infinix, itel, Xiaomi, Samsung, etc.).
void showBackgroundProtectionSheet(BuildContext context) {
  IosBottomSheet.show(
    context: context,
    initialChildSize: 0.85,
    maxChildSize: 0.95,
    child: const _BackgroundProtectionContent(),
  );
}

class _BackgroundProtectionContent extends StatefulWidget {
  const _BackgroundProtectionContent();

  @override
  State<_BackgroundProtectionContent> createState() =>
      _BackgroundProtectionContentState();
}

class _BackgroundProtectionContentState
    extends State<_BackgroundProtectionContent> {
  int _selectedBrandIndex = 0;

  final List<({String name, String sub, List<String> steps})> _brands = const [
    (
      name: 'Tecno / itel (HiOS)',
      sub: 'Phone Master & Auto-start',
      steps: [
        'Open your phone Settings → App Management → Auto-start management.',
        'Find PesaFlow in the list and toggle Auto-start to ON.',
        'Open the Phone Master app → Toolbox / Battery → Battery Optimization.',
        'Find PesaFlow and select "Don\'t optimize".',
        'Open Recent Apps switcher, swipe down on PesaFlow card and tap the Lock icon.',
      ],
    ),
    (
      name: 'Infinix (XOS)',
      sub: 'XArena & Power Marathon',
      steps: [
        'Open phone Settings → App Management → Auto-start Management → Enable PesaFlow.',
        'Open Phone Master app → Power Marathon / Battery → Battery Saver.',
        'Set PesaFlow to "No Restrictions" or "Don\'t Optimize".',
        'Lock PesaFlow in Recent Apps so it stays running in memory.',
      ],
    ),
    (
      name: 'Xiaomi / Redmi (MIUI / HyperOS)',
      sub: 'Autostart & Battery Saver',
      steps: [
        'Open Settings → Apps → Manage Apps → PesaFlow.',
        'Enable the "Autostart" toggle.',
        'Scroll down to "Battery saver" and select "No restrictions".',
        'In App permissions, ensure SMS and Notifications are Allowed.',
        'In Recent Apps switcher, long-press PesaFlow card and tap the Lock icon.',
      ],
    ),
    (
      name: 'Samsung (One UI)',
      sub: 'Never Sleeping Apps',
      steps: [
        'Open Settings → Battery and device care → Battery.',
        'Tap Background usage limits → Never sleeping apps.',
        'Tap the "+" icon and add PesaFlow to the list.',
        'Under Settings → Apps → PesaFlow → Battery, choose "Unrestricted".',
      ],
    ),
    (
      name: 'Oppo / Realme / Vivo',
      sub: 'Auto-launch & Background Activity',
      steps: [
        'Open Settings → App Management → PesaFlow.',
        'Tap Battery Usage → enable "Allow background activity" & "Allow auto-launch".',
        'Turn off "Optimize battery use" for PesaFlow.',
      ],
    ),
    (
      name: 'Other Android Phones',
      sub: 'Stock / Nokia / Pixel',
      steps: [
        'Open Settings → Apps → PesaFlow → App battery usage.',
        'Select "Unrestricted" instead of "Optimized".',
        'Ensure SMS and Notification permissions are permanently granted.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBrand = _brands[_selectedBrandIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: kSpacing16),
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                ),
                child: const Icon(
                  PesaFlowIcons.bolt,
                  color: Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: kSpacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Background Reliability',
                      style: context.ts(20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keep SMS capture alive when screen is off',
                      style: context.ts(
                        13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: kSpacing16),

          // Context Banner
          Container(
            padding: const EdgeInsets.all(kSpacing12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusInput),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PesaFlowIcons.emergency,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: kSpacing8),
                Expanded(
                  child: Text(
                    'Many phones (especially Tecno, Infinix, itel & Xiaomi) kill background apps to save battery. Follow these steps so PesaFlow never misses your mobile money SMS.',
                    style: context.ts(12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: kSpacing16),

          // Brand Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_brands.length, (idx) {
                final isSelected = _selectedBrandIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: kSpacing8),
                  child: ChoiceChip(
                    label: Text(_brands[idx].name),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        PesaHaptics.light();
                        setState(() => _selectedBrandIndex = idx);
                      }
                    },
                    selectedColor: theme.colorScheme.primaryContainer,
                    labelStyle: context.ts(
                      12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: kSpacing16),

          // Steps List
          Expanded(
            child: ListView.separated(
              itemCount: activeBrand.steps.length,
              separatorBuilder: (_, _) => const SizedBox(height: kSpacing12),
              itemBuilder: (context, idx) {
                final stepText = activeBrand.steps[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${idx + 1}',
                        style: context.ts(
                          12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: kSpacing12),
                    Expanded(
                      child: Text(
                        stepText,
                        style: context.ts(13, height: 1.35),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: kSpacing12),

          // Action Button
          TactileSpringContainer(
            onTap: () async {
              PesaHaptics.medium();
              await openAppSettings();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: kSpacing14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    PesaFlowIcons.settings,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    'Open App Battery Settings',
                    style: context.ts(
                      15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpacing20),
        ],
      ),
    );
  }
}
