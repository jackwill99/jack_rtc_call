//
// Created by Jack Will on 28/06/2023.
// https://github.com/jackwill99
// This file is created for only public methods of class

import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:jack_rtc_call/model/web_rtc/webrtc_abstract.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/misc_socket.dart";
import "package:jack_rtc_call/src/socket/socket_data.dart";
import "package:jack_rtc_call/src/socket/socket_media_services.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";
import "package:jack_rtc_call/src/web_rtc/rtc_connection.dart";
import "package:rxdart/rxdart.dart";

class JackRTCService extends WebRTCAbstract {
  ///
  /// `toCallingPage` is route for calling page
  ///
  /// This should be
  /// toCallingPage: () async {
  ///    ...
  ///    return Get.toNamed(CallingPage.name);
  /// }
  ///
  JackRTCService({
    required String socketUrl,
    required String myId,
    required Future<dynamic> Function() toCallingPage,
    required dynamic redirectToOffer,
  }) {
    socketData
      ..myUserId = myId
      ..socketUrl = socketUrl
      ..settingSocket();
    SocketServices.I.connectToServer(redirectToOffer);
    RTCMediaService.I.init();

    toRoute = toCallingPage;
    unawaited(CallKitVOIP.I.listenerEvent());
    CallKitVOIP.I.toRoute = toCallingPage;
  }

  final _socketServices = SocketServices();
  final _socketMediaService = SocketMediaService();
  final _miscSocketService = MiscSocketService();
  final _rtcMediaServices = RTCMediaService();
  final _rtcConnection = RTCConnections();

  // final dynamic redirectToOffers;

  // ------------------------ Connection and Disconnection ---------------------

  @override
  Future<void> disconnect() async {
    final socketData = SocketData();

    _socketServices.chatClose();

    /// ❌ Everytime you leave the chat conversation, dispose peer connection.
    await _rtcConnection.dispose();

    socketData
      ..socket?.disconnect()
      ..socket?.close()
      ..socket = null;
  }

  // void connect() {
  //   SocketServices.connectToServer(
  //     socketUrl: socketData.socketUrl,
  //     socketData: socketData,
  //   );
  //   RTCMediaService.init();
  // }

  // ------------------------ Media Services Section ---------------------

  // *************** Data Channel

  @override
  Future<void> sendMessage({
    required dynamic message,
    bool isBinary = false,
  }) async {
    await _rtcMediaServices.sendMessage(
      message: message,
      isBinary: isBinary,
    );
  }

  // *************** Media Calling

  @override
  Future<dynamic> mediaCall({
    required bool isVideoOn,
    required String callerName,
    String? callerHandle,
    String? callerAvatar,
  }) async {
    return await _rtcMediaServices.mediaCall(
      videoOn: isVideoOn,
      toRoute: toRoute,
      callerName: callerName,
      callerAvatar: callerAvatar,
      callerHandle: callerHandle,
    );
  }

  @override
  Future<void> acceptCall() async {
    await _rtcMediaServices.acceptCall(toRoute: toRoute);
  }

  @override
  Future<void> endCall({required bool isComesFromChat}) async {
    await _rtcMediaServices.callEnd();
    if (socketData.myCurrentCallPartnerId.isNotEmpty) {
      await _rtcConnection.dispose();
      _socketMediaService.endCallSocket();
    }
    if (isComesFromChat) {
      await _rtcConnection.checkAndReinitialize();
    }
  }

  @override
  Future<void> cancelCall() async {
    _socketMediaService.cancelCallSocket();
  }

  @protected
  static FutureOr<void> Function()? onListenDeclineCall;

  @protected
  static FutureOr<void> Function()? onListenCancelCall;

  @override
  void setAudio({required bool status}) {
    _rtcMediaServices.setAudioStatus(status: status);
  }

  @override
  void setVideo({required bool status}) {
    _rtcMediaServices.setVideoStatus(status: status);
  }

  @override
  void switchCamera() {
    unawaited(_rtcMediaServices.switchCamera());
  }

  @override
  Future<void> setSpeaker({required bool status}) async {
    await _rtcMediaServices.setSpeakerStatus(status: status);
  }

  @override
  Stream<(bool, bool, bool, bool, bool, bool)> mediaStatus() {
    return _rtcMediaServices.mediaStatus;
  }

  // ------------------------ CallKit Section ---------------------

  static Future<void> showIncomingCall({
    required String callerName,
    required String callerId,
    String? callerHandle,
    String? callerAvatar,
    int? duration,
    bool isVideo = false,
    void Function()? onCallDeepLink,
  }) async {
    if (onCallDeepLink != null) {
      CallKitVOIP.I.onCallDeepLink = onCallDeepLink;
      await CallKitVOIP.I.listenerEvent();
    }
    await CallKitVOIP.I.inComingCall(
      callerName: callerName,
      callerId: callerId,
      callerAvatar: callerAvatar,
      callerHandle: callerAvatar,
      duration: duration,
      isVideo: isVideo,
      // onCallDeepLink: onCallDeepLink,
    );
  }

  // ------------------------ Other Miscellaneous actions ---------------------

  @override
  Future<void> enterChatPage() async {
    if (!_rtcMediaServices.isCallingMedia.value) {
      /// ✅ Everytime you want to start communication, open connection
      await _rtcConnection.setupPeerConnection();
    }
    _socketServices.initializeRequest();
  }

  @override
  Future<void> leaveChatPage() async {
    if (!_rtcMediaServices.isCallingMedia.value) {
      _socketServices.chatClose();

      /// ❌ Everytime you leave the chat conversation, dispose peer connection.
      await _rtcConnection.dispose();
    }
  }

  @override
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
  }) {
    _rtcMediaServices
      ..onListenMessage = (message) {
        onListenMessage(message);
      }
      ..onPartnerCallEnded = onListenPartnerCallEnded;

    JackRTCService.onListenCancelCall = onListenPartnerCallCancel;

    _miscSocketService.isOnline.listen((value) {
      onListenOnline(
        _miscSocketService.id,
        isOnline: value,
      );
    });

    _miscSocketService.callerName.listen((value) {
      onListenCallerInfo(
        callerName: value,
        callHandler: _miscSocketService.callHandler,
        avatar: _miscSocketService.avatar,
      );
    });

    JackRTCService.onListenDeclineCall = onListenDeclineCall;
  }

  /// -------------

  @override
  ValueStream<RTCVideoRenderer?> get onLocalRTCMedia {
    return RTCMediaService.I.localRTCVideoRenderer.stream;
  }

  @override
  ValueStream<MediaStream?> get onLocalStream {
    return RTCMediaService.I.localStream.stream;
  }

  @override
  ValueStream<RTCVideoRenderer?> get onRemoteRTCMedia {
    return RTCMediaService.I.remoteRTCVideoRenderer.stream;
  }

  /// To change the chat id that I want
  void setMyCurrentChatId(String value) {
    socketData.myCurrentChatId = value;
  }

  String get getMyCurrentChatId {
    return socketData.myCurrentChatId;
  }

  String get getMyId {
    return socketData.myUserId;
  }

  /// To set status that have I SDP
  void setMyOwnSDP({required bool value}) {
    socketData.hasSDP = value;
  }
}
