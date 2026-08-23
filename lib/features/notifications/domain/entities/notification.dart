/// A notification in the app, returned from `GET /api/v1/notifications`.
///
/// Named `AppNotification` rather than `Notification` because Flutter
/// already has a `Notification` class (the widget notification tree) —
/// colliding names would force a prefixed import everywhere this is used.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.type,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String? body;
  final String? type;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String?,
      type: json['type'] as String?,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
