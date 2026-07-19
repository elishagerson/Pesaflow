import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';

class CalculatorNumpad extends StatefulWidget {
  final String initialValue;
  final Function(String) onValueChanged;
  final VoidCallback onConfirm;

  const CalculatorNumpad({
    super.key,
    required this.initialValue,
    required this.onValueChanged,
    required this.onConfirm,
  });

  @override
  State<CalculatorNumpad> createState() => _CalculatorNumpadState();
}

class _CalculatorNumpadState extends State<CalculatorNumpad> {
  late String _expr;

  @override
  void initState() {
    super.initState();
    _expr = widget.initialValue == '0' ? '' : widget.initialValue;
  }

  void _onKeyPress(String key) {
    triggerHaptic(HapticType.impact);
    setState(() {
      if (key == 'C') {
        _expr = '';
      } else if (key == '⌫') {
        if (_expr.isNotEmpty) {
          _expr = _expr.substring(0, _expr.length - 1);
        }
      } else if (key == '=') {
        _evaluate();
      } else {
        // Prevent duplicate operators
        final operators = ['+', '-', '*', '/'];
        if (operators.contains(key)) {
          if (_expr.isEmpty) return;
          final lastChar = _expr.substring(_expr.length - 1);
          if (operators.contains(lastChar)) {
            _expr = _expr.substring(0, _expr.length - 1) + key;
            return;
          }
        }
        // Limit total length to prevent overflow
        if (_expr.length < 24) {
          _expr += key;
        }
      }
    });

    _updateParentValue();
  }

  void _updateParentValue() {
    final displayVal = _expr.isEmpty ? '0' : _expr;
    widget.onValueChanged(displayVal);
  }

  void _evaluate() {
    if (_expr.isEmpty) return;
    try {
      final result = _parseAndEval(_expr);
      if (result != null) {
        // Format to remove trailing .0 if integer
        _expr = result % 1 == 0 ? result.toInt().toString() : result.toStringAsFixed(2);
      }
    } catch (_) {
      // Invalid expression, do nothing
    }
  }

  double? _parseAndEval(String expression) {
    // A simple parser for math expressions containing +, -, *, /
    final normalized = expression.replaceAll(' ', '');
    try {
      return _parseAdditionSubtraction(normalized);
    } catch (_) {
      return null;
    }
  }

  double _parseAdditionSubtraction(String expr) {
    // Find the last occurrence of + or - not inside any priority (if we had parentheses)
    int opIndex = -1;
    String currentOp = '';
    
    // Find + or - from right to left to maintain left-to-right evaluation order
    for (int i = expr.length - 1; i >= 0; i--) {
      final char = expr[i];
      if (char == '+' || char == '-') {
        opIndex = i;
        currentOp = char;
        break;
      }
    }

    if (opIndex != -1) {
      final left = _parseAdditionSubtraction(expr.substring(0, opIndex));
      final right = _parseMultiplicationDivision(expr.substring(opIndex + 1));
      if (currentOp == '+') return left + right;
      if (currentOp == '-') return left - right;
    }

    return _parseMultiplicationDivision(expr);
  }

  double _parseMultiplicationDivision(String expr) {
    int opIndex = -1;
    String currentOp = '';

    for (int i = expr.length - 1; i >= 0; i--) {
      final char = expr[i];
      if (char == '*' || char == '/') {
        opIndex = i;
        currentOp = char;
        break;
      }
    }

    if (opIndex != -1) {
      final left = _parseMultiplicationDivision(expr.substring(0, opIndex));
      final right = double.parse(expr.substring(opIndex + 1));
      if (currentOp == '*') return left * right;
      if (currentOp == '/') {
        if (right == 0) throw Exception('Division by zero');
        return left / right;
      }
    }

    return double.parse(expr);
  }

  Widget _buildButton({
    required String text,
    Color? bgColor,
    Color? textColor,
    bool isPrimary = false,
    IconData? icon,
    int flex = 1,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsTheme>()!;
    
    final finalBg = bgColor ?? (isPrimary 
        ? theme.colorScheme.primary 
        : theme.colorScheme.surfaceContainerHigh);

    final finalTextColor = textColor ?? (isPrimary
        ? Colors.white
        : theme.colorScheme.onSurface);

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: TactileSpringContainer(
          onTap: () => icon != null && text == '⌫' 
              ? _onKeyPress('⌫') 
              : _onKeyPress(text),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: finalBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: icon != null 
                ? Icon(icon, color: finalTextColor, size: 20)
                : Text(
                    text,
                    style: context.ts(
                      18,
                      fontWeight: FontWeight.bold,
                      color: finalTextColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsTheme>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpacing8, vertical: kSpacing4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live arithmetic evaluation view
          if (_expr.contains(RegExp(r'[\+\-\*\/]')))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                'Expr: $_expr',
                style: context.ts(
                  12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Row(
            children: [
              _buildButton(text: 'C', textColor: appColors.expenseColor),
              _buildButton(text: '('), // Placeholder or paren
              _buildButton(text: ')'), // Paren
              _buildButton(text: '/', bgColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4), textColor: theme.colorScheme.primary),
            ],
          ),
          Row(
            children: [
              _buildButton(text: '7'),
              _buildButton(text: '8'),
              _buildButton(text: '9'),
              _buildButton(text: '*', bgColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4), textColor: theme.colorScheme.primary),
            ],
          ),
          Row(
            children: [
              _buildButton(text: '4'),
              _buildButton(text: '5'),
              _buildButton(text: '6'),
              _buildButton(text: '-', bgColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4), textColor: theme.colorScheme.primary),
            ],
          ),
          Row(
            children: [
              _buildButton(text: '1'),
              _buildButton(text: '2'),
              _buildButton(text: '3'),
              _buildButton(text: '+', bgColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4), textColor: theme.colorScheme.primary),
            ],
          ),
          Row(
            children: [
              _buildButton(text: '.'),
              _buildButton(text: '0'),
              _buildButton(text: '⌫', icon: PesaFlowIcons.backspace),
              _buildButton(text: '=', isPrimary: true),
            ],
          ),
        ],
      ),
    );
  }
}
