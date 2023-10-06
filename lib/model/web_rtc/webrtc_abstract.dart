import "dart:async";

import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:jack_rtc_call/src/socket/socket_data.dart";
import "package:rxdart/rxdart.dart";

abstract class WebRTCAbstract {
  final socketData = SocketData();

  late Future<dynamic> Function() toRoute;

  // ------------------------ Connection and Disconnection ---------------------

  /// This will disconnect everything such as websocket, peer to peer connection
  Future<void> disconnect();

  // ------------------------ Media Services Section ---------------------

  // *************** Data Channel

  /// Send a message to another peer connection
  Future<void> sendMessage({
    required dynamic message,
    bool isBinary = false,
  });

  // *************** Media Calling

  /// [callerName] is the name of the caller to display
  ///
  /// [callerHandle] may be email or phone number or None
  ///
  /// [callerAvatar] works only in Android to show the avatar of the caller profile
  ///
  Future<dynamic> mediaCall({
    required bool isVideoOn,
    required String callerName,
    String? callerHandle,
    String? callerAvatar,
  });

  /// Accept the incoming call, connect to communicate and go to the desired page
  Future<void> acceptCall();

  ///
  Future<void> endCall({required bool isComesFromChat});

  Future<void> cancelCall();

  void setAudio({required bool status});

  void setVideo({required bool status});

  void switchCamera();

  Future<void> setSpeaker({required bool status});

  /// `isJoinedCallingMedia, isAudioOn, isVideoOn, isFrontCamera, isPartnerVideoOpen, isSpeakerOn`
  Stream<(bool, bool, bool, bool, bool, bool)> mediaStatus();

  // ------------------------ Other Miscellaneous actions ---------------------

  Future<void> enterChatPage();

  Future<void> leaveChatPage();

  void onListenMiscState({
    required Function(RTCDataChannelMessage message) onListenMessage,
    required void Function() onListenPartnerCallEnded,
    required void Function(String? id, {required bool isOnline}) onListenOnline,
    required FutureOr<void> Function() onListenPartnerCallCancel,
    required FutureOr<void> Function() onListenDeclineCall,
    required void Function({
      String? callerName,
      String? callHandler,
      String? avatar,
    }) onListenCallerInfo,
  });

  // -------------

  ValueStream<RTCVideoRenderer?> get onLocalRTCMedia;

  ValueStream<MediaStream?> get onLocalStream;

  ValueStream<RTCVideoRenderer?> get onRemoteRTCMedia;
}
