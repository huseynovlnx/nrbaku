import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { sos, arrived, ping }

class CoupleEvent {
  final String id;
  final String pairId;
  final String fromUid;
  final EventType type;
  final double? lat;
  final double? lng;
  final String message;
  final bool read;
  final DateTime timestamp;

  const CoupleEvent({
    required this.id,
    required this.pairId,
    required this.fromUid,
    required this.type,
    required this.message,
    required this.read,
    required this.timestamp,
    this.lat,
    this.lng,
  });

  factory CoupleEvent.fromMap(String id, Map<String, dynamic> data) {
    return CoupleEvent(
      id: id,
      pairId: data['pairId'] as String,
      fromUid: data['fromUid'] as String,
      type: _parseType(data['type'] as String?),
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      message: data['message'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static EventType _parseType(String? v) {
    switch (v) {
      case 'sos': return EventType.sos;
      case 'arrived': return EventType.arrived;
      default: return EventType.ping;
    }
  }

  String get typeString {
    switch (type) {
      case EventType.sos: return 'sos';
      case EventType.arrived: return 'arrived';
      case EventType.ping: return 'ping';
    }
  }

  Map<String, dynamic> toMap() => {
        'pairId': pairId,
        'fromUid': fromUid,
        'type': typeString,
        'lat': lat,
        'lng': lng,
        'message': message,
        'read': read,
        'timestamp': FieldValue.serverTimestamp(),
      };
}
