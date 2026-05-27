import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/home_shell_screen.dart';
import 'package:mobile_app/screens/login_screen.dart';

import 'package:mobile_app/services/notification_socket_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      if (AppSession.isLoggedIn) {
        NotificationSocketService.instance.connect();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeShellScreen()),
        );
      } else {
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoMark(),
            SizedBox(width: 12),
            Text(
              'P-Connect',
              style: TextStyle(
                color: Color(0xFFE43A5E),
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF3D97FF), Color(0xFFE73A62)],
        ),
      ),
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.link_rounded, color: Color(0xFF5A7BFF)),
        ),
      ),
    );
  }
}
