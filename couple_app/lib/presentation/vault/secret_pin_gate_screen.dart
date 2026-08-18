import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'notification_vault_screen.dart';
import 'browsing_history_screen.dart';

/// 5-tap jestindən sonra göstərilən kod ekranı. Doğru kod (1752) daxil
/// edilərsə, gizli bölmənin seçim menyusuna keçir.
///
/// ⚠️ TƏHLÜKƏSİNLİK: PIN kodu source code-da hardcoded-dir.
/// Şəxsi istifadə üçün kifayətdir, amma brute-force hücumuna qarşı
/// rate limiting tətbiq olunub.
class SecretPinGateScreen extends StatefulWidget {
  const SecretPinGateScreen({super.key});

  @override
  State<SecretPinGateScreen> createState() => _SecretPinGateScreenState();
}

class _SecretPinGateScreenState extends State<SecretPinGateScreen> {
  static const _correctPin = '1752';
  static const _maxAttempts = 5;
  static const _lockoutDuration = Duration(minutes: 5);

  final _controller = TextEditingController();
  String? _error;
  int _attemptCount = 0;
  DateTime? _lockedUntil;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLocked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  void _submit() {
    if (_isLocked) {
      final remaining = _lockedUntil!.difference(DateTime.now());
      setState(() => _error =
          'Kilidləndi. ${remaining.inMinutes + 1} dəq. sonra yenidən cəhd edin.');
      return;
    }

    if (_controller.text.trim() == _correctPin) {
      _attemptCount = 0;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const _SecretMenuScreen()),
      );
    } else {
      _attemptCount++;
      _controller.clear();

      if (_attemptCount >= _maxAttempts) {
        _lockedUntil = DateTime.now().add(_lockoutDuration);
        setState(() => _error =
            'Çox sayda səhv cəhd. 5 dəq. sonra yenidən yoxlayın.');
      } else {
        setState(() =>
            _error = 'Kod səhvdir. Qalan cəhd: ${_maxAttempts - _attemptCount}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: Colors.white54, size: 40),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _error,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                onChanged: (v) {
                  if (_error != null) setState(() => _error = null);
                  if (v.length == 4) _submit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecretMenuScreen extends StatelessWidget {
  const _SecretMenuScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizli Bölmə'),
        flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.gradient)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuCard(
            icon: Icons.notifications_active_rounded,
            title: 'Bildiriş Toplayıcı',
            subtitle: 'Telefona gələn bildirişlər',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const NotificationVaultScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.travel_explore_rounded,
            title: 'Gəzinti Tarixçəsi',
            subtitle: 'Chrome-da ziyarət edilən səhifələr',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const BrowsingHistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.purple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
