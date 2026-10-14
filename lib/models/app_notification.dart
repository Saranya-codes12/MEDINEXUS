class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id, required this.type, required this.title,
    required this.message, required this.isRead, required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'], type: map['type'], title: map['title'], message: map['message'],
    isRead: map['is_read'] ?? false, createdAt: DateTime.parse(map['created_at']),
  );
}
