import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/background_location_service.dart';
import '../../core/services/device_reporter_service.dart';
import '../../core/services/fcm_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/terminal_fx.dart';
import '../../core/widgets/permission_flow_runner.dart';
import '../../providers/admin_chat_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/location_providers.dart' show locationServiceProvider;
import '../../providers/reminder_providers.dart';
import '../reminders/reminders_screen.dart';
import '../settings/settings_screen.dart';
import 'device_chat_screen.dart';

class DeviceShell extends ConsumerStatefulWidget {
  const DeviceShell({super.key});

  @override
  ConsumerState<DeviceShell> createState() => _DeviceShellState();
}

class _DeviceShellState extends ConsumerState<DeviceShell>
    with WidgetsBindingObserver {
  int _tab = 0;
  Timer? _reportTimer;
  final _permissionFlow = PermissionFlowRunner();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final user = ref.read(userDocProvider).value;
    if (user == null) return;

    await FcmService.init(user.uid);

    if (mounted) {
      await _permissionFlow.run(context, myUid: user.uid, role: 'device');
    }

    await _startLocationReporting(user.uid);
    _startDeviceReporting(user.uid);  // uid indi real-time oxunur

    final reminders = await ref.read(remindersProvider.future);
    unawaited(
      ref.read(reminderControllerProvider.notifier).syncAlarms(reminders),
    );
  }

  /// Konum izləməni başlat:
  /// 1) Əvvəlcə native background service yoxla ("Həmişə icazə ver" lazımdır)
  /// 2) Native işləmirsə, Dart Geolocator stream-i işə sal (foreground-only)
  Future<void> _startLocationReporting(String uid) async {
    final svc = ref.read(locationServiceProvider);
    final status = await svc.checkStatus();

    bool nativeStarted = false;

    // Yalnız "Həmişə icazə ver" varsa native background service işə sala bilər
    if (status == LocationPermission.always) {
      final bgGranted =
          await BackgroundLocationService.isBackgroundLocationGranted();
      if (bgGranted) {
        await BackgroundLocationService.start();
        nativeStarted = true;
      }
    }

    // Native başlamayıbsa, Dart stream ilə fallback et
    // (bu yalnız tətbiq açıq olanda işləyir)
    if (!nativeStarted &&
        (status == LocationPermission.always ||
            status == LocationPermission.whileInUse)) {
      svc.startTracking(uid);
    }
  }

  /// Cihaz statusunu (batareya, WiFi) hər 5 dəqiqədən bir Firestore-a yaz.
  /// Location artıq LocationService.startTracking() və ya
  /// BackgroundLocationService tərəfindən ayrıca yazılır.
  void _startDeviceReporting(String uid) {
    _reportOnce();
    _reportTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _reportOnce(),
    );
  }

  Future<void> _reportOnce() async {
    try {
      final currentUser = ref.read(userDocProvider).value;
      if (currentUser == null) return;
      final status = await DeviceReporterService.getDeviceStatus();
      if (status.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(currentUser.uid)
          .set(status, SetOptions(merge: true));
    } catch (_) {
      // Silent fail — cihaz statusu kritik deyil
    }
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    // Dart stream-i dayandır
    ref.read(locationServiceProvider).stopTracking();

    // Native background service-i dayandır
    BackgroundLocationService.stop();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = ref.read(userDocProvider).value;
      if (user != null) {
        // App önə gələndə location reporting-i yenidən yoxla
        _startLocationReporting(user.uid);
        _reportOnce();

        // Permission flow-u yenidən yoxla (istifadəçi ayarlardan icazə vermiş ola bilər)
        if (mounted) {
          _permissionFlow.run(context, myUid: user.uid, role: 'device');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDocProvider).value;
    final unreadAsync = ref.watch(deviceUnreadCountProvider);
    final unread = unreadAsync.value ?? 0;

    ref.listen(remindersProvider, (_, next) {
      final list = next.value;
      if (list == null) return;
      ref.read(reminderControllerProvider.notifier).syncAlarms(list);
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NrBaku', style: AppTheme.heading(size: 18, spacing: 1.2)),
            const SizedBox(width: 8),
            PatronCursor(size: 8),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          // Admin ilə chat
          user != null
              ? DeviceChatScreen(deviceUid: user.uid, isAdmin: false)
              : const SizedBox.shrink(),
          // Xatırladıcılar
          const RemindersScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 0 && user != null) {
            ref.read(adminChatControllerProvider.notifier).markRead(
                  deviceUid: user.uid,
                  readByAdmin: false,
                );
          }
        },
        destinations: [
          NavigationDestination(
            icon: unread > 0
                ? Badge(
                    label: Text('$unread'),
                    backgroundColor: AppTheme.alert,
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  )
                : const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: 'ƏLAQƏ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm_rounded),
            label: 'ƏMƏL.',
          ),
        ],
      ),
    );
  }
}
