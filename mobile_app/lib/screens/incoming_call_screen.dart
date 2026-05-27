import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/video_call_screen.dart';
import 'package:mobile_app/services/call_state.dart';

/// Modal screen shown when a realtime incoming_call socket event arrives.
class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key, required this.data});

  final IncomingCallData data;

  /// Persists the callee decision before opening or closing the call screen.
  Future<void> _updateStatus(String statusValue) async {
    // External HTTP API: POST /api/chat/{conversationId}/call-logs/{callLogId}/status/.
    await http.post(
      Uri.parse(
        '${AppApi.chat}/${data.conversationId}/call-logs/${data.callLogId}/status/',
      ),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'status': statusValue}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.account_circle, size: 96, color: Colors.white70),
            const SizedBox(height: 20),
            Text(
              data.callerName.isEmpty ? data.callerUsername : data.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.callType == 'video'
                  ? 'Cuộc gọi video đến'
                  : 'Cuộc gọi thoại đến',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.orange,
                  onPressed: () async {
                    await _updateStatus('busy');
                    CallState.instance.clearIncoming();
                  },
                  child: const Icon(Icons.phone_disabled),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () async {
                    await _updateStatus('rejected');
                    CallState.instance.clearIncoming();
                  },
                  child: const Icon(Icons.call_end),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.green,
                  onPressed: () async {
                    final title = data.callerName.isEmpty
                        ? data.callerUsername
                        : data.callerName;
                    await _updateStatus('answered');
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => VideoCallScreen(
                            conversationId: data.conversationId,
                            callLogId: data.callLogId,
                            callType: data.callType,
                            title: title,
                            isCaller: false,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Icon(Icons.call),
                ),
              ],
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
