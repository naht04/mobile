import 'package:flutter/material.dart';
import 'package:mobile_app/screens/incoming_call_screen.dart';
import 'package:mobile_app/screens/video_call_screen.dart';
import 'package:mobile_app/services/call_state.dart';

class CallOverlays extends StatelessWidget {
  const CallOverlays({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CallState.instance,
      builder: (context, _) {
        final incoming = CallState.instance.incoming;
        final active = CallState.instance.active;
        final minimized = CallState.instance.minimized;

        return Stack(
          children: [
            child,
            if (incoming != null)
              Positioned.fill(child: IncomingCallScreen(data: incoming)),
            if (active != null && minimized)
              Positioned(
                right: 12,
                bottom: 90,
                child: GestureDetector(
                  onTap: () {
                    CallState.instance.setMinimized(false);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VideoCallScreen(
                          conversationId: active.conversationId,
                          callLogId: active.callLogId,
                          callType: active.callType,
                          title: active.title,
                          isCaller: active.isCaller,
                        ),
                      ),
                    );
                  },
                  child: Material(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active.callType == 'video'
                                ? Icons.videocam
                                : Icons.call,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            active.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
