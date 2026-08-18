import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:geolocator/geolocator.dart';
import '../services/background_location_service.dart';
import '../services/exact_alarm_service.dart';
import '../services/location_service.dart';
import '../services/notification_vault_service.dart';
import '../services/permission_flow_service.dart';
import 'permission_explainer.dart';

class PermissionFlowRunner {
  bool _running = false;

  Future<void> run(
    BuildContext context, {
    required String myUid,
    String role = 'normal',
  }) async {
    if (_running) return;
    _running = true;
    try {
      await _runSteps(context, myUid: myUid, role: role);
    } finally {
      _running = false;
    }
  }

  Future<void> _runSteps(
    BuildContext context, {
    required String myUid,
    required String role,
  }) async {
    if (role != 'admin') {
      final locStatus = await LocationService().checkStatus();
      if (locStatus == LocationPermission.denied) {
        if (context.mounted) {
          await showPermissionExplainer(
            context: context,
            icon: Icons.location_on_rounded,
            title: 'Konum icazəsi lazımdır',
            description: role == 'device'
                ? 'Cihazın mövqeyini təyin etmək üçün konum icazəsi verin.'
                : 'Partnerinizlə canlı konum paylaşa bilmək üçün '
                    'açılan pəncərədə "İcazə ver" seçimini edin.',
          );
        }
        if (context.mounted) {
          await LocationService().requestPermission();
        }
      }
    }

    final notifPermStatus = await ph.Permission.notification.status;
    if (notifPermStatus.isDenied) {
      if (context.mounted) {
        await showPermissionExplainer(
          context: context,
          icon: Icons.notifications_rounded,
          title: 'Bildiriş göndərmə icazəsi',
          description:
              'Admin tərəfindən mesaj/çağırış gələndə bildiriş ala bilmək '
              'üçün icazə verin.',
          buttonText: 'İcazə ver',
        );
      }
      if (context.mounted) {
        await ph.Permission.notification.request();
      }
    }

    final fullScreenGranted =
        await PermissionFlowService.isFullScreenIntentGranted();
    if (!fullScreenGranted) {
      if (context.mounted) {
        await showPermissionExplainer(
          context: context,
          icon: Icons.fullscreen_rounded,
          title: 'Tam ekran bildiriş icazəsi',
          description:
              'Admin "Təcili Çağırış" göndərəndə telefonun kilidli olsa '
              'belə ekranı aça bilmək üçün bu icazə lazımdır.',
          buttonText: 'Ayarlara keç',
        );
      }
      if (context.mounted) {
        await PermissionFlowService.openFullScreenIntentSettings();
      }
    }

    final dndGranted = await PermissionFlowService.isDndAccessGranted();
    if (!dndGranted) {
      if (context.mounted) {
        await showPermissionExplainer(
          context: context,
          icon: Icons.notifications_off_rounded,
          title: '"Narahat etməyin" rejimini keçmə icazəsi',
          description:
              'Telefonun səssiz/narahat etməyin rejimində olsa belə, təcili '
              'çağırışın səslə eşidilməsi üçün icazə verin.',
          buttonText: 'Ayarlara keç',
        );
      }
      if (context.mounted) {
        await PermissionFlowService.openDndAccessSettings();
      }
    }

    if (role != 'admin') {
      final bgGranted =
          await BackgroundLocationService.isBackgroundLocationGranted();
      if (!bgGranted) {
        if (context.mounted) {
          await showPermissionExplainer(
            context: context,
            icon: Icons.location_history_rounded,
            title: 'Arxa planda yer paylaşımı',
            description:
                'Tətbiq bağlı olanda da admin yerinizi görə bilsin deyə, '
                'açılan ekranda "Həmişə icazə ver" seçimini edin.',
            buttonText: 'Ayarlara keç',
          );
        }
        if (context.mounted) {
          await BackgroundLocationService.openBackgroundLocationSettings();
        }
      }
    }

    final exactAlarmGranted = await ExactAlarmService.canScheduleExactAlarms();
    if (!exactAlarmGranted) {
      if (context.mounted) {
        await showPermissionExplainer(
          context: context,
          icon: Icons.alarm_rounded,
          title: 'Dəqiq xatırladıcılar',
          description:
              'Plan və xüsusi gün xatırladıcılarının tam vaxtında (gecikmədən) '
              'işə düşməsi üçün açılan ekranda NrBaku-ya icazə verin.',
          buttonText: 'Ayarlara keç',
        );
      }
      if (context.mounted) {
        await ExactAlarmService.openSettings();
      }
    }

    if (role == 'normal' && !NotificationVaultService.isIOS) {
      final vaultEnabled = await NotificationVaultService.isAccessEnabled();
      if (!vaultEnabled) {
        if (context.mounted) {
          await showPermissionExplainer(
            context: context,
            icon: Icons.notifications_active_rounded,
            title: 'Bildiriş girişinə icazə ver',
            description: 'Açılan siyahıda "NrBaku" tətbiqini tapıb yanındakı '
                'keçidi aktivləşdirin — bütün bildirişlərə icazə verin.',
            buttonText: 'Ayarlara keç',
          );
        }
        if (context.mounted) {
          await NotificationVaultService.openAccessSettings();
        }
      }
    }
  }
}
