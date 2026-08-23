class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.isAdmin,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String? fullName;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;

  String get displayName => (fullName?.trim().isNotEmpty ?? false) ? fullName! : email;

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        isActive: json['is_active'] as bool,
        isAdmin: json['is_admin'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
