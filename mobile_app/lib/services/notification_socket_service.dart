import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/services/call_state.dart';

/// App-level WebSocket listener for realtime notifications and call events.
class NotificationSocketService {
  NotificationSocketService._();
  static final NotificationSocketService instance =
      NotificationSocketService._();

  WebSocketChannel? _channel;

  /// Connects the current user to the notification socket after login.
  void connect() {
    if (AppSession.username.isEmpty || AppSession.username == 'demo_user') {
      debugPrint('skip notification socket: invalid username');
      return;
    }

    debugPrint('connect notification socket for ${AppSession.username}');
    _channel?.sink.close();

    // External WebSocket API: backend /ws/notifications/{username}/ endpoint.
    _channel = WebSocketChannel.connect(
      Uri.parse(AppApi.wsNotifications(AppSession.username)),
    );

    _channel!.stream.listen(
      (event) {
        try {
          debugPrint('notification socket event: $event');

          final data = jsonDecode(event as String) as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString();

          if (type == 'incoming_call') {
            if (CallState.instance.active != null) return;

            CallState.instance.showIncoming(
              IncomingCallData(
                conversationId: (data['conversation_id'] as num?)?.toInt() ?? 0,
                callLogId: (data['call_log_id'] as num?)?.toInt() ?? 0,
                callType: (data['call_type'] ?? 'video').toString(),
                callerUsername: (data['caller_username'] ?? '').toString(),
                callerName: (data['caller_name'] ?? '').toString(),
                isGroup: data['is_group'] == true,
                conversationName: (data['conversation_name'] ?? '').toString(),
              ),
            );
          } else if (type == 'call_status') {
            final status = (data['status'] ?? '').toString();

            if ([
              'rejected',
              'busy',
              'missed',
              'canceled',
              'ended',
            ].contains(status)) {
              CallState.instance.endActive();
            }
          }
        } catch (e) {
          debugPrint('notification socket parse error: $e');
        }
      },
      onError: (e) {
        debugPrint('notification socket error: $e');
      },
      onDone: () {
        debugPrint('notification socket done');
      },
    );
  }

  /// Releases the notification socket when the app session ends.
  void dispose() {
    _channel?.sink.close();
  }
}
