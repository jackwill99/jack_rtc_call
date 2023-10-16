//
// Created by Jack Will on 21/06/2023.
// https://github.com/jackwill99
//

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:flutter_webrtc/src/native/factory_impl.dart" as Navigator;
import "package:jack_rtc_call/model/web_rtc/media_services_abstract.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/socket_media_services.dart";
import "package:rxdart/rxdart.dart";

@protected
class RTCMediaService extends RTCMediaServiceAbstract {
  factory RTCMediaService() {
    return I;
  }

  RTCMediaService._();

  static final RTCMediaService I = RTCMediaService._();

  @override
  void init() {
    localRTCVideoRenderer.add(RTCVideoRenderer());
    remoteRTCVideoRenderer.add(RTCVideoRenderer());

    isCallingMedia.add(false);
    isAudioOn.add(true);
    isVideoOn.add(false);
    isFrontCamera.add(true);
    isPartnerVideoOpen.add(false);
    isSpeakerOn.add(false);
  }

  @override
  Stream<(bool, bool, bool, bool, bool, bool)> get mediaStatus {
    return Rx.combineLatest6<bool, bool, bool, bool, bool, bool,
        (bool, bool, bool, bool, bool, bool)>(
      isJoinedCallingMedia.stream,
      isAudioOn.stream,
      isVideoOn.stream,
      isFrontCamera.stream,
      isPartnerVideoOpen.stream,
      isSpeakerOn.stream,
      (
        isJoinedCallingMedia,
        isAudioOn,
        isVideoOn,
        isFrontCamera,
        isPartnerVideoOpen,
        isSpeakerOn,
      ) =>
          (
        isJoinedCallingMedia,
        isAudioOn,
        isVideoOn,
        isFrontCamera,
        isPartnerVideoOpen,
        isSpeakerOn,
      ),
    );
  }

  @override
  void setAudioStatus({required bool status}) {
    isAudioOn.add(status);
    // enable or disable audio track
    localStream.value!.getAudioTracks().forEach((track) {
      track.enabled = status;
    });
  }

  @override
  void setVideoStatus({required bool status}) {
    isVideoOn.add(status);
    localStream.value!.getVideoTracks().forEach((track) {
      track.enabled = status;
    });
    SocketMediaService.I.videoMutedSocket(status: status);
  }

  @override
  Future<void> switchCamera() async {
    isFrontCamera.add(!isFrontCamera.value);
    // switch camera
    localStream.value!.getVideoTracks().forEach((track) async {
      await Helper.switchCamera(track);
    });
  }

  @override
  Future<void> setSpeakerStatus({
    required bool status,
  }) async {
    isSpeakerOn.add(status);
    debugPrint(
      "----------------------change speaker $status----------------------",
    );

    await Helper.setSpeakerphoneOn(status);
  }

  /// --------------------- Data Channel ------------------

  @override
  Future<void> sendMessage({
    required dynamic message,
    bool isBinary = false,
  }) async {
    debugPrint(
      "----------send partner chat id------------${socketData.partnerCurrentChatId}----------------------",
    );

    if (socketData.myUserId == socketData.partnerCurrentChatId) {
      if (socketData.partnerHasSDP && socketData.hasSDP) {
        debugPrint("in Chat -----------------------");
      } else {
        final offer = await onListenMessageService(
          onMessage: (message) {
            onListenMessage(message);
          },
        );

        //! From Client 1
        socketData.socket?.emit("exchangeSDPOffer", {
          "to": socketData.myCurrentChatId,
          "offer": offer.toMap(),
        });
        debugPrint("Create Offer ======================");
      }
      if (rtcConnection.getRTCPeerConnection.connectionState !=
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        tempMessages.add(
          isBinary
              ? RTCDataChannelMessage.fromBinary(message)
              : RTCDataChannelMessage(message),
        );
      }
      await channel!.send(
        isBinary
            ? RTCDataChannelMessage.fromBinary(message)
            : RTCDataChannelMessage(message),
      );
      debugPrint("----------------------sent----------------------");
    } else {
      debugPrint("Normal Mesage =======================");
      // TODO(jackwill): send message to server
    }
  }

  /// --------------------- Media Call Action ------------------

  @override
  Future<void> setupMediaCall({
    bool audioOn = true,
    bool videoOn = false,
    bool frontCameraOn = true,
  }) async {
    isAudioOn.add(audioOn);
    isVideoOn.add(videoOn);
    isFrontCamera.add(frontCameraOn);
    isPartnerVideoOpen.add(videoOn);
    await _setUpInitialize();

    // listen for remotePeer mediaTrack event
    rtcConnection.getRTCPeerConnection.onTrack = (event) async {
      final tempRemoteRenderer = RTCVideoRenderer();
      await tempRemoteRenderer.initialize();
      tempRemoteRenderer.srcObject = event.streams[0];
      remoteRTCVideoRenderer.add(tempRemoteRenderer);
      // final remoteRenderer = await remoteRTCVideoRenderer.first;
      // remoteRenderer.srcObject = event.streams[0];
      debugPrint(
        "-----------streams in setupMediaCall-----------${remoteRTCVideoRenderer.value.srcObject}----------------------",
      );
      debugPrint(
        "----------------------${event.streams[0]}----------------------",
      );
    };

    // get localStream
    localStream.value = await Navigator.mediaDevices.getUserMedia({
      "audio": audioOn,
      "video": {
        "facingMode": frontCameraOn ? "user" : "environment",
      },
    });

    // To turn off the local stream video
    if (videoOn) {
      /// set to default speaker false
      await setSpeakerStatus(status: false);
      debugPrint(
        "----------------------speaker with false default----------------------",
      );
    } else {
      setVideoStatus(status: false);
      await setSpeakerStatus(status: false);
    }

    // set source for local video renderer
    // localRTCVideoRenderer.value.srcObject = localStream.value;
    final tempRemoteRenderer = RTCVideoRenderer();
    await tempRemoteRenderer.initialize();
    tempRemoteRenderer.srcObject = localStream.value;
    localRTCVideoRenderer.add(tempRemoteRenderer);
    // add mediaTrack to peerConnection
    localStream.value!.getTracks().forEach((track) {
      rtcConnection.getRTCPeerConnection.addTrack(track, localStream.value!);
    });
  }

  /// You should return true when not ending the media calling
  @override
  Future<dynamic> mediaCall({
    required bool videoOn,
    required Future<dynamic> Function() toRoute,
    required String callerName,
    String? callerHandle,
    String? callerAvatar,
  }) async {
    RTCSessionDescription? offer;

    debugPrint(
      "---------------------${isCallingMedia.value}---in media call-------------------",
    );
    if (!isCallingMedia.value) {
      isCallingMedia.add(true);
      await rtcConnection.restartConnections();

      await setupMediaCall(videoOn: videoOn);

      offer = await onListenMessageService(
        onMessage: (message) {
          onListenMessage(message);
        },
      );

      //! From Client 1
      socketData.socket?.emit("makeCall", {
        "to": socketData.myCurrentChatId,
        "offer": offer.toMap(),
        "video": videoOn,
        "callerName": callerName,
        "callerHandle": callerHandle,
        "callerAvatar": callerAvatar,
      });

      debugPrint("Create Offer video ======================");
    }
    await toRoute();

    return offer?.toMap();
  }

  @override
  Future<void> acceptCall({
    required Future<dynamic> Function() toRoute,
    dynamic offer,
  }) async {
    await rtcConnection.restartConnections();

    // data channel
    rtcConnection.getRTCPeerConnection.onDataChannel = (ch) {
      channel = ch
        ..onDataChannelState = (state) {
          onDataChannelService(state: state);
        }
        ..onMessage = (message) {
          onListenMessage(message);
        };
    };

    late Map<String, dynamic> partnerOffer;
    if (offer == null) {
      partnerOffer = socketData.tempOffer;
    } else {
      partnerOffer = offer;
      socketData.tempOffer = offer;
    }

    /// media call
    await setupMediaCall(
      videoOn: partnerOffer["video"],
    );

    SocketMediaService.I.videoMutedSocket(
      status: partnerOffer["video"],
    );

    // create SDP answer
    final answer = await rtcConnection.createAnswer(
      offerSDP: (partnerOffer["offer"] as Map<String, dynamic>)["sdp"],
      type: (partnerOffer["offer"] as Map<String, dynamic>)["type"],
    );

    socketData
      ..hasSDP = true
      ..partnerHasSDP = true
      ..myCurrentCallPartnerId = partnerOffer["from"];

    isCallingMedia.add(true);
    isJoinedCallingMedia.add(true);

    //* call socket
    await SocketMediaService.I.acceptCallSocket(answer);

    await toRoute();

    if (partnerOffer["video"]) {
      await setSpeakerStatus(status: true);
    }
  }

  @override
  Future<void> callEnd() async {
    localStream.value?.getTracks().forEach((track) async {
      await track.stop();
    });
    await setSpeakerStatus(status: false);

    await localStream.value?.dispose();
    localStream.value = null;
    localRTCVideoRenderer.value.srcObject = null;
    remoteRTCVideoRenderer.value.srcObject = null;
    await localRTCVideoRenderer.value.dispose();
    await remoteRTCVideoRenderer.value.dispose();
    localRTCVideoRenderer.add(RTCVideoRenderer());
    remoteRTCVideoRenderer.add(RTCVideoRenderer());
    isCallingMedia.add(false);
    isJoinedCallingMedia.add(false);
    await CallKitVOIP.I.callEnd();
  }

  Future<void> _setUpInitialize() async {
    await localRTCVideoRenderer.value.initialize();
    await remoteRTCVideoRenderer.value.initialize();
  }

  /// --------------------- Listening Methods ------------------

  @override
  Future<RTCSessionDescription> onListenMessageService({
    required void Function(RTCDataChannelMessage message) onMessage,
  }) async {
    // listening data channel
    channel = await rtcConnection.getRTCPeerConnection.createDataChannel(
      "dataChannel-${123456}",
      RTCDataChannelInit()..id = int.parse("123456"),
    );
    channel!.onDataChannelState = (state) {
      onDataChannelService(state: state);
    };

    channel!.onMessage = (data) {
      onMessage(data);
    };

    final offer = await rtcConnection.createOffer();
    socketData.hasSDP = true;
    return offer;
  }

  @override
  Future<void> onDataChannelService({
    required RTCDataChannelState state,
  }) async {
    if (state == RTCDataChannelState.RTCDataChannelOpen) {
      if (tempMessages.isNotEmpty) {
        for (final i in tempMessages) {
          await channel!.send(i);
        }
        tempMessages.clear();
      }
    }

    debugPrint(
      "---------------data channel-------$state----------------------",
    );
    // TODO(jack-will): Need disconnect socket to notify the other client
    if (state == RTCDataChannelState.RTCDataChannelClosed) {
      socketData
        ..partnerCurrentChatId = ""
        ..partnerHasSDP = false;

      isCallingMedia.value = false;
      await rtcConnection.restartConnections();
    }
  }
}
