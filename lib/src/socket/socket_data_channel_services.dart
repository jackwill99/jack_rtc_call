import "package:flutter/foundation.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/src/socket/socket_media_services.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";
import "package:jack_rtc_call/src/web_rtc/rtc_base.dart";

@protected
class SocketDataChannelService {
  factory SocketDataChannelService() {
    return I;
  }

  SocketDataChannelService._();

  static final SocketDataChannelService I = SocketDataChannelService._();

  void initializeDataChannel() {
    final socketData = GetIt.instance<SocketData>();

    //! For Client 1 / DataChannel
    socketData.socket.on("exchangeSDPAnswerNotify", (data) async {
      await SocketMediaService.I.socketSDPAnswer(
        data: data,
      );
    });

    //! For Client 2 / DataChannel
    socketData.socket.on("exchangeSDPOfferNotify", (data) async {
      RTCConnections.getRTCPeerConnection.onDataChannel = (ch) {
        RTCMediaService.I.channel = ch
          ..onDataChannelState = (state) {
            RTCMediaService.I.onDataChannelService(state: state);
          }
          ..onMessage = (message) {
            RTCMediaService.I.onListenMessage(message);
          };
      };

      // listen for Remote IceCandidate
      socketData.socket.on("exchangeIceNotify", (data) {
        final ice =
            (data as Map<String, dynamic>)["ice"] as Map<String, dynamic>;

        RTCConnections.addCandidates(
          candidate: ice["candidate"],
          sdpMid: ice["sdpMid"],
          sdpMLineIndex: ice["sdpMLineIndex"],
        );
      });

      // create SDP answer
      final offer =
          (data as Map<String, dynamic>)["offer"] as Map<String, dynamic>;
      final RTCSessionDescription answer = await RTCConnections.createAnswer(
        offerSDP: offer["sdp"],
        type: offer["type"],
      );

      socketData
        ..hasSDP = true
        ..partnerHasSDP = true;

      socketData.socket.emit("exchangeSDPAnswer", {
        {
          "to": data["from"],
          "answer": answer.toMap(),
        }
      });
    });
  }
}
