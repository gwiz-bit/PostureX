import 'package:flutter/material.dart';

class Plan {
  final String name;
  final String detail;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  bool selling;

  Plan({
    required this.name,
    required this.detail,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    this.selling = true,
  });
}

class Promo {
  final String code;
  final String detail;
  final bool active;

  const Promo({
    required this.code,
    required this.detail,
    this.active = true,
  });
}
