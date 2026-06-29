import 'package:flutter/material.dart';

class Insight {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final String? actionRoute;
  final int priority;

  const Insight({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.actionRoute,
    this.priority = 0,
  });
}
