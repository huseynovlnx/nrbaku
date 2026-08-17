import 'package:cloud_firestore/cloud_firestore.dart';

enum UrgentCallStatus { pending, responded }

class UrgentCallModel {
  final String id;
  final String pairId;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String message;
  final UrgentCallStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const UrgentCallModel({
    required this.id,
    required this.pairId,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.message,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory UrgentCallModel.fromMap(String id, Map<String, dynamic> data) {
    return UrgentCallModel(
      id: id,
      pairId: data['pairId'] as String? ?? '',
      fromUid: data['fromUid'] as String? ?? '',
      fromName: data['fromName'] as String? ?? 'Partner',
      toUid: data['toUid'] as String? ?? '',
      message: data['message'] as String? ?? '',
      status: (data['status'] as String? ?? 'pending') == 'responded'
          ? UrgentCallStatus.responded
          : UrgentCallStatus.pending,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}
