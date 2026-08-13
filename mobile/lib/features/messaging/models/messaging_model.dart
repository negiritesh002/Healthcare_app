class ConversationModel {
  final String id;
  final String otherDoctorId;
  final String otherDoctorName;
  final String otherDoctorSpecialty;
  final String? lastMessageContent;
  final DateTime? lastMessageSentAt;

  ConversationModel({
    required this.id,
    required this.otherDoctorId,
    required this.otherDoctorName,
    required this.otherDoctorSpecialty,
    this.lastMessageContent,
    this.lastMessageSentAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      otherDoctorId: json['other_doctor_id'] as String,
      otherDoctorName: json['other_doctor_name'] as String,
      otherDoctorSpecialty: json['other_doctor_specialty'] as String,
      lastMessageContent: json['last_message_content'] as String?,
      lastMessageSentAt: json['last_message_sent_at'] != null
          ? DateTime.parse(json['last_message_sent_at'] as String)
          : null,
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime sentAt;
  final DateTime? readAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.sentAt,
    this.readAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
    );
  }
}
