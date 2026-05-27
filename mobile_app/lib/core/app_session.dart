import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  AppSession._();

  static String username = 'demo_user';
  static String accessToken = '';
  static String refreshToken = '';

  static bool get isLoggedIn =>
      username != 'demo_user' && accessToken.isNotEmpty;

  static Map<String, String> authHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{};
    if (accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    if (username.isNotEmpty && username != 'demo_user') {
      headers['X-Demo-User'] = username;
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('session_username') ?? 'demo_user';
    accessToken = prefs.getString('session_access_token') ?? '';
    refreshToken = prefs.getString('session_refresh_token') ?? '';
  }

  static Future<void> saveLogin({
    required String usernameValue,
    required String accessTokenValue,
    required String refreshTokenValue,
  }) async {
    username = usernameValue;
    accessToken = accessTokenValue;
    refreshToken = refreshTokenValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_username', usernameValue);
    await prefs.setString('session_access_token', accessTokenValue);
    await prefs.setString('session_refresh_token', refreshTokenValue);
  }

  static Future<void> clear() async {
    username = 'demo_user';
    accessToken = '';
    refreshToken = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_username');
    await prefs.remove('session_access_token');
    await prefs.remove('session_refresh_token');
  }
}
