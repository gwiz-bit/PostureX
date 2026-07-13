import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../theme/app_theme.dart';
import '../models/admin_models.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _target = 'all';

  List<AdminNotification> _notifications = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  static const _audiences = {
    'all': 'All users',
    'free': 'Free users only',
    'premium': 'Premium users only',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final notifs = await ApiClient.instance.fetchAdminNotifications();
      if (!mounted) return;
      setState(() => _notifications = notifs);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      showToast(context, 'Please enter a title and content before sending');
      return;
    }
    setState(() => _isSending = true);
    try {
      await ApiClient.instance.createAdminNotification(
        title: _title.text.trim(),
        content: _content.text.trim(),
        audience: _target,
      );
      _title.clear();
      _content.clear();
      if (!mounted) return;
      showToast(context, 'Notification sent');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Notification Management', 'Broadcast to users'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
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
                  items: _audiences.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _target = v ?? 'all'),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _isSending ? 'Sending...' : 'Send notification',
                  onPressed: _isSending ? () {} : _send,
                ),
              ]),
            ),
            const SizedBox(height: 16),
            const SectionLabel('Recently sent'),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text(_errorMessage!, style: const TextStyle(color: kMuted), textAlign: TextAlign.center)),
              )
            else if (_notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No notifications sent yet', style: TextStyle(color: kMuted))),
              )
            else
              ListCard(
                rows: _notifications.map((n) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(children: [
                      const CircleAvatar(
                          radius: 17,
                          backgroundColor: kCoralBg,
                          child: Icon(Icons.notifications_none, size: 17, color: kCoral)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(n.title,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                            Text('Sent to ${_audiences[n.audience] ?? n.audience} · '
                                '${n.createdAt.day.toString().padLeft(2, '0')}/${n.createdAt.month.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: kMuted)),
                          ])),
                      const StatusBadge('Sent', kGreenBg, kGreen),
                    ]),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
