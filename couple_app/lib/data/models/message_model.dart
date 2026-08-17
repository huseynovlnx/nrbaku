import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sent, delivered, read }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final MessageStatus status;
  final String? reaction;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderId;
  final bool isDeleted;
  final DateTime? editedAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.status,
    this.reaction,
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
    this.isDeleted = false,
    this.editedAt,
  });

  bool get isRead => status == MessageStatus.read;
  bool get isDelivered =>
      status == MessageStatus.delivered || status == MessageStatus.read;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(data['status'] as String?),
      reaction: data['reaction'] as String?,
      replyToId: data['replyToId'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToSenderId: data['replyToSenderId'] as String?,
      isDeleted: data['isDeleted'] as bool? ?? false,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  static MessageStatus _parseStatus(String? v) {
    switch (v) {
      case 'read':
        return MessageStatus.read;
      case 'delivered':
        return MessageStatus.delivered;
      default:
        return MessageStatus.sent;
    }
  }

  String get statusString => status.name;

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'sent',
        'reaction': reaction,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'replyToSenderId': replyToSenderId,
        'isDeleted': false,
      };
}
