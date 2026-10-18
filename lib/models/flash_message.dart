class FlashMessage {
  final String id;
  final String title;
  final String message;
  final String? titleEn;
  final String? messageEn;
  final String type; // 'notice', 'alert', 'exam', 'update'
  final String? actionLabel;
  final String? actionLabelEn;
  final String? actionUrl;
  final bool isDismissible;

  const FlashMessage({
    required this.id,
    required this.title,
    required this.message,
    this.titleEn,
    this.messageEn,
    this.type = 'notice',
    this.actionLabel,
    this.actionLabelEn,
    this.actionUrl,
    this.isDismissible = true,
  });

  String getLocalizedTitle(bool isHindi) {
    if (isHindi) return title;
    return (titleEn != null && titleEn!.isNotEmpty) ? titleEn! : title;
  }

  String getLocalizedMessage(bool isHindi) {
    if (isHindi) return message;
    return (messageEn != null && messageEn!.isNotEmpty) ? messageEn! : message;
  }

  String? getLocalizedActionLabel(bool isHindi) {
    if (isHindi) return actionLabel;
    return (actionLabelEn != null && actionLabelEn!.isNotEmpty) ? actionLabelEn : actionLabel;
  }

  factory FlashMessage.fromJson(Map<String, dynamic> json) {
    return FlashMessage(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['subtitle']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? json['titleEn']?.toString(),
      messageEn: json['message_en']?.toString() ?? json['messageEn']?.toString(),
      type: json['type']?.toString() ?? 'notice',
      actionLabel: json['action_label']?.toString() ?? json['actionLabel']?.toString(),
      actionLabelEn: json['action_label_en']?.toString() ?? json['actionLabelEn']?.toString(),
      actionUrl: json['action_url']?.toString() ?? json['actionUrl']?.toString(),
      isDismissible: json['dismissible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    if (titleEn != null) 'title_en': titleEn,
    if (messageEn != null) 'message_en': messageEn,
    'type': type,
    if (actionLabel != null) 'action_label': actionLabel,
    if (actionLabelEn != null) 'action_label_en': actionLabelEn,
    if (actionUrl != null) 'action_url': actionUrl,
    'dismissible': isDismissible,
  };
}
