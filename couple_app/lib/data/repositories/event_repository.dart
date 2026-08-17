import 'package:cloud_firestore/cloud_firestore.dart';

/// Event repository — "Evdəyəm" bildirişi üçün passiv saxlanılır.
/// Yeni sistemdə admin ↔ cihaz arası event göndərmə AdminChat vasitəsilə edilir.
/// Bu fayl compile xətası olmasın deyə saxlanılıb.
class EventRepository {
  final FirebaseFirestore _db;
  EventRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<void> sendEvent({
    required String myUid,
    required String partnerUid,
    required EventType type,
    String? customMessage,
  }) async {
    // Passiv — yeni sistemdə istifadə olunmur
  }

  Stream<List<dynamic>> watchEvents({required String uid}) {
    return Stream.value(const []);
  }
}

enum EventType { arrived, leftHome, other }
