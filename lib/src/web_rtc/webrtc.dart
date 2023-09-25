//
// Created by Jack Will on 28/06/2023.
// https://github.com/jackwill99
// This file is created for only public methods of class

import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/misc_socket.dart";
import "package:jack_rtc_call/src/socket/socket_media_services.dart";
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
    SocketServices.I.connectToServer(redirectToOffer);
    RTCMediaService.I.init();

    toRoute = toCallingPage;
    unawaited(CallKitVOIP.I.listenerEvent());
    CallKitVOIP.I.toRoute = toCallingPage;
  }

  final callKitVoip = CallKitVOIP();
  final socketServices = SocketServices();
  final socketMediaService = SocketMediaService();
  final miscSocketService = MiscSocketService();
  final rtcMediaServices = RTCMediaService();
  final rtcConnection = RTCConnections();

  // final dynamic redirectToOffers;

  // ------------------------ Connection and Disconnection ---------------------
  Future<void> disconnect() async {
    final socketData = GetIt.instance<SocketData>();

    socketServices.chatClose();

    /// ❌ Everytime you leave the chat conversation, dispose peer connection.
    await rtcConnection.dispose();

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
    await rtcMediaServices.sendMessage(
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
    return await rtcMediaServices.mediaCall(
      videoOn: isVideoOn,
      toRoute: toRoute,
      callerName: callerName,
      callerAvatar: callerAvatar,
      callerHandle: callerHandle,
    );
  }

  Future<void> acceptCall() async {
    await rtcMediaServices.acceptCall(toRoute: toRoute);
  }

  Future<void> endCall({required bool isComesFromChat}) async {
    final socketData = GetIt.instance<SocketData>();

    await rtcMediaServices.callEnd();
    if (socketData.myCurrentCallPartnerId.isNotEmpty) {
      await rtcConnection.dispose();
      socketMediaService.endCallSocket();
    }
    if (isComesFromChat) {
      await rtcConnection.checkAndReinitialize();
    }
  }

  Future<void> cancelCall() async {
    socketMediaService.cancelCallSocket();
  }

  @protected
  static FutureOr<void> Function()? onListenDeclineCall;

  @protected
  static FutureOr<void> Function()? onListenCancelCall;

  void setAudio({required bool status}) {
    rtcMediaServices.setAudioStatus(status: status);
  }

  void setVideo({required bool status}) {
    rtcMediaServices.setVideoStatus(status: status);
  }

  void switchCamera() {
    unawaited(rtcMediaServices.switchCamera());
  }

  Future<void> setSpeaker({required bool status}) async {
    await rtcMediaServices.setSpeakerStatus(status: status);
  }

  /// `isJoinedCallingMedia, isAudioOn, isVideoOn, isFrontCamera, isPartnerVideoOpen, isSpeakerOn`
  Stream<(bool, bool, bool, bool, bool, bool)> mediaStatus() {
    return rtcMediaServices.mediaStatus;
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

  Future<void> enterChatPage() async {
    if (!rtcMediaServices.isCallingMedia.value) {
      /// ✅ Everytime you want to start communication, open connection
      await rtcConnection.setupPeerConnection();
    }
    socketServices.initializeRequest();
  }

  Future<void> leaveChatPage() async {
    if (!rtcMediaServices.isCallingMedia.value) {
      socketServices.chatClose();

      /// ❌ Everytime you leave the chat conversation, dispose peer connection.
      await rtcConnection.dispose();
    }
  }

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
    rtcMediaServices
      ..onListenMessage = (message) {
        onListenMessage(message);
      }
      ..onPartnerCallEnded = onListenPartnerCallEnded;

    JackRTCService.onListenCancelCall = onListenPartnerCallCancel;

    miscSocketService.isOnline.listen((value) {
      onListenOnline(
        miscSocketService.id,
        isOnline: value,
      );
    });

    miscSocketService.callerName.listen((value) {
      onListenCallerInfo(
        callerName: value,
        callHandler: miscSocketService.callHandler,
        avatar: miscSocketService.avatar,
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
  void setMyOwnSDP({required bool value}) {
    GetIt.instance<SocketData>().hasSDP = value;
  }
}
