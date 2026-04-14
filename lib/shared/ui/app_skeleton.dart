import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';

class AppSkeletonBlock extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  final EdgeInsetsGeometry margin;

  const AppSkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = 16,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.7),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return AnimatedOpacity(
          opacity: value,
          duration: const Duration(milliseconds: 900),
          child: child,
        );
      },
      onEnd: () {},
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppTheme.border),
        ),
      ),
    );
  }
}
