class BroadcastHistoryItem {
  const BroadcastHistoryItem({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.recipients,
  });

  final String title;
  final String? body;
  final DateTime createdAt;
  final int recipients;

  factory BroadcastHistoryItem.fromJson(Map<String, dynamic> json) => BroadcastHistoryItem(
        title: json['title'] as String,
        body: json['body'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        recipients: json['recipients'] as int,
      );
}
