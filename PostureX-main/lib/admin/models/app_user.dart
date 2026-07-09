import 'package:flutter/material.dart';

class PaymentRecord {
  final String plan;
  final String dateMethod;
  final String amount;
  const PaymentRecord(this.plan, this.dateMethod, this.amount);
}

class AppUser {
  final String initials;
  final String name;
  final String email;
  final String plan; // 'Premium' | 'Free'
  final Color avatarBg;
  final Color avatarFg;
  final bool hasDetail;
  final int sessionsThisMonth;
  final int totalReps;
  final List<PaymentRecord> payments;

  AppUser({
    required this.initials,
    required this.name,
    required this.email,
    required this.plan,
    required this.avatarBg,
    required this.avatarFg,
    this.hasDetail = false,
    this.sessionsThisMonth = 0,
    this.totalReps = 0,
    this.payments = const [],
  });
}
