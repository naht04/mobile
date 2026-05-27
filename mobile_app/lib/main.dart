import 'package:flutter/material.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/splash_screen.dart';
import 'package:mobile_app/services/notification_socket_service.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/call_overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSession.init();
  runApp(const PConnectApp());
}

class PConnectApp extends StatefulWidget {
  const PConnectApp({super.key});

  @override
  State<PConnectApp> createState() => _PConnectAppState();
}

class _PConnectAppState extends State<PConnectApp> {
  bool _connectedSocket = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_connectedSocket) {
      _connectedSocket = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'P-Connect',
      theme: AppTheme.light(),
      routes: {LoginScreen.routeName: (_) => const LoginScreen()},
      builder: (context, child) {
        return CallOverlays(child: child ?? const SizedBox());
      },
      home: const SplashScreen(),
    );
  }
}
