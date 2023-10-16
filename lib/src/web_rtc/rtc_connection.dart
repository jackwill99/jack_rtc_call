//
// Created by Jack Will on 21/06/2023.
// https://github.com/jackwill99
//

import "package:flutter/foundation.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:jack_rtc_call/model/web_rtc/rtc_connection_abstract.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";

/// ## Assume there has Client 1 and Client 2.
///
/// 🙋‍♂️ Client 1 is the sender or request to start the real time communication.
///
/// 🙆‍♀️ Client 2 will be accept the request from Client 2.
///
/// 📲 Assume like that flow ...
///
/// Session Description Protocol (SDP) exchange media capabilities,codecs and session parameters between peers
/// and establish a connection
///
/// ICE Candidates (Interactive Connectivity Establishment)is a technique used to establish network connectivity between WebRTC peers
/// by gathering network addresses (IP addresses and ports) of a client using techniques like STUN and TURN
@protected
class RTCConnections extends RTCConnectionsAbstract {
  factory RTCConnections() {
    return I;
  }

  RTCConnections._();

  static final RTCConnections I = RTCConnections._();

  // RTC peer connection
  RTCPeerConnection? _rtcPeerConnection;

  @override
  RTCPeerConnection get getRTCPeerConnection {
    return _rtcPeerConnection!;
  }

  List? iceServers;

  @override
  Future<RTCPeerConnection> setupPeerConnection() async {
    // create peer connection
    _rtcPeerConnection = await createPeerConnection(
      {
        "iceServers": iceServers ??
            [
              {
                "stun:stun1.l.google.com:19302",
              },
            ],
      },
    );
    _rtcPeerConnection?.onIceCandidate =
        (candidate) => rtcIceCandidates.add(candidate);
    debugPrint(
      "----------------------successfully set up Web RTC Open Connection----------------------",
    );

    _rtcPeerConnection!.onSignalingState = (state) {
      debugPrint("-----------signaling-----------$state----------------------");
    };

    _rtcPeerConnection!.onConnectionState = (state) {
      debugPrint(
        "------connection----------------$state----------------------",
      );
    };
    return _rtcPeerConnection!;
  }

  @override
  Future<RTCSessionDescription> createOffer() async {
    // listen for local iceCandidate and add it to the list of IceCandidate
    _rtcPeerConnection!.onIceCandidate =
        (candidate) => RTCConnections.I.rtcIceCandidates.add(candidate);

    // create SDP Offer
    final RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();

    // set SDP offer as localDescription for peerConnection
    await _rtcPeerConnection!.setLocalDescription(offer);

    return offer;
  }

  @override
  Future<List<RTCIceCandidate>> setRemoteDescription({
    required String sdp,
    required String type,
  }) async {
    await _rtcPeerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, type),
    );
    return rtcIceCandidates;
  }

  @override
  Future<RTCSessionDescription> createAnswer({
    required String offerSDP,
    required String type,
  }) async {
    // set SDP offer as remoteDescription for peerConnection
    await _rtcPeerConnection!.setRemoteDescription(
      RTCSessionDescription(offerSDP, type),
    );

    // create SDP answer
    final RTCSessionDescription answer =
        await _rtcPeerConnection!.createAnswer();

    // set SDP answer as localDescription for peerConnection
    await _rtcPeerConnection!.setLocalDescription(answer);

    return answer;
  }

  @override
  Future<void> addCandidates({
    required String candidate,
    required String sdpMid,
    required int sdpMLineIndex,
  }) async {
    //* It's a Future but I don't want to wait
    await _rtcPeerConnection!.addCandidate(
      RTCIceCandidate(
        candidate,
        sdpMid,
        sdpMLineIndex,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _rtcPeerConnection?.dispose();
    await _rtcPeerConnection?.close();
    _rtcPeerConnection = null;
    rtcIceCandidates.clear();
    debugPrint(
      "----------------------Closed Web RTC Connection----------------------",
    );
  }

  @override
  Future<void> restartConnections() async {
    await dispose();

    /// ✅ Everytime you want to start communication, open connection
    await setupPeerConnection();
    debugPrint(
      "----------------------Ready to restart peer connection----------------------",
    );
  }

  @override
  Future<void> checkAndReinitialize() async {
    SocketServices.I.initializeRequest();
    await RTCConnections.I.setupPeerConnection();
  }
}
