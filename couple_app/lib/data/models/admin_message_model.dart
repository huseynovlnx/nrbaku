import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin ↔ Cihaz arasındakı mesaj modeli.
/// Kolleksiya: adminChats/{deviceUid}/messages/{msgId}
class AdminMessage {
  final String id;
  final String text;
  final String senderUid;  // admin uid və ya cihaz uid
  final bool isFromAdmin;
  final DateTime timestamp;
  final bool isRead;

  const AdminMessage({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.isFromAdmin,
    required this.timestamp,
    this.isRead = false,
  });

  factory AdminMessage.fromMap(String id, Map<String, dynamic> data) {
    return AdminMessage(
      id: id,
      text: data['text'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      isFromAdmin: data['isFromAdmin'] as bool? ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'senderUid': senderUid,
        'isFromAdmin': isFromAdmin,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': isRead,
      };
}
