import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class UserDetailScreen extends StatefulWidget {
  final AdminUser user;
  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late AdminUser _user;
  bool _isBusy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _toggleActive() async {
    final targetActive = !_user.isActive;
    final ok = await showConfirmDialog(
      context,
      targetActive ? 'Re-enable account?' : 'Disable account?',
      targetActive
          ? '${_user.displayName} will be able to log in again.'
          : '${_user.displayName} will be blocked from logging in.',
    );
    if (!ok) return;
    await _runUpdate(() => ApiClient.instance.updateAdminUser(_user.id, isActive: targetActive));
  }

  Future<void> _toggleAdmin() async {
    final targetAdmin = !_user.isAdmin;
    final ok = await showConfirmDialog(
      context,
      targetAdmin ? 'Grant admin rights?' : 'Revoke admin rights?',
      targetAdmin
          ? '${_user.displayName} will get full admin access.'
          : '${_user.displayName} will lose admin access.',
    );
    if (!ok) return;
    await _runUpdate(() => ApiClient.instance.updateAdminUser(_user.id, isAdmin: targetAdmin));
  }

  Future<void> _runUpdate(Future<AdminUser> Function() action) async {
    setState(() => _isBusy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _user = updated;
        _changed = true;
      });
      showToast(context, 'User updated');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      'Delete this account?',
      '${_user.displayName} and all their workouts/videos will be permanently deleted. This cannot be undone.',
    );
    if (!ok) return;
    setState(() => _isBusy = true);
    try {
      await ApiClient.instance.deleteAdminUser(_user.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed ? true : null);
      },
      child: Scaffold(
        appBar: adminAppBar('User Details', 'Back to list'),
        body: AbsorbPointer(
          absorbing: _isBusy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              WhiteCard(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  CircleAvatar(
                      radius: 32,
                      backgroundColor: _user.isAdmin ? kPurpleBg : kBlueBg,
                      child: Text(_user.initials,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _user.isAdmin ? kPurple : kBlue))),
                  const SizedBox(height: 10),
                  Text(_user.displayName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kInk)),
                  Text(_user.email, style: const TextStyle(fontSize: 12, color: kMuted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    StatusBadge(_user.isActive ? 'Active' : 'Disabled',
                        _user.isActive ? kGreenBg : kRedBg, _user.isActive ? kGreen : kRed),
                    if (_user.isAdmin) const StatusBadge('Admin', kPurpleBg, kPurple),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              MetricCard(
                label: 'Joined',
                value:
                    '${_user.createdAt.day.toString().padLeft(2, '0')}/${_user.createdAt.month.toString().padLeft(2, '0')}/${_user.createdAt.year}',
              ),
              const SizedBox(height: 16),
              const SectionLabel('Manage account'),
              ListCard(rows: [
                _actionRow(
                  icon: _user.isActive ? Icons.block : Icons.check_circle_outline,
                  label: _user.isActive ? 'Disable account' : 'Re-enable account',
                  color: _user.isActive ? kRed : kGreen,
                  onTap: _toggleActive,
                ),
                _actionRow(
                  icon: _user.isAdmin ? Icons.remove_moderator_outlined : Icons.admin_panel_settings_outlined,
                  label: _user.isAdmin ? 'Revoke admin rights' : 'Grant admin rights',
                  color: kPurple,
                  onTap: _toggleAdmin,
                ),
                _actionRow(
                  icon: Icons.delete_outline,
                  label: 'Delete account',
                  color: kRed,
                  onTap: _delete,
                ),
              ]),
              const SizedBox(height: 18),
              GhostButton(label: 'Back to list', onPressed: () => Navigator.pop(context, _changed ? true : null)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
          const Icon(Icons.chevron_right_rounded, size: 18, color: kMuted),
        ]),
      ),
    );
  }
}
