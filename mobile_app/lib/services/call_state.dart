import 'package:flutter/foundation.dart';

/// Data carried by realtime socket events before a call is accepted.
class IncomingCallData {
  IncomingCallData({
    required this.conversationId,
    required this.callLogId,
    required this.callType,
    required this.callerUsername,
    required this.callerName,
    required this.isGroup,
    required this.conversationName,
  });

  final int conversationId;
  final int callLogId;
  final String callType;
  final String callerUsername;
  final String callerName;
  final bool isGroup;
  final String conversationName;
}

/// Data for the currently running call, including minimized overlay state.
class ActiveCallData {
  ActiveCallData({
    required this.conversationId,
    required this.callLogId,
    required this.callType,
    required this.isCaller,
    required this.title,
  });

  final int conversationId;
  final int callLogId;
  final String callType;
  final bool isCaller;
  final String title;
}

/// Global call state shared by incoming call screen, call overlay, and video screen.
class CallState extends ChangeNotifier {
  CallState._();
  static final CallState instance = CallState._();

  IncomingCallData? incoming;
  ActiveCallData? active;
  bool minimized = false;

  /// Shows an incoming call only when no call is already active.
  void showIncoming(IncomingCallData data) {
    if (active != null) return;
    incoming = data;
    notifyListeners();
  }

  /// Dismisses the incoming-call modal state.
  void clearIncoming() {
    incoming = null;
    notifyListeners();
  }

  /// Starts an accepted or outgoing call and clears any incoming prompt.
  void startActive(ActiveCallData data) {
    incoming = null;
    active = data;
    minimized = false;
    notifyListeners();
  }

  /// Toggles whether the active call is represented by the floating overlay.
  void setMinimized(bool value) {
    minimized = value;
    notifyListeners();
  }

  /// Clears all call state after hangup, cancel, missed, or remote end events.
  void endActive() {
    incoming = null;
    active = null;
    minimized = false;
    notifyListeners();
  }
}
