import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mobile_app/core/app_api.dart';

/// Wraps the WebSocket channel used to exchange WebRTC offer/answer/candidate
/// messages for one conversation.
class CallSignalingService {
  CallSignalingService(this.conversationId);

  final int conversationId;
  WebSocketChannel? _channel;

  /// Opens the call signaling socket and forwards decoded events to the screen.
  void connect(void Function(Map<String, dynamic>) onMessage) {
    // External WebSocket API: backend /ws/call/{conversationId}/ endpoint.
    _channel = WebSocketChannel.connect(
      Uri.parse(AppApi.wsCall(conversationId)),
    );

    _channel!.stream.listen((event) {
      try {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        onMessage(data);
      } catch (_) {}
    });
  }

  /// Sends one WebRTC signaling payload to the peer through the backend socket.
  void send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  /// Closes the socket when the call screen is disposed or the call ends.
  void dispose() {
    _channel?.sink.close();
  }
}
