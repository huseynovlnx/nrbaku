import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/notification_vault_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/terminal_fx.dart';
import '../../core/widgets/permission_explainer.dart';
import '../../providers/notification_sharing_providers.dart';

class NotificationVaultScreen extends ConsumerStatefulWidget {
  const NotificationVaultScreen({super.key});

  @override
  ConsumerState createState() => _NotificationVaultScreenState();
}

class _NotificationVaultScreenState
    extends ConsumerState<NotificationVaultScreen> {
  bool _loading = true;
  bool _accessEnabled = false;
  bool _autoPromptShown = false;
  List<CapturedNotification> _mine = [];

  @override
  void initState() {
    super.initState();
    _refresh(auto: true);
  }

  @override
  void dispose() {
    ref.read(notificationVaultRepositoryProvider).dispose();
    super.dispose();
  }

  Future<void> _refresh({bool auto = false}) async {
    setState(() => _loading = true);
    final enabled = await NotificationVaultService.isAccessEnabled();
    final items = enabled
        ? (await NotificationVaultService.getAll()).cast<CapturedNotification>()
        : <CapturedNotification>[];
    if (!mounted) return;
    setState(() {
      _accessEnabled = enabled;
      _mine = items;
      _loading = false;
    });
    if (!enabled && auto && !_autoPromptShown) {
      _autoPromptShown = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _requestAccess());
    }
  }

  Future<void> _requestAccess() async {
    if (!mounted) return;
    await showPermissionExplainer(
      context: context,
      icon: Icons.notifications_active_rounded,
      title: 'Bildiriş girişinə icazə ver',
      description:
          'Açılan siyahıda "NrBaku" tətbiqini tapıb yanındakı '
          'keçidi aktivləşdirin — bütün bildirişlərə icazə verin.',
      buttonText: 'Ayarlara keç',
    );
    await NotificationVaultService.openAccessSettings();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _refresh();
  }

  Future<void> _clearMine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('Hamısını sil', style: AppTheme.heading(size: 18)),
        content: Text(
          'Bütün toplanmış bildiriş tarixçəniz silinsin? '
          'Bu geri qaytarıla bilməz.',
          style: AppTheme.body(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Xeyr'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil', style: AppTheme.body(color: AppTheme.alert)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationVaultService.clearAll();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🔒 BİLDİRİŞ TOPLAYICI', style: AppTheme.heading(size: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.purple));
    }
    if (!_accessEnabled) return _buildAccessRequest();
    if (_mine.isEmpty) return _buildEmpty('Hələ heç bir bildiriş toplanmayıb');

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 70),
          itemCount: _mine.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final n = _mine[i];
            return Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppTheme.alert.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.delete_rounded, color: AppTheme.alert),
              ),
              onDismissed: (_) => NotificationVaultService.deleteOne(n.id),
              child: _NotificationCard(
                appLabel: n.appLabel,
                title: n.title,
                text: n.text,
                time: n.postedAt,
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'clear_mine',
            backgroundColor: AppTheme.alert,
            onPressed: _clearMine,
            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active_outlined,
                size: 64, color: AppTheme.textDim.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Bildiriş girişi lazımdır',
              style: AppTheme.heading(size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Ayarlardan icazə verin, davamı avtomatik olacaq.',
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 14, color: AppTheme.textDim),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestAccess,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Ayarları aç'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined,
              size: 56, color: AppTheme.textDim.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(message, style: AppTheme.body(size: 14, color: AppTheme.textDim)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String appLabel;
  final String title;
  final String text;
  final DateTime time;

  const _NotificationCard({
    required this.appLabel,
    required this.title,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return KartelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(appLabel.toUpperCase(),
                    style: AppTheme.mono(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppTheme.purple)),
              ),
              Text(DateFormat('d MMM, HH:mm').format(time),
                  style: AppTheme.mono(size: 10, color: AppTheme.textDim)),
            ],
          ),
          const SizedBox(height: 6),
          if (title.isNotEmpty)
            Text(title,
                style: AppTheme.body(size: 14, weight: FontWeight.w600)),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(text, style: AppTheme.body(size: 13, color: AppTheme.textDim)),
          ],
        ],
      ),
    );
  }
}