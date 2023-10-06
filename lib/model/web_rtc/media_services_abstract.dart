import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:jack_rtc_call/src/socket/socket_data.dart";
import "package:jack_rtc_call/src/web_rtc/rtc_connection.dart";
import "package:rxdart/rxdart.dart";

abstract class RTCMediaServiceAbstract {
  final socketData = SocketData();

  // videoRenderer for localPeer
  //! check it that can listen when we set `srcObject`
  final localRTCVideoRenderer = BehaviorSubject<RTCVideoRenderer>();

  // mediaStream for localPeer
  final localStream = BehaviorSubject<MediaStream?>();

  // videoRenderer for remotePeer
  final remoteRTCVideoRenderer = BehaviorSubject<RTCVideoRenderer>();

  /// data channel
  RTCDataChannel? channel;

  // tempMessage
  final tempMessages = <RTCDataChannelMessage>[];

  late Function(RTCDataChannelMessage message) onListenMessage;

  late Function() onPartnerCallEnded;

  final rtcConnection = RTCConnections();

  /// -------------------------- Media status --------------------------

  final isCallingMedia = BehaviorSubject<bool>();
  final isAudioOn = BehaviorSubject<bool>();
  final isVideoOn = BehaviorSubject<bool>();
  final isFrontCamera = BehaviorSubject<bool>();
  final isJoinedCallingMedia = BehaviorSubject<bool>.seeded(false);
  final isPartnerVideoOpen = BehaviorSubject<bool>();
  final isSpeakerOn = BehaviorSubject<bool>();

  Stream<(bool, bool, bool, bool, bool, bool)> get mediaStatus;

  void init();

  void setAudioStatus({required bool status});

  void setVideoStatus({required bool status});

  Future<void> switchCamera();

  Future<void> setSpeakerStatus({
    required bool status,
  });

  /// --------------------- Data Channel ------------------

  Future<void> sendMessage({
    required dynamic message,
    bool isBinary = false,
  });

  /// --------------------- Media Call Action ------------------

  Future<void> setupMediaCall({
    bool audioOn = true,
    bool videoOn = false,
    bool frontCameraOn = true,
  });

  /// You should return true when not ending the media calling
  Future<dynamic> mediaCall({
    required bool videoOn,
    required Future<dynamic> Function() toRoute,
    required String callerName,
    String? callerHandle,
    String? callerAvatar,
  });

  Future<void> acceptCall({
    required Future<dynamic> Function() toRoute,
    dynamic offer,
  });

  Future<void> callEnd();

  /// --------------------- Listening Methods ------------------

  Future<RTCSessionDescription> onListenMessageService({
    required void Function(RTCDataChannelMessage message) onMessage,
  });

  Future<void> onDataChannelService({
    required RTCDataChannelState state,
  });
}
