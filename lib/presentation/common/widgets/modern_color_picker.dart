import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';

const List<String> presetColors = [
  '#FF453A', // Ruby Red
  '#FF9F0A', // Orange Amber
  '#FFD60A', // Gold Yellow
  '#30D158', // Emerald Green
  '#0A84FF', // Sapphire Blue
  '#BF5AF2', // Purple Violet
  '#64D2FF', // Turquoise Cyan
  '#E91E63', // Pink
  '#008080', // Teal
  '#9C27B0', // Magenta
  '#673AB7', // Indigo
  '#4CAF50', // Mint Green
  '#795548', // Brown
  '#607D8B', // Slate
  '#8E8E93', // Cool Grey
  '#FF5E7E', // Coral Pink
  '#FFB900', // Ochre
  '#00C6FF', // Light Blue
];

String colorToHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

class ModernColorPicker extends StatefulWidget {
  final String selectedColorHex;
  final ValueChanged<String> onColorChanged;

  const ModernColorPicker({
    super.key,
    required this.selectedColorHex,
    required this.onColorChanged,
  });

  @override
  State<ModernColorPicker> createState() => _ModernColorPickerState();
}

class _ModernColorPickerState extends State<ModernColorPicker> {
  bool _showCustom = false;
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: widget.selectedColorHex);
    _parseCurrentColor();
    // If current color is not in presets, auto-open custom picker
    if (!presetColors.contains(widget.selectedColorHex.toUpperCase())) {
      _showCustom = true;
    }
  }

  @override
  void didUpdateWidget(covariant ModernColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColorHex != widget.selectedColorHex) {
      if (_hexController.text.toUpperCase() !=
          widget.selectedColorHex.toUpperCase()) {
        _hexController.text = widget.selectedColorHex;
      }
      _parseCurrentColor();
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _parseCurrentColor() {
    final color = hexToColor(widget.selectedColorHex);
    final hsv = HSVColor.fromColor(color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  void _updateFromHSV() {
    final color = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    final hex = colorToHex(color);
    if (_hexController.text.toUpperCase() != hex.toUpperCase()) {
      _hexController.text = hex;
    }
    widget.onColorChanged(hex);
  }

  void _updateFromHex(String hex) {
    if (hex.startsWith('#') && hex.length == 7) {
      final color = hexToColor(hex);
      final hsv = HSVColor.fromColor(color);
      setState(() {
        _hue = hsv.hue;
        _saturation = hsv.saturation;
        _value = hsv.value;
      });
      widget.onColorChanged(hex.toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelectedCustom = !presetColors.contains(
      widget.selectedColorHex.toUpperCase(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Grid of presets
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: [
            ...presetColors.map((hex) {
              final color = hexToColor(hex);
              final isSelected =
                  widget.selectedColorHex.toUpperCase() == hex.toUpperCase();
              return TactileSpringContainer(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onColorChanged(hex);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? (theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          PesaFlowIcons.check,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              );
            }),

            // Custom color button
            TactileSpringContainer(
              onTap: () {
                setState(() {
                  _showCustom = !_showCustom;
                });
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelectedCustom
                      ? hexToColor(widget.selectedColorHex)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelectedCustom
                        ? (theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black)
                        : theme.colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    PesaFlowIcons.palette,
                    color: isSelectedCustom
                        ? Colors.white
                        : context.appColors.textMedium,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Animated custom picker panel
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: kSpacing20),
            child: Container(
              padding: const EdgeInsets.all(kSpacing16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppTheme.surfaceContainerDark
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hexToColor(widget.selectedColorHex),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpacing12),
                      Expanded(
                        child: TextField(
                          controller: _hexController,
                          maxLength: 7,
                          onChanged: _updateFromHex,
                          textCapitalization: TextCapitalization.characters,
                          style: context.ts(14, fontWeight: FontWeight.bold),
                          decoration: context
                              .inputDecoration(
                                labelText: 'Hex Code',
                                hintText: '#HEXCODE',
                              )
                              .copyWith(counterText: ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing16),

                  // HUE Slider
                  Text(
                    'Hue',
                    style: context.ts(12, color: context.appColors.textMedium),
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 12,
                      trackShape: const RoundedRectSliderTrackShape(),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                    ),
                    child: Container(
                      height: 12,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.red,
                            Colors.yellow,
                            Colors.green,
                            Colors.cyan,
                            Colors.blue,
                            Colors.purple,
                            Colors.red,
                          ],
                        ),
                      ),
                      child: Slider(
                        value: _hue,
                        min: 0.0,
                        max: 360.0,
                        onChanged: (val) {
                          setState(() {
                            _hue = val;
                          });
                          _updateFromHSV();
                        },
                      ),
                    ),
                  ),

                  // SATURATION Slider
                  const SizedBox(height: kSpacing8),
                  Text(
                    'Saturation',
                    style: context.ts(12, color: context.appColors.textMedium),
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 12,
                      trackShape: const RoundedRectSliderTrackShape(),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                    ),
                    child: Container(
                      height: 12,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                          ],
                        ),
                      ),
                      child: Slider(
                        value: _saturation,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          setState(() {
                            _saturation = val;
                          });
                          _updateFromHSV();
                        },
                      ),
                    ),
                  ),

                  // LIGHTNESS Slider
                  const SizedBox(height: kSpacing8),
                  Text(
                    'Brightness',
                    style: context.ts(12, color: context.appColors.textMedium),
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 12,
                      trackShape: const RoundedRectSliderTrackShape(),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                    ),
                    child: Container(
                      height: 12,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black,
                            HSVColor.fromAHSV(
                              1.0,
                              _hue,
                              _saturation,
                              1.0,
                            ).toColor(),
                          ],
                        ),
                      ),
                      child: Slider(
                        value: _value,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          setState(() {
                            _value = val;
                          });
                          _updateFromHSV();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          crossFadeState: _showCustom
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
