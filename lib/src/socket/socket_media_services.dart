import "package:flutter/foundation.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/jack_rtc_call.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/misc_socket.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";
import "package:jack_rtc_call/src/web_rtc/rtc_base.dart";

@protected
class SocketMediaService {
  factory SocketMediaService() {
    return I;
  }

  SocketMediaService._();

  static final SocketMediaService I = SocketMediaService._();

  void initializeMedia() {
    final socketData = GetIt.instance<SocketData>();

    //! For Client 1 / Media Call
    socketData.socket.on("callAnswered", (data) async {
      await socketSDPAnswer(data: data, isVideo: true);
      socketData.myCurrentCallPartnerId =
          (data as Map<String, dynamic>)["from"];
    });

    //! For Client 2 / MediaCall
    socketData.socket.on("newCall", (data) async {
      debugPrint("----------------------new call-------$data---------------");
      socketData.tempOffer = data as Map<String, dynamic>;
      await CallKitVOIP.I.inComingCall(
        callerName: data["callerName"],
        callerId: data["from"],
        isVideo: data["video"],
        callerHandle: data["callerHandle"],
        callerAvatar: data["callerAvatar"],
      );

      MiscSocketService.I
        ..callHandler = data["callerHandle"]
        ..avatar = data["callerAvatar"]
        ..callerName.add(data["callerName"]);
    });

    socketData.socket.on("callEndNotify", (data) {
      socketData
        ..hasSDP = false
        ..myCurrentCallPartnerId = "";
      RTCMediaService.I.onPartnerCallEnded();
    });

    socketData.socket.on("declineCallNotify", (data) async {
      JackRTCService.onListenDeclineCall?.call();
    });

    socketData.socket.on("callCancelNotify", (data) async {
      await CallKitVOIP.I.callEnd();
      JackRTCService.onListenCancelCall?.call();
    });

    socketData.socket.on("missedCallNotify", (data) async {});
    socketData.socket.on("videoMutedNotify", (data) async {
      RTCMediaService.I.isPartnerVideoOpen
          .add((data as Map<String, dynamic>)["status"]);
    });
    socketData.socket.on("videoRequestNotify", (data) async {});
  }

  Future<void> socketSDPAnswer({
    required Map<String, dynamic> data,
    bool isVideo = false,
  }) async {
    final socketData = GetIt.instance<SocketData>();

    debugPrint(
      "---------------just-------${RTCConnections.getRTCPeerConnection.signalingState}----------------------",
    );
    try {
      final answer = data["answer"] as Map<String, dynamic>;
      // set SDP answer as remoteDescription for peerConnection
      await RTCConnections.getRTCPeerConnection.setRemoteDescription(
        RTCSessionDescription(answer["sdp"], answer["type"]),
      );
    } catch (_) {
      debugPrint(
        "----------------------remote description already set up----------------------",
      );
    }
    socketData.partnerHasSDP = true;

    debugPrint(
      "-----------exchangeIce stack-----------${RTCConnections.rtcIceCadidates.length}----------------------",
    );
    // send iceCandidate generated to remote peer over signalling
    for (final RTCIceCandidate i in RTCConnections.rtcIceCadidates) {
      socketData.socket.emit(
        "exchangeIce",
        {
          "to": socketData.myCurrentChatId,
          "ice": {
            "sdpMid": i.sdpMid,
            "sdpMLineIndex": i.sdpMLineIndex,
            "candidate": i.candidate,
          },
        },
      );
    }
  }

  Future<void> acceptCallSocket(RTCSessionDescription answer) async {
    final socketData = GetIt.instance<SocketData>();

    // listen for Remote IceCandidate
    socketData.socket.on("exchangeIceNotify", (data) {
      final ice =
          ((data as Map<String, dynamic>)["ice"] as Map<String, dynamic>);
      RTCConnections.addCandidates(
        candidate: ice["candidate"],
        sdpMid: ice["sdpMid"],
        sdpMLineIndex: ice["sdpMLineIndex"],
      );
    });

    socketData.socket.emit("answerCall", {
      {
        "to": (socketData.tempOffer as Map<String, dynamic>)["from"],
        "answer": answer.toMap(),
      }
    });
  }

  void videoMutedSocket({required bool status}) {
    final socketData = GetIt.instance<SocketData>();

    socketData.socket.emit("videoMuted", {
      "to": socketData.myCurrentCallPartnerId,
      "status": status,
    });
  }

  void endCallSocket() {
    final socketData = GetIt.instance<SocketData>()
      ..hasSDP = false
      ..myCurrentCallPartnerId = "";
    socketData.socket.emit("callEnd", {
      "to": socketData.myCurrentCallPartnerId,
    });
  }

  void cancelCallSocket() {
    final socketData = GetIt.instance<SocketData>();

    RTCMediaService.I.isCallingMedia.add(false);
    socketData.socket.emit("callCancel", {
      "to": socketData.myCurrentChatId,
    });
  }
}
