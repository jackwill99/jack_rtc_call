//
// Created by Jack Will on 21/06/2023.
// https://github.com/jackwill99
//

// ignore_for_file: avoid_positional_boolean_parameters

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
// ignore: implementation_imports
import "package:flutter_webrtc/src/native/factory_impl.dart" as Navigator;
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";
import "package:jack_rtc_call/src/web_rtc/rtc_base.dart";
import "package:rxdart/rxdart.dart";

@protected
class RTCMediaService {
  RTCMediaService._();

  // videoRenderer for localPeer
  //! check it that can listen when we set `srcObject`
  static final localRTCVideoRenderer = BehaviorSubject<RTCVideoRenderer>();

  // mediaStream for localPeer
  static final localStream = BehaviorSubject<MediaStream?>();

  // videoRenderer for remotePeer
  static final remoteRTCVideoRenderer = BehaviorSubject<RTCVideoRenderer>();

  /// data channel
  static RTCDataChannel? channel;

  // tempMessage
  static final tempMessages = <RTCDataChannelMessage>[];

  static late Function(RTCDataChannelMessage message) onListenMessage;

  static late Function() onPartnerCallEnded;

  static void init() {
    localRTCVideoRenderer.add(RTCVideoRenderer());
    remoteRTCVideoRenderer.add(RTCVideoRenderer());

    isCallingMedia.add(false);
    isAudioOn.add(true);
    isVideoOn.add(false);
    isFrontCamera.add(true);
    isPartnerVideoOpen.add(false);
    isSpeakerOn.add(false);
  }

  /// --------------------------Media status--------------------------

  static final isCallingMedia = BehaviorSubject<bool>();
  static final isAudioOn = BehaviorSubject<bool>();
  static final isVideoOn = BehaviorSubject<bool>();
  static final isFrontCamera = BehaviorSubject<bool>();
  static final isJoinedCallingMedia = BehaviorSubject<bool>.seeded(false);
  static final isPartnerVideoOpen = BehaviorSubject<bool>();
  static final isSpeakerOn = BehaviorSubject<bool>();

  static Stream<(bool, bool, bool, bool, bool, bool)> get mediaStatus {
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

  static void setAudioStatus(bool status) {
    isAudioOn.add(status);
    // enable or disable audio track
    localStream.value!.getAudioTracks().forEach((track) {
      track.enabled = status;
    });
  }

  static void setVideoStatus(bool status) {
    isVideoOn.add(status);
    localStream.value!.getVideoTracks().forEach((track) {
      track.enabled = status;
    });
    SocketMediaService.videoMutedSocket(status);
  }

  static Future<void> switchCamera() async {
    isFrontCamera.add(!isFrontCamera.value);
    // switch camera
    localStream.value!.getVideoTracks().forEach((track) async {
      await Helper.switchCamera(track);
    });
  }

  static Future<void> setSpeakerStatus(
    bool status,
  ) async {
    isSpeakerOn.add(status);
    debugPrint(
      "----------------------change speaker $status----------------------",
    );

    await Helper.setSpeakerphoneOn(status);
  }

  /// Data Channel

  static Future<void> sendMessage({
    required dynamic message,
    bool isBinary = false,
  }) async {
    final socketData = GetIt.instance<SocketData>();

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
        socketData.socket.emit("exchangeSDPOffer", {
          "to": socketData.myCurrentChatId,
          "offer": offer.toMap(),
        });
        debugPrint("Create Offer ======================");
      }
      if (RTCConnections.getRTCPeerConnection.connectionState !=
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        tempMessages.add(RTCDataChannelMessage(message));
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

  /// Media Call Action -----------------------

  static Future<void> setupMediaCall({
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
    RTCConnections.getRTCPeerConnection.onTrack = (event) async {
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
      await setSpeakerStatus(false);
      debugPrint(
        "----------------------speaker with false default----------------------",
      );
    } else {
      setVideoStatus(false);
      await setSpeakerStatus(false);
    }

    // set source for local video renderer
    // localRTCVideoRenderer.value.srcObject = localStream.value;
    final tempRemoteRenderer = RTCVideoRenderer();
    await tempRemoteRenderer.initialize();
    tempRemoteRenderer.srcObject = localStream.value;
    localRTCVideoRenderer.add(tempRemoteRenderer);
    // add mediaTrack to peerConnection
    localStream.value!.getTracks().forEach((track) {
      RTCConnections.getRTCPeerConnection.addTrack(track, localStream.value!);
    });
  }

  /// You should return true when not ending the media calling
  static Future<dynamic> mediaCall({
    required bool videoOn,
    required Future<dynamic> Function() toRoute,
    required String callerName,
    String? callerHandle,
    String? callerAvatar,
  }) async {
    final socketData = GetIt.instance<SocketData>();
    RTCSessionDescription? offer;

    debugPrint(
      "---------------------${isCallingMedia.value}---in media call-------------------",
    );
    if (!isCallingMedia.value) {
      isCallingMedia.add(true);
      await RTCConnections.restartConnections();

      await setupMediaCall(videoOn: videoOn);

      offer = await onListenMessageService(
        onMessage: (message) {
          onListenMessage(message);
        },
      );

      //! From Client 1
      socketData.socket.emit("makeCall", {
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

  static Future<void> acceptCall({
    required Future<dynamic> Function() toRoute,
    dynamic offer,
  }) async {
    final socketData = GetIt.instance<SocketData>();

    await RTCConnections.restartConnections();

    // data channel
    RTCConnections.getRTCPeerConnection.onDataChannel = (ch) {
      channel = ch
        ..onDataChannelState = (state) {
          onDataChannelService(state: state);
        }
        ..onMessage = (message) {
          onListenMessage(message);
        };
    };

    final partnerOffer =
        (offer ?? socketData.tempOffer) as Map<String, dynamic>;

    /// media call
    await setupMediaCall(
      videoOn: partnerOffer["video"],
    );

    SocketMediaService.videoMutedSocket(
      partnerOffer["video"],
    );

    // create SDP answer
    final answer = await RTCConnections.createAnswer(
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
    await SocketMediaService.acceptCallSocket(answer);

    await toRoute();

    if (partnerOffer["video"]) {
      await setSpeakerStatus(true);
    }
  }

  static Future<void> callEnd() async {
    localStream.value?.getTracks().forEach((track) async {
      await track.stop();
    });
    await RTCMediaService.setSpeakerStatus(false);

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
    await CallKitVOIP.callEnd();
  }

  static Future<void> _setUpInitialize() async {
    await localRTCVideoRenderer.value.initialize();
    await remoteRTCVideoRenderer.value.initialize();
  }

  /// Listening Methods

  static Future<RTCSessionDescription> onListenMessageService({
    required void Function(RTCDataChannelMessage message) onMessage,
  }) async {
    final socketData = GetIt.instance<SocketData>();

    // listening data channel
    channel = await RTCConnections.getRTCPeerConnection.createDataChannel(
      "dataChannel-${123456}",
      RTCDataChannelInit()..id = int.parse("123456"),
    );
    channel!.onDataChannelState = (state) {
      onDataChannelService(state: state);
    };

    channel!.onMessage = (data) {
      onMessage(data);
    };

    final offer = await RTCConnections.createOffer();
    socketData.hasSDP = true;
    return offer;
  }

  static Future<void> onDataChannelService({
    required RTCDataChannelState state,
  }) async {
    final socketData = GetIt.instance<SocketData>();

    if (state == RTCDataChannelState.RTCDataChannelOpen) {
      if (tempMessages.isNotEmpty) {
        for (final i in tempMessages) {
          await channel!.send(i);
        }
        tempMessages.clear();
      }
    }

    debugPrint("---------------datachannel-------$state----------------------");
    // TODO(jackwill): Need disconnect socket to notify the other client
    if (state == RTCDataChannelState.RTCDataChannelClosed) {
      socketData
        ..partnerCurrentChatId = ""
        ..partnerHasSDP = false;

      isCallingMedia.value = false;
      await RTCConnections.restartConnections();
    }
  }
}
