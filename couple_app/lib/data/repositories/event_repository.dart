import 'package:cloud_firestore/cloud_firestore.dart';

/// Event repository — "Evdəyəm" bildirişi üçün passiv saxlanılır.
/// Yeni sistemdə admin ↔ cihaz arası event göndərmə AdminChat vasitəsilə edilir.
/// Bu fayl compile xətası olmasın deyə saxlanılıb.
///
/// QEYD: EventType enum-u event_model.dart-dakı ilə eyni adlıdır.
/// Hər iki faylı eyni vaxtda import etmək ambiguity xətasına səbəb ola bilər.
/// Bu fayl yalnız backward compatibility üçün saxlanılıb.
class EventRepository {
  final FirebaseFirestore _db;
  EventRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<void> sendEvent({
    required String myUid,
    required String partnerUid,
    required EventRepoType type,
    String? customMessage,
  }) async {
    // Passiv — yeni sistemdə istifadə olunmur
  }

  Stream<List<Map<String, dynamic>>> watchEvents({required String uid}) {
    return Stream.value(const []);
  }
}

/// EventRepository üçün xüsusi enum.
/// event_model.dart-dakı EventType ilə ad conflict olmaması üçün
/// fərqli adlandırılmışdır.
enum EventRepoType { arrived, leftHome, other }
