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
    _startDeviceReporting(user.uid);

    final reminders = await ref.read(remindersProvider.future);
    unawaited(
      ref.read(reminderControllerProvider.notifier).syncAlarms(reminders),
    );
  }

  Future<void> _startLocationReporting(String uid) async {
    final svc = ref.read(locationServiceProvider);
    final status = await svc.checkStatus();

    bool nativeStarted = false;

    if (status == LocationPermission.always) {
      final bgGranted =
          await BackgroundLocationService.isBackgroundLocationGranted();
      if (bgGranted) {
        await BackgroundLocationService.start();
        nativeStarted = true;
      }
    }

    if (!nativeStarted &&
        (status == LocationPermission.always ||
            status == LocationPermission.whileInUse)) {
      svc.startTracking(uid);
    }
  }

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
    } catch (_) {}
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    final svc = ref.read(locationServiceProvider);
    svc.stopTracking();

    BackgroundLocationService.stop();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = ref.read(userDocProvider).value;
      if (user != null) {
        _startLocationReporting(user.uid);
        _reportOnce();

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
          user != null
              ? DeviceChatScreen(deviceUid: user.uid, isAdmin: false)
              : const SizedBox.shrink(),
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
                    label: Text('\$unread'),
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
