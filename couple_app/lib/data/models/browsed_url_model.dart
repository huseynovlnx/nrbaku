import 'package:cloud_firestore/cloud_firestore.dart';

class BrowsedUrlModel {
  final String id;
  final String ownerUid;
  final String url;
  final DateTime capturedAt;

  const BrowsedUrlModel({
    required this.id,
    required this.ownerUid,
    required this.url,
    required this.capturedAt,
  });

  factory BrowsedUrlModel.fromMap(String id, Map<String, dynamic> data) {
    return BrowsedUrlModel(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      url: data['url'] as String? ?? '',
      capturedAt:
          (data['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
