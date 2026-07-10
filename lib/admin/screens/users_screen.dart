import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/app_user.dart';
import '../services/mock_data_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _data = MockDataService.instance;

  Future<void> _openDetail(AppUser u) async {
    if (!u.hasDetail) {
      showToast(context, 'Demo: only Nguyen Minh has a detail screen');
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => UserDetailScreen(user: u)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final users = _data.users;
    return Scaffold(
      appBar: adminAppBar('User Management', '1,284 accounts'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              style: const TextStyle(color: kInk),
              decoration: adminInput('Search by name, email...')),
          const SizedBox(height: 12),
          const SectionLabel('User list — tap to view details'),
          ListCard(
            rows: users.map((u) {
              final premium = u.plan == 'Premium';
              return InkWell(
                onTap: () => _openDetail(u),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 17,
                        backgroundColor: u.avatarBg,
                        child: Text(u.initials,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: u.avatarFg))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(u.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: kInk)),
                          Text(u.email,
                              style: const TextStyle(
                                  fontSize: 11, color: kMuted)),
                        ])),
                    StatusBadge(u.plan, premium ? kBlueBg : kGrayBg,
                        premium ? kBlue : kGrayFg),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
