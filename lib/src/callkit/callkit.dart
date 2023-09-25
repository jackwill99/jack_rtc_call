import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_callkit_incoming/entities/entities.dart";
import "package:flutter_callkit_incoming/flutter_callkit_incoming.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";
import "package:uuid/uuid.dart";

@protected
class CallKitVOIP {
  factory CallKitVOIP() {
    return I;
  }

  CallKitVOIP._();

  static final CallKitVOIP I = CallKitVOIP._();

  String? _currentUuid;
  late CallKitParams callKitParams;

  late Future<dynamic> Function() toRoute;

  FutureOr<void> Function()? onCallDeepLink;

  /// `callerName` is the name of the caller to display
  ///
  /// `callerHandle` may be email or phone number or None
  ///
  /// `callerAvatar` works only in Android to show the avatar of the caller profile
  ///
  /// `duration` is to end and missed call in second, default is `45`s
  ///
  /// `isVideo` is the boolean and default is audio `false`
  ///
  Future<void> inComingCall({
    required String callerName,
    required String callerId,
    String? callerHandle,
    //'https://i.pravatar.cc/100'
    String? callerAvatar,
    int? duration,
    bool isVideo = false,
    void Function()? onCallDeepLink,
  }) async {
    _currentUuid = const Uuid().v4();
    debugPrint(
      "----------------------incomming call $_currentUuid----------------------",
    );
    final params = CallKitParams(
      id: _currentUuid,
      nameCaller: callerName,
      appName: "Sabahna TeleMed",
      avatar: callerAvatar,
      handle: callerHandle,
      type: isVideo ? 1 : 0,
      duration: duration ?? 45000,
      textAccept: "Accept",
      textDecline: "Decline",
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: "Missed TeleMed call",
        callbackText: "Call back TeleMed",
      ),
      extra: {
        "callerId": callerId,
      },
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: "sabahna_ringtone",
        backgroundColor: "#0955fa",
        backgroundUrl: callerAvatar ?? "assets/test.png",
        actionColor: "#4CAF50",
        incomingCallNotificationChannelName: "Incoming Call",
        missedCallNotificationChannelName: "Missed Call",
      ),
      ios: IOSParams(
        // iconName: 'CallKitLogo',
        handleType: callerHandle,
        supportsVideo: isVideo,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: "videoChat",
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: "sabahna_ringtone",
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
    callKitParams = params;
  }

  Future<void> listenerEvent({
    void Function(CallEvent)? callback,
  }) async {
    SocketData? socketData;
    try {
      socketData = GetIt.instance<SocketData>();
    } catch (_) {
      debugPrint("---------------------can't socketData----------------------");
    }

    try {
      FlutterCallkitIncoming.onEvent.listen((event) async {
        switch (event!.event) {
          case Event.actionCallIncoming:
            debugPrint(
              "----------------------incoming call----------------------",
            );
            break;
          case Event.actionCallAccept:
            debugPrint(
              "----------------------accept call-----${onCallDeepLink != null}-----------------",
            );
            if (onCallDeepLink != null) {
              onCallDeepLink?.call();
              debugPrint("onCalldeeplink called");
              onCallDeepLink = null;
            } else {
              await RTCMediaService.I.acceptCall(toRoute: toRoute);
              if (_currentUuid != null) {
                await FlutterCallkitIncoming.setCallConnected(_currentUuid!);
              }
            }

            break;
          case Event.actionCallDecline:
            try {
              socketData?.socket.emit("declineCall", {
                "to": callKitParams.extra?["callerId"],
              });
            } catch (_) {
              debugPrint(
                "----------------------socket can't emit in background. you need to establish socket----------------------",
              );
            }
            await callEnd();
            break;
          case Event.actionCallTimeout:
            debugPrint(
              "----------------------missed called----------------------",
            );
            await FlutterCallkitIncoming.showMissCallNotification(
              callKitParams,
            );

            break;
          case Event.actionCallToggleMute:
            break;
          case Event.actionDidUpdateDevicePushTokenVoip:
            break;
          default:
            break;
        }
        callback?.call(event);
      });
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> callEnd() async {
    debugPrint(
      "----------------------call end in call kit $_currentUuid----------------------",
    );
    if (_currentUuid != null) {
      final i = await FlutterCallkitIncoming.activeCalls();
      await FlutterCallkitIncoming.endCall(_currentUuid!);
      _currentUuid = null;
      debugPrint("----------------------active call $i----------------------");
    } else {
      debugPrint(
        "----------------------current id is null----------------------",
      );
    }
  }

  Future<void> checkAndNavigationCallingPage() async {
    final currentCall = await _getCurrentCall();
    if (currentCall != null) {
      /// navigate to calling page
      await toRoute();
    }
  }

  Future<dynamic> _getCurrentCall() async {
    //check current call from pushkit if possible
    final calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      if (calls.isNotEmpty) {
        debugPrint("callDATA: $calls[0]");
        if (_currentUuid == (calls[0] as Map<String, dynamic>)["id"]) {
          return calls[0];
        }
      } else {
        return null;
      }
    }
  }

  /// Get device push token VoIP. iOS: return deviceToken, Android: Empty
  Future<String> getDevicePushTokenVoIP() async {
    final devicePushTokenVoIP =
        await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    debugPrint(
      "----------------------Device Push Token VoIP----$devicePushTokenVoIP------------------",
    );
    return devicePushTokenVoIP;
  }
}
