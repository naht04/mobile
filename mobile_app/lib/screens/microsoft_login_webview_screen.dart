import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MicrosoftLoginWebViewScreen extends StatefulWidget {
  const MicrosoftLoginWebViewScreen({super.key, required this.emailHint});

  final String emailHint;

  @override
  State<MicrosoftLoginWebViewScreen> createState() =>
      _MicrosoftLoginWebViewScreenState();
}

class _MicrosoftLoginWebViewScreenState
    extends State<MicrosoftLoginWebViewScreen> {
  static const String _clientId = 'YOUR_AZURE_CLIENT_ID';
  static const String _redirectUri =
      'https://login.microsoftonline.com/common/oauth2/nativeclient';

  late final Uri _loginUri;
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final normalizedHint = widget.emailHint.trim();
    final queryParams = <String, String>{
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'response_mode': 'query',
      'scope': 'openid profile email',
      'prompt': 'select_account',
    };
    if (normalizedHint.contains('@')) {
      queryParams['login_hint'] = normalizedHint;
    }
    _loginUri = Uri.https(
      'login.microsoftonline.com',
      '/common/oauth2/v2.0/authorize',
      queryParams,
    );

    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _isLoading = true),
            onPageFinished: (_) => setState(() => _isLoading = false),
          ),
        )
        ..loadRequest(_loginUri);
    } else {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập Microsoft'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xong'),
          ),
        ],
      ),
      body: kIsWeb ? _buildWebFallback() : _buildMobileWebView(),
    );
  }

  Widget _buildMobileWebView() {
    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildWebFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bản web không hỗ trợ WebView trực tiếp.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  launchUrl(_loginUri, mode: LaunchMode.externalApplication),
              child: const Text('Mở trang đăng nhập Microsoft'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đăng nhập xong quay lại app và bấm "Xong".',
              style: TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
