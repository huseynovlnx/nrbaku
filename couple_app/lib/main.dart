import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/fcm_service.dart';
import 'core/services/urgent_call_launch_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/access_repository.dart';
import 'firebase_options.dart';
import 'providers/access_providers.dart';
import 'providers/auth_providers.dart';
import 'providers/urgent_call_providers.dart';
import 'presentation/admin/admin_shell.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/device/device_shell.dart';
import 'presentation/splash/splash_screen.dart';
import 'presentation/urgent_call/urgent_call_full_screen.dart';

/// Bütün naviqasiyanı (BuildContext olmadan da) idarə edə bilmək üçün.
final navigatorKey = GlobalKey<NavigatorState>();

/// Tətbiqin harasında olursa olsun SnackBar göstərə bilmək üçün.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Arxa plan FCM handler-i — runApp-dan ƏVVƏL, YALNIZ BİR DƏFƏ
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: CoupleApp()));
}

class CoupleApp extends StatelessWidget {
  const CoupleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'NrBaku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _AppStartup(),
    );
  }
}

class _AppStartup extends StatefulWidget {
  const _AppStartup();

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(
        onFinished: () => setState(() => _splashDone = true),
      );
    }
    return const AuthGate();
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    pendingNotificationPayload.addListener(_onPendingPayload);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _onPendingPayload());

    UrgentCallLaunchService.init();
    UrgentCallLaunchService.onLaunch = _navigateToUrgentCall;
    UrgentCallLaunchService.getPendingLaunch().then((data) {
      if (!mounted) return;
      if (data != null) _navigateToUrgentCall(data);
    });
  }

  @override
  void dispose() {
    pendingNotificationPayload.removeListener(_onPendingPayload);
    UrgentCallLaunchService.onLaunch = null;
    super.dispose();
  }

  void _navigateToUrgentCall(Map<String, dynamic> data) {
    final callId = data['callId'] ?? '';
    if (callId.isEmpty) return;
    final fromName = data['fromName'] ?? 'Admin';
    final message = data['message'] ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => UrgentCallFullScreen(
            callId: callId,
            fromName: fromName,
            message: message,
          ),
          fullscreenDialog: true,
        ),
      );
    });
  }

  void _onPendingPayload() {
    final data = pendingNotificationPayload.value;
    if (data == null) return;
    pendingNotificationPayload.value = null;

    if (data['type'] == 'urgent_call') {
      final callId = data['callId'] as String? ?? '';
      final fromName = data['fromName'] as String? ?? 'Admin';
      final message = data['message'] as String? ?? '';
      if (callId.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => UrgentCallFullScreen(
              callId: callId,
              fromName: fromName,
              message: message,
            ),
            fullscreenDialog: true,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _MiniLoader(),
      error: (e, _) => Scaffold(body: Center(child: Text('Xəta: $e'))),
      data: (user) {
        if (user == null) return const LoginScreen();

        final roleAsync = ref.watch(userRoleProvider);
        return roleAsync.when(
          loading: () => const _MiniLoader(),
          error: (_, __) => const _MiniLoader(),
          data: (role) {
            if (role == UserRole.admin) return const AdminShell();
            return const DeviceShell();
          },
        );
      },
    );
  }
}

class _MiniLoader extends StatelessWidget {
  const _MiniLoader();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 56, color: Colors.white),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 64),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
