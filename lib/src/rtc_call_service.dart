//
// Created by Jack Will on 28/06/2023.
// https://github.com/jackwill99
// This file is created for only public methods of class

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:jack_rtc_call/callkit/callkit.dart';
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
  }) {
    SocketServices.connectToServer(
        socketUrl: socketUrl, myId: myId, socketData: socketData);
    RTCMediaService.init();
    RTCMediaService.onListenMessage = (message) {
      onListenMessage(message);
    };
    toRoute = toCallingPage;

    CallKitVOIP.listenerEvent(socketData: socketData, toRoute: toCallingPage);
  }

  // ------------------------ Media Services Section ---------------------

  // *************** Data Channel

  Future<void> sendMessage(
      {required dynamic message, required bool isBinary}) async {
    await RTCMediaService.sendMessage(
      socketData: socketData,
      message: message,
      isBinary: isBinary,
    );
  }

  // *************** Media Calling
  Future<void> mediaCall(bool isVideoOn) async {
    await RTCMediaService.mediaCall(
      videoOn: isVideoOn,
      socketData: socketData,
      toRoute: toRoute,
    );
  }

  Future<void> acceptCall() async {
    await RTCMediaService.acceptCall(socketData: socketData, toRoute: toRoute);
  }

  Future<void> endCall(bool isComesFromChat) async {
    await RTCMediaService.callEnd();
    if (socketData.myCurrentCallPartnerId.isNotEmpty) {
      await RTCConnections.dispose();
      SocketMediaService.endCallSocket(socketData);
    }
    if (isComesFromChat) {
      RTCConnections.checkAndReinitialize(socketData);
    }
  }

  void setAudio(bool status) {
    RTCMediaService.setAudioStatus(status);
  }

  void setVideo(bool status) {
    RTCMediaService.setVideoStatus(status, socketData);
  }

  void switchCamera() {
    RTCMediaService.switchCamera();
  }

  void setSpeaker(bool status) {
    RTCMediaService.setSpeakerStatus(status, socketData);
  }

  /// `isCallingMedia, isAudioOn, isVideoOn, isFrontCamera, isPartnerVideoOpen`
  Stream<(bool, bool, bool, bool, bool)> mediaStatus() {
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
  }) async =>
      CallKitVOIP.inComingCall;

  // ------------------------ Other Miscellaneous actions ---------------------

  Future<void> enterChatPage() async {
    if (!RTCMediaService.isCallingMedia.value) {
      /// ✅ Everytime you want to start communication, open connection
      await RTCConnections.setupPeerConnection();
    }
    SocketServices.initializeRequest(socketData: socketData);
  }

  Future<void> leaveChatPage() async {
    if (!RTCMediaService.isCallingMedia.value) {
      SocketServices.chatClose(socketData: socketData);

      /// ❌ Everytime you leave the chat conversation, dispose peer connection.
      await RTCConnections.dispose();
    }
  }
}
