import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/models/user_model.dart';
import 'package:iway_app/services/session_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    final currentUser = SessionService.currentUser;
    final needsContactVerification = _needsContactVerification(currentUser);

    Navigator.pushReplacementNamed(
      context,
      !SessionService.isLoggedIn
          ? '/login'
          : needsContactVerification
              ? '/verify_contact'
              : '/home',
    );
  }

  bool _needsContactVerification(UserModel? user) {
    if (user == null) return false;
    return !user.emailVerificado && !user.telefonoVerificado;
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              Color(0xFF111216),
              Color(0xFF0A0A0C),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.local_shipping_rounded, size: 56, color: AppTheme.accent),
              SizedBox(height: 16),
              Text(
                'iWay',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'GT ↔ USA logistics',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
