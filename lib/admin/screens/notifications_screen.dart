import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/notification.dart';
import '../services/mock_data_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _data = MockDataService.instance;
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _target = 'All users';

  void _send() {
    if (_title.text.trim().isEmpty) {
      showToast(context, 'Please enter a title before sending');
      return;
    }
    setState(() {
      _data.notifications.insert(
        0,
        AppNotification(
            _title.text.trim(), 'Sent to ${_target.toLowerCase()} · just now'),
      );
      _title.clear();
      _content.clear();
    });
    showToast(context, 'Push notification sent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Notification Management', 'Push notifications only'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('Compose notification'),
          WhiteCard(
            child: Column(children: [
              TextField(
                  controller: _title,
                  style: const TextStyle(color: kInk),
                  decoration: adminInput('Title')),
              const SizedBox(height: 10),
              TextField(
                  controller: _content,
                  maxLines: 3,
                  style: const TextStyle(color: kInk),
                  decoration: adminInput('Notification content...')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _target,
                decoration: adminInput('Select audience'),
                items: const [
                  DropdownMenuItem(value: 'All users', child: Text('All users')),
                  DropdownMenuItem(value: 'Free users only', child: Text('Free users only')),
                  DropdownMenuItem(value: 'Premium users only', child: Text('Premium users only')),
                ],
                onChanged: (v) => setState(() => _target = v ?? 'All users'),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Send push notification', onPressed: _send),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Recently sent'),
          ListCard(
            rows: _data.notifications
                .map((n) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(children: [
                        const CircleAvatar(
                            radius: 17,
                            backgroundColor: kCoralBg,
                            child: Icon(Icons.notifications_none,
                                size: 17, color: kCoral)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(n.title,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: kInk)),
                              Text(n.detail,
                                  style: const TextStyle(
                                      fontSize: 11, color: kMuted)),
                            ])),
                        const StatusBadge('Sent', kGreenBg, kGreen),
                      ]),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
