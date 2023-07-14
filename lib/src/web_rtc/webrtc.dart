//
// Created by Jack Will on 28/06/2023.
// https://github.com/jackwill99
// This file is created for only public methods of class

// ignore_for_file: avoid_positional_boolean_parameters

import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/misc_socket.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";
import "package:jack_rtc_call/src/web_rtc/jack_rtc_data.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";
import "package:jack_rtc_call/src/web_rtc/rtc_base.dart";

class JackRTCService extends JackRTCData {
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
    if (!GetIt.I.isRegistered<SocketData>()) {
      debugPrint(
        "----------------------register sigalton ----------------------",
      );
      GetIt.I.registerSingleton<SocketData>(SocketData());
    }

    GetIt.instance<SocketData>()
      ..myUserId = myId
      ..socketUrl = socketUrl
      ..settingSocket();
    SocketServices.connectToServer(redirectToOffer);
    RTCMediaService.init();

    toRoute = toCallingPage;
    unawaited(CallKitVOIP.listenerEvent());
    CallKitVOIP.toRoute = toCallingPage;
  }
  // final dynamic redirectToOffers;

  // ------------------------ Connection and Disconnection ---------------------
  Future<void> disconnect() async {
    final socketData = GetIt.instance<SocketData>();

    SocketServices.chatClose();

    /// ❌ Everytime you leave the chat conversation, dispose peer connection.
    await RTCConnections.dispose();

    socketData
      ..socket.disconnect()
      ..socket.close()
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

  Future<void> sendMessage({
    required dynamic message,
    bool isBinary = false,
  }) async {
    await RTCMediaService.sendMessage(
      message: message,
      isBinary: isBinary,
    );
  }

  // *************** Media Calling

  /// `callerName` is the name of the caller to display
  ///
  /// `callerHandle` may be email or phone number or None
  ///
  /// `callerAvatar` works only in Android to show the avatar of the caller profile
  ///
  Future<dynamic> mediaCall({
    required bool isVideoOn,
    required String callerName,
    String? callerHandle,
    String? callerAvatar,
  }) async {
    return await RTCMediaService.mediaCall(
      videoOn: isVideoOn,
      toRoute: toRoute,
      callerName: callerName,
      callerAvatar: callerAvatar,
      callerHandle: callerHandle,
    );
  }

  Future<void> acceptCall() async {
    await RTCMediaService.acceptCall(toRoute: toRoute);
  }

  Future<void> endCall(bool isComesFromChat) async {
    final socketData = GetIt.instance<SocketData>();

    await RTCMediaService.callEnd();
    if (socketData.myCurrentCallPartnerId.isNotEmpty) {
      await RTCConnections.dispose();
      SocketMediaService.endCallSocket();
    }
    if (isComesFromChat) {
      await RTCConnections.checkAndReinitialize();
    }
  }

  Future<void> cancelCall() async {
    SocketMediaService.cancelCallSocket();
  }

  @protected
  static FutureOr<void> Function()? onListenDeclineCall;

  @protected
  static FutureOr<void> Function()? onListenCancelCall;

  void setAudio(bool status) {
    RTCMediaService.setAudioStatus(status);
  }

  void setVideo(bool status) {
    RTCMediaService.setVideoStatus(status);
  }

  void switchCamera() {
    unawaited(RTCMediaService.switchCamera());
  }

  Future<void> setSpeaker(bool status) async {
    await RTCMediaService.setSpeakerStatus(status);
  }

  /// `isJoinedCallingMedia, isAudioOn, isVideoOn, isFrontCamera, isPartnerVideoOpen, isSpeakerOn`
  Stream<(bool, bool, bool, bool, bool, bool)> mediaStatus() {
    return RTCMediaService.mediaStatus;
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
      CallKitVOIP.onCallDeepLink = onCallDeepLink;
      await CallKitVOIP.listenerEvent();
    }
    await CallKitVOIP.inComingCall(
      callerName: callerName,
      callerId: callerId,
      callerAvatar: callerAvatar,
      callerHandle: callerAvatar,
      duration: duration,
      isVideo: isVideo,
      onCallDeepLink: onCallDeepLink,
    );
  }

  // ------------------------ Other Miscellaneous actions ---------------------

  Future<void> enterChatPage() async {
    if (!RTCMediaService.isCallingMedia.value) {
      /// ✅ Everytime you want to start communication, open connection
      await RTCConnections.setupPeerConnection();
    }
    SocketServices.initializeRequest();
  }

  Future<void> leaveChatPage() async {
    if (!RTCMediaService.isCallingMedia.value) {
      SocketServices.chatClose();

      /// ❌ Everytime you leave the chat conversation, dispose peer connection.
      await RTCConnections.dispose();
    }
  }

  void onListenMiscState({
    required Function(RTCDataChannelMessage message) onListenMessage,
    required void Function() onListenPartnerCallEnded,
    required void Function(bool isOnline, String? id) onListenOnline,
    required FutureOr<void> Function() onListenPartnerCallCancel,
    required FutureOr<void> Function() onListenDeclineCall,
    required void Function({
      String? callerName,
      String? callHandler,
      String? avatar,
    }) onListenCallerInfo,
  }) {
    RTCMediaService.onListenMessage = (message) {
      onListenMessage(message);
    };

    RTCMediaService.onPartnerCallEnded = onListenPartnerCallEnded;

    JackRTCService.onListenCancelCall = onListenPartnerCallCancel;

    MiscSocketService.isOnline.listen((value) {
      onListenOnline(value, MiscSocketService.id);
    });

    MiscSocketService.callerName.listen((value) {
      onListenCallerInfo(
        callerName: value,
        callHandler: MiscSocketService.callHandler,
        avatar: MiscSocketService.avatar,
      );
    });

    JackRTCService.onListenDeclineCall = onListenDeclineCall;
  }

  /// -------------

  /// To change the chat id that I want
  void setMyCurrentChatId(String value) {
    GetIt.instance<SocketData>().myCurrentChatId = value;
  }

  String get getMyCurrentChatId {
    final socketData = GetIt.instance<SocketData>();
    return socketData.myCurrentChatId;
  }

  String get getMyId {
    final socketData = GetIt.instance<SocketData>();
    return socketData.myUserId;
  }

  /// To set status that have I SDP
  void setMyOwnSDP(bool value) {
    GetIt.instance<SocketData>().hasSDP = value;
  }
}
