import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = const UserProfile();
  final String _joinDate = 'tháng 3, 2026';

  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: _profile,
          onSave: (updated) => setState(() => _profile = updated),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.border,
                child: Icon(Icons.person, color: AppColors.gray, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile.displayName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    if (_profile.email.isNotEmpty)
                      Text(
                        _profile.email,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      )
                    else
                      Text(
                        'Thành viên từ $_joinDate',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openEdit,
                child: const Icon(Icons.edit_outlined,
                    color: AppColors.textSecondary, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SettingTile(
              icon: Icons.notifications_outlined, label: 'Thông báo'),
          const _SettingTile(
              icon: Icons.straighten,
              label: 'Đơn vị đo',
              trailingText: 'Mét'),
          const _SettingTile(
              icon: Icons.camera_alt_outlined,
              label: 'Quyền truy cập camera'),
          const _SettingTile(icon: Icons.help_outline, label: 'Trợ giúp'),
          const _SettingTile(
              icon: Icons.logout,
              label: 'Đăng xuất',
              danger: true,
              showChevron: false),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingText;
  final bool danger;
  final bool showChevron;

  const _SettingTile({
    required this.icon,
    required this.label,
    this.trailingText,
    this.danger = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = danger ? AppColors.red : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Icon(icon,
              color: danger ? AppColors.red : AppColors.textSecondary,
              size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: labelColor, fontSize: 14))),
          if (trailingText != null)
            Text(trailingText!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          if (showChevron && trailingText == null)
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 16),
        ],
      ),
    );
  }
}
