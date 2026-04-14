import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';

class AppBackButtonShell extends StatelessWidget {
  final VoidCallback onTap;

  const AppBackButtonShell({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: onTap,
        ),
      ),
    );
  }
}
