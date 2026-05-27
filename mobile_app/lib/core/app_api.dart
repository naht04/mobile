import 'package:flutter/foundation.dart';

class AppApi {
  AppApi._();

  static String get host {
    const env = String.fromEnvironment('API_HOST');
    if (env.isNotEmpty) return env;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String get wsHost {
    if (host.startsWith('https://')) {
      return host.replaceFirst('https://', 'wss://');
    }
    return host.replaceFirst('http://', 'ws://');
  }

  static String get baseOrigin => host;
  static String get users => '$host/api/users';
  static String get friends => '$host/api/users/friends';
  static String get community => '$host/api/community';
  static String get documents => '$host/api/documents';
  static String get groups => '$host/api/groups';
  static String get chat => '$host/api/chat';
  static String get notifications => '$host/api/notifications';
  static String wsNotifications(String username) =>
      '$wsHost/ws/notifications/$username/';

  static String wsCall(int conversationId) =>
      '$wsHost/ws/call/$conversationId/';
}
