import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// SOS tam-ekran — hazırda gizlədilmişdir.
/// Kod saxlanılır ki, gələcəkdə aktivləşdirilərkən sıfırdan yazılmasın.
class UrgentCallFullScreen extends StatelessWidget {
  final String callId;
  final String fromName;
  final String message;

  const UrgentCallFullScreen({
    super.key,
    required this.callId,
    required this.fromName,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SOS', style: AppTheme.heading(size: 32, color: AppTheme.alert)),
            const SizedBox(height: 16),
            Text(fromName, style: AppTheme.body(size: 18)),
            const SizedBox(height: 8),
            Text(message, style: AppTheme.body(color: AppTheme.textDim)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('BAĞLA'),
            ),
          ],
        ),
      ),
    );
  }
}
