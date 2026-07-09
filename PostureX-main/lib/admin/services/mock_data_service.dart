import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/app_user.dart';
import '../models/plan.dart';
import '../models/notification.dart';
import '../admin_theme.dart';

class MockDataService {
  MockDataService._();
  static final MockDataService instance = MockDataService._();

  // ---- Exercises ----
  final List<Exercise> exercises = [
    Exercise(name: 'Squat', detail: 'Legs, glutes · Basic', status: ExerciseStatus.published),
    Exercise(name: 'Push-up', detail: 'Chest, arms · Basic', status: ExerciseStatus.published),
    Exercise(name: 'Plank', detail: 'Abs, core · Intermediate', status: ExerciseStatus.draft),
    Exercise(name: 'Lunge', detail: 'Legs, glutes · Intermediate', status: ExerciseStatus.published),
  ];

  // ---- Users ----
  final List<AppUser> users = [
    AppUser(
      initials: 'NM',
      name: 'Nguyen Minh',
      email: 'nguyenminh@gmail.com',
      plan: 'Premium',
      avatarBg: kBlueBg,
      avatarFg: kBlue,
      hasDetail: true,
      sessionsThisMonth: 18,
      totalReps: 2430,
      payments: const [
        PaymentRecord('Annual Premium', '02/07/2026 · Momo', '799,000₫'),
        PaymentRecord('Monthly Premium', '02/06/2026 · Momo', '99,000₫'),
      ],
    ),
    AppUser(
        initials: 'TL',
        name: 'Tran Lan',
        email: 'tranlan@gmail.com',
        plan: 'Premium',
        avatarBg: kPurpleBg,
        avatarFg: kPurple),
    AppUser(
        initials: 'PH',
        name: 'Pham Huy',
        email: 'phamhuy@gmail.com',
        plan: 'Free',
        avatarBg: kCoralBg,
        avatarFg: kCoral),
    AppUser(
        initials: 'LA',
        name: 'Le An',
        email: 'lean@gmail.com',
        plan: 'Free',
        avatarBg: const Color(0xFFFBEAF0),
        avatarFg: const Color(0xFF993556)),
  ];

  // ---- Plans ----
  final List<Plan> plans = [
    Plan(
        name: 'Free',
        detail: '0₫ · Basic Squat, Push-up',
        icon: Icons.card_giftcard,
        iconBg: kGrayBg,
        iconFg: kGrayFg),
    Plan(
        name: 'Monthly Premium',
        detail: '99,000₫ / month',
        icon: Icons.star_border,
        iconBg: kBlueBg,
        iconFg: kBlue),
    Plan(
        name: 'Annual Premium',
        detail: '799,000₫ / year',
        icon: Icons.workspace_premium_outlined,
        iconBg: kBlueBg,
        iconFg: kBlue),
  ];

  // ---- Promo codes ----
  final List<Promo> promos = [
    const Promo(code: 'HELLO30', detail: '30% off · Expires 31/07'),
    const Promo(code: 'SUMMER25', detail: '25% off · Expires 30/06', active: false),
  ];

  // ---- Sent notifications ----
  final List<AppNotification> notifications = [
    const AppNotification('July Promotion', 'Sent to all · 05/07'),
    const AppNotification('New Plank Exercise!', 'Sent to Premium · 01/07'),
  ];
}
