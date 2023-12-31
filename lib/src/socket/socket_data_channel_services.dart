import "package:flutter/foundation.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:jack_rtc_call/model/socket/socket_data_channel_abstract.dart";
import "package:jack_rtc_call/src/socket/socket_data.dart";
import "package:jack_rtc_call/src/socket/socket_media_services.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";

@protected
class SocketDataChannelService extends SocketDataChannelAbstract {
  factory SocketDataChannelService() {
    return I;
  }

  SocketDataChannelService._();

  static final SocketDataChannelService I = SocketDataChannelService._();

  @override
  void initializeDataChannel() {
    final socketData = SocketData();

    //! For Client 1 / DataChannel
    socketData.socket?.on("exchangeSDPAnswerNotify", (data) async {
      await SocketMediaService.I.socketSDPAnswer(
        data: data,
      );
    });

    //! For Client 2 / DataChannel
    socketData.socket?.on("exchangeSDPOfferNotify", (data) async {
      rtcConnection.getRTCPeerConnection.onDataChannel = (ch) {
        RTCMediaService.I.channel = ch
          ..onDataChannelState = (state) {
            RTCMediaService.I.onDataChannelService(state: state);
          }
          ..onMessage = (message) {
            RTCMediaService.I.onListenMessage(message);
          };
      };

      // listen for Remote IceCandidate
      socketData.socket?.on("exchangeIceNotify", (data) {
        final ice =
            (data as Map<String, dynamic>)["ice"] as Map<String, dynamic>;

        rtcConnection.addCandidates(
          candidate: ice["candidate"],
          sdpMid: ice["sdpMid"],
          sdpMLineIndex: ice["sdpMLineIndex"],
        );
      });

      // create SDP answer
      final offer =
          (data as Map<String, dynamic>)["offer"] as Map<String, dynamic>;
      final RTCSessionDescription answer = await rtcConnection.createAnswer(
        offerSDP: offer["sdp"],
        type: offer["type"],
      );

      socketData
        ..hasSDP = true
        ..partnerHasSDP = true;

      socketData.socket?.emit("exchangeSDPAnswer", {
        {
          "to": data["from"],
          "answer": answer.toMap(),
        }
      });
    });
  }
}
