import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String uid;
  final double lat;
  final double lng;
  final DateTime updatedAt;

  const LocationModel({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.updatedAt,
  });

  factory LocationModel.fromMap(String uid, Map<String, dynamic> data) {
    return LocationModel(
      uid: uid,
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
