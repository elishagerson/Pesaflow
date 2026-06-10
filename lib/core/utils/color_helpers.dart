import 'package:flutter/material.dart';

Color hexToColor(String hex) {
  final clean = hex.replaceAll('#', '');
  if (clean.length == 6) {
    return Color(int.parse('FF$clean', radix: 16));
  }
  return Colors.grey;
}
