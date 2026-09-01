class AppNotification {
  final String id;
  final String title;
  final String description;
  final String dateLabel;
  final String type;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.dateLabel,
    required this.type,
    this.isRead = false,
  });
}
