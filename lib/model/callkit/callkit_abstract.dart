import "dart:async";

import "package:flutter_callkit_incoming/entities/call_event.dart";
import "package:flutter_callkit_incoming/entities/call_kit_params.dart";

abstract class CallKitVOIPAbstract {
  late CallKitParams callKitParams;

  late Future<dynamic> Function() toRoute;

  FutureOr<void> Function()? onCallDeepLink;

  /// To show up the incoming call alert
  ///
  /// [callerName] is the name of the caller to display
  ///
  /// [callerHandle] may be email or phone number or None
  ///
  /// [callerAvatar] works only in Android to show the avatar of the caller profile.
  /// You can use as an example of avatar at [here](https://i.pravatar.cc/100)
  ///
  /// [duration] is to end and missed call in second, default is `45`s
  ///
  /// [isVideo] is the boolean and default is audio `false`
  ///
  Future<void> inComingCall({
    required String callerName,
    required String callerId,
    String? callerHandle,
    String? callerAvatar,
    int? duration,
    bool isVideo = false,
    // void Function()? onCallDeepLink,
  });

  /// Listen to the call kit event
  Future<void> listenerEvent({
    void Function(CallEvent)? callback,
  });

  Future<void> callEnd();

  /// Check the incoming call is coming from this app and if it is, go to the navigate page
  Future<void> checkAndNavigationCallingPage();

  /// Get device push token VoIP. iOS: return deviceToken, Android: Empty
  Future<String> getDevicePushTokenVoIP();
}
