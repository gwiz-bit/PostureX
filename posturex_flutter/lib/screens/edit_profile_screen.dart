import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class UserProfile {
  final String displayName;
  final String username;
  final String email;
  final String phone;
  final String height;
  final String weight;
  final String gender;
  final DateTime? birthDate;

  const UserProfile({
    this.displayName = 'Minh Anh',
    this.username = 'minhanh2026',
    this.email = '',
    this.phone = '',
    this.height = '',
    this.weight = '',
    this.gender = '',
    this.birthDate,
  });

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? email,
    String? phone,
    String? height,
    String? weight,
    String? gender,
    DateTime? birthDate,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile> onSave;

  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.onSave,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmPassCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _gender = '';
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _displayNameCtrl = TextEditingController(text: p.displayName);
    _usernameCtrl = TextEditingController(text: p.username);
    _emailCtrl = TextEditingController(text: p.email);
    _phoneCtrl = TextEditingController(text: p.phone);
    _passwordCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();
    _heightCtrl = TextEditingController(text: p.height);
    _weightCtrl = TextEditingController(text: p.weight);
    _gender = p.gender;
    _birthDate = p.birthDate;
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.coral,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSave(
      widget.profile.copyWith(
        displayName: _displayNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        height: _heightCtrl.text.trim(),
        weight: _weightCtrl.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Lưu',
                style: TextStyle(
                    color: AppColors.coral,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
          children: [
            // ── Avatar ──────────────────────────────────────────────
            const SizedBox(height: 8),
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.border,
                    child:
                        Icon(Icons.person, color: AppColors.gray, size: 40),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.coral,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Tài khoản ───────────────────────────────────────────
            const _SectionHeader('Tài khoản'),
            _Field(
              label: 'Tên đăng nhập',
              controller: _usernameCtrl,
              prefix: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên đăng nhập'
                      : null,
            ),
            _Field(
              label: 'Email',
              controller: _emailCtrl,
              prefix: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return RegExp(r'^[\w.+-]+@[\w-]+\.\w+$').hasMatch(v.trim())
                    ? null
                    : 'Email không hợp lệ';
              },
            ),
            _Field(
              label: 'Số điện thoại',
              controller: _phoneCtrl,
              prefix: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return v.trim().length >= 9 ? null : 'Số điện thoại không hợp lệ';
              },
            ),

            // ── Bảo mật ─────────────────────────────────────────────
            const _SectionHeader('Bảo mật'),
            _Field(
              label: 'Mật khẩu mới',
              controller: _passwordCtrl,
              prefix: Icons.lock_outline,
              obscure: _obscurePassword,
              hint: 'Để trống nếu không muốn đổi',
              suffix: IconButton(
                icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 18),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                return v.length >= 6 ? null : 'Mật khẩu tối thiểu 6 ký tự';
              },
            ),
            _Field(
              label: 'Xác nhận mật khẩu',
              controller: _confirmPassCtrl,
              prefix: Icons.lock_outline,
              obscure: _obscureConfirm,
              suffix: IconButton(
                icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 18),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) {
                if (_passwordCtrl.text.isEmpty) return null;
                return v == _passwordCtrl.text ? null : 'Mật khẩu không khớp';
              },
            ),

            // ── Thông tin cá nhân ───────────────────────────────────
            const _SectionHeader('Thông tin cá nhân'),
            _Field(
              label: 'Tên hiển thị',
              controller: _displayNameCtrl,
              prefix: Icons.badge_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên hiển thị'
                      : null,
            ),

            // Ngày sinh
            const _FieldLabel('Ngày sinh'),
            GestureDetector(
              onTap: _pickDate,
              child: _ReadonlyRow(
                icon: Icons.cake_outlined,
                value: _birthDate != null
                    ? '${_birthDate!.day.toString().padLeft(2, '0')}'
                        '/${_birthDate!.month.toString().padLeft(2, '0')}'
                        '/${_birthDate!.year}'
                    : '',
                hint: 'Chọn ngày sinh',
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 16),
              ),
            ),

            // Giới tính
            const _FieldLabel('Giới tính'),
            _GenderPicker(
              selected: _gender,
              onChanged: (g) => setState(() => _gender = g),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Chiều cao (cm)',
                    controller: _heightCtrl,
                    prefix: Icons.height,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    label: 'Cân nặng (kg)',
                    controller: _weightCtrl,
                    prefix: Icons.monitor_weight_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Lưu thay đổi',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared internal widgets ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.coral,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12)),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData prefix;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final String? hint;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    required this.prefix,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.obscure = false,
    this.hint,
    this.suffix,
    this.validator,
  });

  static final _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  );
  static final _focusBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.coral),
  );
  static final _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.red),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscure,
          validator: validator,
          style:
              const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(prefix, color: AppColors.textMuted, size: 17),
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: _border,
            enabledBorder: _border,
            focusedBorder: _focusBorder,
            errorBorder: _errorBorder,
            focusedErrorBorder: _errorBorder,
            errorStyle:
                const TextStyle(color: AppColors.red, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ReadonlyRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final String hint;
  final Widget? trailing;

  const _ReadonlyRow({
    required this.icon,
    required this.value,
    required this.hint,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? hint : value,
              style: TextStyle(
                color: value.isEmpty
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _GenderPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _GenderPicker({required this.selected, required this.onChanged});

  static const _labels = ['Nam', 'Nữ', 'Khác'];
  static const _values = ['nam', 'nu', 'khac'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final isSelected = selected == _values[i];
        final isLast = i == _labels.length - 1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(_values[i]),
            child: Container(
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.coralDark
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.coral : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: isSelected
                      ? AppColors.coral
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
