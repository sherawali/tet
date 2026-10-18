class FlashMessage {
  final String id;
  final String title;
  final String message;
  final String type; // 'notice', 'alert', 'exam', 'update'
  final String? actionLabel;
  final String? actionUrl;
  final bool isDismissible;

  const FlashMessage({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'notice',
    this.actionLabel,
    this.actionUrl,
    this.isDismissible = true,
  });

  factory FlashMessage.fromJson(Map<String, dynamic> json) {
    return FlashMessage(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['subtitle']?.toString() ?? '',
      type: json['type']?.toString() ?? 'notice',
      actionLabel: json['action_label']?.toString() ?? json['actionLabel']?.toString(),
      actionUrl: json['action_url']?.toString() ?? json['actionUrl']?.toString(),
      isDismissible: json['dismissible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type,
    if (actionLabel != null) 'action_label': actionLabel,
    if (actionUrl != null) 'action_url': actionUrl,
    'dismissible': isDismissible,
  };
}
