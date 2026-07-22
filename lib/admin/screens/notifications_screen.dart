import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../theme/app_theme.dart';
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
  final _body = TextEditingController();
  List<BroadcastHistoryItem> _history = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final history = await ApiClient.instance.fetchBroadcastHistory();
      if (!mounted) return;
      setState(() => _history = history);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showToast(context, 'Title is required.');
      return;
    }
    final ok = await showConfirmDialog(
      context,
      'Send to all active users?',
      'This pushes "$title" to every active account right now — it can\'t be undone.',
    );
    if (!ok) return;

    setState(() => _isSending = true);
    try {
      final recipients = await ApiClient.instance.sendBroadcast(
        title: title,
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
      );
      if (!mounted) return;
      _title.clear();
      _body.clear();
      showToast(context, 'Sent to $recipients user(s)');
      _load();
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
      appBar: adminAppBar('Broadcast Notifications', 'Push a message to every user'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                    controller: _title,
                    style: const TextStyle(color: kInk),
                    decoration: adminInput('Title (required)')),
                const SizedBox(height: 10),
                TextField(
                    controller: _body,
                    maxLines: 3,
                    style: const TextStyle(color: kInk),
                    decoration: adminInput('Message (optional)')),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _isSending ? 'Sending...' : 'Send to all active users',
                  onPressed: _isSending ? () {} : _send,
                ),
              ]),
            ),
            const SizedBox(height: 20),
            const SectionLabel('History'),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_errorMessage!, style: const TextStyle(color: kMuted)),
              )
            else if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No broadcasts sent yet.', style: TextStyle(color: kMuted)),
              )
            else
              ListCard(
                rows: _history.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(children: [
                      const CircleAvatar(
                          radius: 17,
                          backgroundColor: kBlueBg,
                          child: Icon(Icons.campaign_outlined, size: 17, color: kBlue)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                              if (item.body != null && item.body!.isNotEmpty)
                                Text(item.body!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: kMuted)),
                            ]),
                      ),
                      Text('${item.recipients} sent',
                          style: const TextStyle(fontSize: 11, color: kMuted)),
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
