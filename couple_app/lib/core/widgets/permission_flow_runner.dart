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

/// Bütün icazələri SIRAYLA soruşan axın idarəçisi.
///
/// ƏSAS DƏYİŞİKLİK: əvvəl hər addımda `return` ilə kəsirdi,
/// indi bütün addımlar ardıcıl icra olunur. İstifadəçi bir icazə
/// verdikdən sonra proqramı yenidən açmaq məcburiyyətində qalmır.
///
/// [role] parametri ilə admin/cihaz/normal rejimə uyğun icazələr soruşulur:
/// - admin: yalnız bildiriş + tam ekran + DND (vault/konum lazım deyil)
/// - device: konum + bildiriş + tam ekran + DND + arxa plan + xatırladıcı
/// - normal: hamısı (konum, bildiriş, tam ekran, DND, arxa plan, xatırladıcı, vault)
class PermissionFlowRunner {
  bool _running = false;

  Future<void> run(
    BuildContext context, {
    required String myUid,
    String role = 'normal', // 'admin', 'device', 'normal'
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
    // ── 1) Konum icazəsi — admin üçün lazım deyil ─────────────────────
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
          await LocationService().requestPermission();
        }
      }
    }

    // ── 2) Bildiriş göndərmə icazəsi (Android 13+) ────────────────────
    // Bundan sonrakı HEÇ bir bildiriş (SOS daxil) bu olmadan görünə bilməz.
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
        await ph.Permission.notification.request();
      }
    }

    // ── 3) Full-Screen Intent (Android 14+) ───────────────────────────
    // Təcili Çağırış üçün MÜTLƏQ lazımdır.
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
        await PermissionFlowService.openFullScreenIntentSettings();
      }
    }

    // ── 4) DND (Do Not Disturb) girişi ────────────────────────────────
    // Səssiz rejimdə də səs çıxsın.
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
        await PermissionFlowService.openDndAccessSettings();
      }
    }

    // ═══ Bu nöqtəyə qədər bütün SOS-a aid icazələr tamamlanıb. ═══
    // Aşağıdakılar ikinci dərəcəli (map/xatırladıcı/vault) xüsusiyyətlərdir.

    // ── 5) Arxa planda yer paylaşımı ("Həmişə icazə ver") ─────────────
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
          await BackgroundLocationService.openBackgroundLocationSettings();
        }
      }
    }

    // ── 6) Dəqiq vaxtlı xatırladıcılar ────────────────────────────────
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
        await ExactAlarmService.openSettings();
      }
    }

    // ── 7) Bildiriş girişi (NotificationListenerService) ──────────────
    // Yalnız normal rejim. Admin və cihaz hesabları vault istifadə etmir.
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
          await NotificationVaultService.openAccessSettings();
        }
      }
    }

    // Hamısı verilib — heç nə etmə
  }
}
