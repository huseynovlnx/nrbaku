import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// İcazə soruşulmazdan (sistem dialoqu/ayarları açılmazdan) əvvəl
/// istifadəçiyə sadə şəkildə nə üçün lazım olduğunu izah edən pəncərə.
/// "Davam et" düyməsi basılanda `true` qaytarır, ləğv edilsə `false`/`null`.
Future<bool> showPermissionExplainer({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String description,
  String buttonText = 'Davam et',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.gradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey.shade600, height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İndi yox'),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
