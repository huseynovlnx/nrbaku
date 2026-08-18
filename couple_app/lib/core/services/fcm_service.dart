import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../firebase_options.dart';

final ValueNotifier<Map<String, dynamic>?> pendingNotificationPayload =
    ValueNotifier(null);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await FcmService._handleIncomingMessage(message);
}

@pragma('vm:entry-point')
void notificationTapForeground(NotificationResponse response) {
  FcmService._handleNotificationResponse(response);
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  FcmService._handleNotificationResponse(response, isBackgroundIsolate: true);
}

class FcmService {
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;
  static bool _initialized = false;
  static String? _lastUid;
  static StreamSubscription? _tokenRefreshSub;

  static const _channelId = 'nrbaku_main';
  static const _channelName = 'NrBaku Bildirişləri';
  static const _reminderChannelId = 'nrbaku_reminders';
  static const _reminderChannelName = 'Xatırladıcılar';
  static const _urgentChannelId = 'nrbaku_urgent';
  static const _urgentChannelName = 'Təcili Çağırış';

  static void initializeTimezone() {
    tzdata.initializeTimeZones();
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inHours;
    final sign = hours <= 0 ? '+' : '-';
    final locationName = 'Etc/GMT' + sign + '${hours.abs()}';
    try {
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static Future<void> _createChannels() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Mesaj və bildiriş kanalı',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const reminderChannel = AndroidNotificationChannel(
      _reminderChannelId,
      _reminderChannelName,
      description: 'Plan, To-Do və xüsusi gün xatırladıcıları',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const urgentChannel = AndroidNotificationChannel(
      _urgentChannelId,
      _urgentChannelName,
      description: 'Admindən təcili diqqət tələb edən çağırışlar',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('urgent_alarm'),
      enableVibration: true,
    );

    final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(reminderChannel);
    await androidPlugin?.createNotificationChannel(urgentChannel);
  }

  static Future<void> _initLocalNotifPlugin() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: notificationTapForeground,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await _createChannels();
  }

  static Future<void> init(String uid) async {
    if (_initialized && _lastUid == uid) {
      await _saveToken(uid);
      return;
    }
    _initialized = true;
    _lastUid = uid;

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _initLocalNotifPlugin();
    initializeTimezone();

    final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}

    FirebaseMessaging.onMessage.listen(_handleIncomingMessage);

    final initialMsg = await _fcm.getInitialMessage();
    if (initialMsg != null) _routeFromData(initialMsg.data);

    FirebaseMessaging.onMessageOpenedApp.listen((m) => _routeFromData(m.data));

    await _saveToken(uid);
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _fcm.onTokenRefresh.listen((t) => _updateToken(uid, t));
  }

  static Future<void> reset() async {
    _initialized = false;
    _lastUid = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  static Future<void> _handleIncomingMessage(RemoteMessage message) async {
    final data = message.data;

    if (data['type'] == 'urgent_call') {
      await _createChannels();
      await showUrgentCallNotification(
        callId: data['callId'] ?? '',
        deviceUid: data['deviceUid'] ?? '',
        fromUid: data['fromUid'] ?? '',
        fromName: data['fromName'] ?? 'Admin',
        message: data['message'] ?? '',
      );
      return;
    }

    if (data['type'] == 'urgent_call_responded') {
      await _createChannels();
      await showNotification(
        title: '✓ Cavab verdi',
        body: "${data['fromName'] ?? 'Cihaz'} çağırışına cavab verdi",
      );
      return;
    }

    if (data['type'] == 'admin_chat') {
      await _createChannels();
      await showNotification(
        title: data['title'] ?? 'NrBaku',
        body: data['body'] ?? 'Yeni mesaj',
      );
      return;
    }

    final n = message.notification;
    if (n != null) {
      await showNotification(title: n.title ?? '', body: n.body ?? '');
    }
  }

  static Future<void> _handleNotificationResponse(
    NotificationResponse response, {
    bool isBackgroundIsolate = false,
  }) async {
    if (isBackgroundIsolate && Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.isEmpty) return;
    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(payloadStr) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (data['type'] == 'urgent_call' &&
        response.actionId == 'respond_urgent_call') {
      await _respondToUrgentCall(
        deviceUid: data['deviceUid'] ?? '',
        callId: data['callId'] ?? '',
      );
      final idHash = (data['callId'] as String? ?? '').hashCode;
      await _localNotif.cancel(idHash);
      return;
    }

    pendingNotificationPayload.value = data;
  }

  static Future<void> _respondToUrgentCall({
    required String deviceUid,
    required String callId,
  }) async {
    if (deviceUid.isEmpty || callId.isEmpty) return;
    try {
      await _db
          .collection('urgentCalls')
          .doc(deviceUid)
          .collection('items')
          .doc(callId)
          .update({
        'status': 'responded',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static void _routeFromData(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    pendingNotificationPayload.value = data;
  }

  static Future<void> _saveToken(String uid) async {
    final token = await _fcm.getToken();
    if (token != null) await _updateToken(uid, token);
  }

  static Future<void> _updateToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    bool isSos = false,
  }) async {
    if (title.isEmpty && body.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Mesaj və bildiriş kanalı',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showUrgentCallNotification({
    required String callId,
    required String deviceUid,
    required String fromUid,
    required String fromName,
    required String message,
  }) async {
    if (callId.isEmpty || deviceUid.isEmpty) return;

    final androidDetails = AndroidNotificationDetails(
      _urgentChannelId,
      _urgentChannelName,
      channelDescription: 'Admindən təcili diqqət tələb edən çağırışlar',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('urgent_alarm'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList(
          [0, 800, 400, 800, 400, 800, 400, 800]),
      actions: const [
        AndroidNotificationAction(
          'respond_urgent_call',
          '✓ Cavab verdim',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final payload = jsonEncode({
      'type': 'urgent_call',
      'callId': callId,
      'deviceUid': deviceUid,
      'fromUid': fromUid,
      'fromName': fromName,
      'message': message,
    });

    await _localNotif.show(
      callId.hashCode,
      '🚨 $fromName',
      message,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    if (dateTime.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      channelDescription: 'Plan, To-Do və xüsusi gün xatırladıcıları',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    try {
      await _localNotif.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _localNotif.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelReminder(int id) async {
    await _localNotif.cancel(id);
  }
}
