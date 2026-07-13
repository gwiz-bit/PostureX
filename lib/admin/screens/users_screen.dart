import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AdminUser> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';

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
      final users = await ApiClient.instance.fetchAdminUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDetail(AdminUser u) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(user: u)),
    );
    if (result != null && mounted) _load();
  }

  List<AdminUser> get _filtered {
    if (_query.trim().isEmpty) return _users;
    final q = _query.trim().toLowerCase();
    return _users
        .where((u) => u.displayName.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('User Management', '${_users.length} accounts'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMessage != null
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(children: [
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _load, child: const Text('Retry')),
                        ]),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        style: const TextStyle(color: kInk),
                        decoration: adminInput('Search by name, email...'),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 12),
                      SectionLabel('User list (${_filtered.length}) — tap to view details'),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No users found', style: TextStyle(color: kMuted))),
                        )
                      else
                        ListCard(
                          rows: _filtered.map((u) {
                            return InkWell(
                              onTap: () => _openDetail(u),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                child: Row(children: [
                                  CircleAvatar(
                                      radius: 17,
                                      backgroundColor: u.isAdmin ? kPurpleBg : kBlueBg,
                                      child: Text(u.initials,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: u.isAdmin ? kPurple : kBlue))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                        Text(u.displayName,
                                            style: const TextStyle(
                                                fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                                        Text(u.email, style: const TextStyle(fontSize: 11, color: kMuted)),
                                      ])),
                                  if (u.isAdmin) ...[
                                    const StatusBadge('Admin', kPurpleBg, kPurple),
                                    const SizedBox(width: 6),
                                  ],
                                  StatusBadge(u.isActive ? 'Active' : 'Disabled',
                                      u.isActive ? kGreenBg : kRedBg, u.isActive ? kGreen : kRed),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
      ),
    );
  }
}
