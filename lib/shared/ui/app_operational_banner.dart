import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';

class AppOperationalBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color tone;
  final VoidCallback? onTap;
  final String? ctaLabel;

  const AppOperationalBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
    this.onTap,
    this.ctaLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
                if (onTap != null && ctaLabel != null) ...[
                  const SizedBox(height: 12),
                  TextButton(onPressed: onTap, child: Text(ctaLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
