import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

/// Xatırladıcı repository — artıq pairId yox, uid əsasında.
/// Kolleksiya: reminders/{uid}/items/{reminderId}
class ReminderRepository {
  final FirebaseFirestore _db;
  ReminderRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db.collection('reminders').doc(uid).collection('items');

  Stream<List<ReminderModel>> watchAll(String uid) {
    return _items(uid).orderBy('dateTime').snapshots().map((snap) =>
        snap.docs.map((d) => ReminderModel.fromMap(d.id, d.data())).toList());
  }

  Future<String> add(ReminderModel reminder) async {
    final ref = await _items(reminder.uid).add(reminder.toMap());
    return ref.id;
  }

  Future<void> delete(String uid, String id) async {
    await _items(uid).doc(id).delete();
  }
}
