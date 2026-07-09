import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/app_user.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class UserDetailScreen extends StatelessWidget {
  final AppUser user;
  const UserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('User Details', 'Back to list'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WhiteCard(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              CircleAvatar(
                  radius: 32,
                  backgroundColor: user.avatarBg,
                  child: Text(user.initials,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: user.avatarFg))),
              const SizedBox(height: 10),
              Text(user.name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kInk)),
              Text(user.email,
                  style: const TextStyle(fontSize: 12, color: kMuted)),
              const SizedBox(height: 8),
              StatusBadge('Annual Premium · Active', kBlueBg, kBlue),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: MetricCard(
                    label: 'Sessions this month',
                    value: '${user.sessionsThisMonth}')),
            const SizedBox(width: 12),
            Expanded(
                child: MetricCard(
                    label: 'Total reps', value: '${user.totalReps}')),
          ]),
          const SizedBox(height: 16),
          const SectionLabel('Payment history'),
          ListCard(
            rows: user.payments
                .map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(p.plan,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: kInk)),
                              Text(p.dateMethod,
                                  style: const TextStyle(
                                      fontSize: 11, color: kMuted)),
                            ])),
                        Text(p.amount,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kInk)),
                      ]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          GhostButton(
              label: 'Back to list',
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
