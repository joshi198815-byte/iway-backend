import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';

class AppPageIntro extends StatelessWidget {
  final String title;
  final String subtitle;

  const AppPageIntro({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.muted, fontSize: 15),
        ),
      ],
    );
  }
}
