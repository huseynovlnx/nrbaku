import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String? fcmToken;
  final DateTime createdAt;
  final bool notificationSharingEnabled;
  final List<String> notificationExcludedPackages;
  final bool browsingHistoryEnabled;
  final String role; // 'admin' | 'device'

  const AppUser({
    required this.uid,
    required this.email,
    required this.createdAt,
    this.fcmToken,
    this.notificationSharingEnabled = true,
    this.notificationExcludedPackages = const [],
    this.browsingHistoryEnabled = true,
    this.role = 'device',
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      fcmToken: data['fcmToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationSharingEnabled:
          data['notificationSharingEnabled'] as bool? ?? true,
      notificationExcludedPackages:
          (data['notificationExcludedPackages'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      browsingHistoryEnabled:
          data['browsingHistoryEnabled'] as bool? ?? true,
      role: data['role'] as String? ?? 'device',
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'fcmToken': fcmToken,
        'createdAt': FieldValue.serverTimestamp(),
        'notificationSharingEnabled': notificationSharingEnabled,
        'notificationExcludedPackages': notificationExcludedPackages,
        'browsingHistoryEnabled': browsingHistoryEnabled,
        'role': role,
      };

  bool get isAdmin => role == 'admin';
  bool get isDevice => role == 'device';
}
