import 'package:flutter/material.dart';

class Transaction {
  final String initials;
  final Color avatarBg;
  final Color avatarFg;
  final String name;
  final String plan;
  final String amount;
  final String status;
  const Transaction({
    required this.initials,
    required this.avatarBg,
    required this.avatarFg,
    required this.name,
    required this.plan,
    required this.amount,
    required this.status,
  });
}

class AppNotification {
  final String title;
  final String detail;
  const AppNotification(this.title, this.detail);
}
