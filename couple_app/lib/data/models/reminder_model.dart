import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String id;
  final String uid;
  final String title;
  final DateTime dateTime;
  final bool isRecurringYearly;
  final String createdBy;
  final DateTime createdAt;

  const ReminderModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.dateTime,
    required this.isRecurringYearly,
    required this.createdBy,
    required this.createdAt,
  });

  factory ReminderModel.fromMap(String id, Map<String, dynamic> data) {
    return ReminderModel(
      id: id,
      uid: data['uid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRecurringYearly: data['isRecurringYearly'] as bool? ?? false,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'title': title,
        'dateTime': Timestamp.fromDate(dateTime),
        'isRecurringYearly': isRecurringYearly,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

  DateTime? nextOccurrence() {
    if (!isRecurringYearly) {
      return dateTime.isAfter(DateTime.now()) ? dateTime : null;
    }
    final now = DateTime.now();
    var next = DateTime(
      now.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );

    if (next.month != dateTime.month) {
      next = DateTime(
        now.year,
        dateTime.month,
        1,
        dateTime.hour,
        dateTime.minute,
      ).add(Duration(days: dateTime.day - 1));
    }

    if (next.isBefore(now)) {
      next = DateTime(
        now.year + 1,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
      );
      if (next.month != dateTime.month) {
        next = DateTime(
          now.year + 1,
          dateTime.month,
          1,
          dateTime.hour,
          dateTime.minute,
        ).add(Duration(days: dateTime.day - 1));
      }
    }
    return next;
  }
}
