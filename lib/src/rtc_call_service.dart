//
// Created by Jack Will on 28/06/2023.
// https://github.com/jackwill99
// This file is created for only public methods of class

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_it/get_it.dart';
import 'package:jack_rtc_call/callkit/callkit.dart';
import 'package:jack_rtc_call/socket/misc_socket.dart';
import 'package:jack_rtc_call/socket/socket_services.dart';
import 'package:jack_rtc_call/src/jack_rtc_data.dart';
import 'package:jack_rtc_call/web_rtc/media_services.dart';
import 'package:jack_rtc_call/web_rtc/rtc.dart';

class JackRTCCallService extends JackRTCData {
  ///
  /// `toCallingPage` is route for calling page
  ///
  /// This should be
  /// toCallingPage: () async {
  ///    ...
  ///    return Get.toNamed(CallingPage.name);
  /// }
  ///
  JackRTCCallService({
    required String socketUrl,
    required String myId,
    required Future<dynamic> Function() toCallingPage,
    required Function(RTCDataChannelMessage message) onListenMessage,
    required void Function() onListenPartnerCallEnded,
  }) {
    if (!GetIt.I.isRegistered<SocketData>()) {
      debugPrint(
          "----------------------register sigalton ----------------------");
      GetIt.I.registerSingleton<SocketData>(SocketData());
    }

    final socketData = GetIt.instance<SocketData>();

    socketData.myUserId = myId;
    socketData.socketUrl = socketUrl;
    socketData.settingSocket();
    SocketServices.connectToServer();
    RTCMediaService.init();
    RTCMediaService.onListenMessage = (message) {
      onListenMessage(message);
    };
    RTCMediaService.onPartnerCallEnded = onListenPartnerCallEnded;
    toRoute = toCallingPage;
    CallKitVOIP.toRoute = toCallingPage;
    CallKitVOIP.listenerEvent();
  }

  // ------------------------ Connection and Disconnection ---------------------
  Future<void> disconnect() async {
    final socketData = GetIt.instance<SocketData>();

    SocketServices.chatClose();

    /// ❌ Everytime you leave the chat conversation, dispose peer connection.
    await RTCConnections.dispose();

    socketData.getSocket.disconnect();
    socketData.getSocket.close();
    socketData.setSocket = null;
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

  Future<void> sendMessage(
      {required dynamic message, bool isBinary = false}) async {
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
  Future<void> mediaCall({
    required bool isVideoOn,
    required String callerName,
    String? callerHandle,
    String? callerAvatar,
  }) async {
    await RTCMediaService.mediaCall(
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
      RTCConnections.checkAndReinitialize();
    }
  }

  Future<void> navigationCallingPage() async {
    CallKitVOIP.checkAndNavigationCallingPage();
  }

  static FutureOr<void> Function()? onListenDeclineCall;

  void setAudio(bool status) {
    RTCMediaService.setAudioStatus(status);
  }

  void setVideo(bool status) {
    RTCMediaService.setVideoStatus(status);
  }

  void switchCamera() {
    RTCMediaService.switchCamera();
  }

  Future<void> setSpeaker(bool status) async {
    await RTCMediaService.setSpeakerStatus(status);
  }

  /// `isCallingMedia, isAudioOn, isVideoOn, isFrontCamera, isPartnerVideoOpen, isSpeakerOn`
  Stream<(bool, bool, bool, bool, bool, bool)> mediaStatus() {
    return RTCMediaService.mediaStatus;
  }

  // ------------------------ CallKit Section ---------------------

  Future<void> showIncomingCall({
    required String callerName,
    required String callerId,
    String? callerHandle,
    String? callerAvatar,
    int? duration,
    bool isVideo = false,
  }) async {
    await CallKitVOIP.inComingCall(
      callerName: callerName,
      callerId: callerId,
      callerAvatar: callerAvatar,
      callerHandle: callerAvatar,
      duration: duration,
      isVideo: isVideo,
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

  void listenMiscData({
    required void Function(bool isOnline, String? id) onListenOnline,
    required FutureOr<void> Function() onListenDeclineCall,
    required void Function({
      String? callerName,
      String? callHandler,
      String? avatar,
    }) onListenCallerInfo,
  }) {
    MiscSocketService.isOnline.listen((value) {
      onListenOnline(value, MiscSocketService.id);
    });

    MiscSocketService.callerName.listen((value) {
      onListenCallerInfo(
        callerName: value,
        callHandler: MiscSocketService.callHandler,
        avatar: MiscSocketService.avatar,
      );

      JackRTCCallService.onListenDeclineCall = onListenDeclineCall;
    });
  }

  /// -------------

  /// To change the chat id that I want
  void setMyCurrentChatId(String value) {
    final socketData = GetIt.instance<SocketData>();
    socketData.myCurrentChatId = value;
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
    final socketData = GetIt.instance<SocketData>();
    socketData.hasSDP = value;
  }
}
