//
// Created by Jack Will on 21/06/2023.
// https://github.com/jackwill99
//

import "package:flutter/foundation.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";

@protected
class RTCConnections {
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
  RTCConnections._();

  // RTC peer connection
  static RTCPeerConnection? _rtcPeerConnection;

  static RTCPeerConnection get getRTCPeerConnection {
    return _rtcPeerConnection!;
  }

  // list of rtcCandidates to be sent over signalling
  static final List<RTCIceCandidate> rtcIceCadidates = [];

  /// ## ✅ Everytime you want to start communication, open connection
  static Future<RTCPeerConnection> setupPeerConnection() async {
    // create peer connection
    _rtcPeerConnection = await createPeerConnection(
      {
        // TODO(jackwill): take params for the server config
        "iceServers": [
          {
            "urls": "stun:stun.telemed.sabahna.com:8443",
            //   'stun:stun1.l.google.com:19302',
          },
          {
            "urls": "turn:turn.telemed.sabahna.com:8443",
            "credential": "sabahna",
            "username": "sabahna",
          }
        ],
      },
    );
    _rtcPeerConnection?.onIceCandidate =
        (candidate) => rtcIceCadidates.add(candidate);
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

  /// ## 💁‍♂️ For Client 1
  /// This setp is after opening the RTC peer connections.
  /// Offer is generated for Client 1 and send this offer to Client 2.
  static Future<RTCSessionDescription> createOffer() async {
    // listen for local iceCandidate and add it to the list of IceCandidate
    _rtcPeerConnection!.onIceCandidate =
        (candidate) => RTCConnections.rtcIceCadidates.add(candidate);

    // create SDP Offer
    final RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();

    // set SDP offer as localDescription for peerConnection
    await _rtcPeerConnection!.setLocalDescription(offer);

    return offer;
  }

  /// ## 💁‍♂️ 💁‍♀️ Both Client 1 and Client 2
  /// ### For Client 1
  /// When Client 2 accept the communication request, he will give you the answer SDP
  ///
  /// Set up this answer for Client 1 peer connection.
  ///
  /// And next step is to send your IceCandidates to Client 2.
  ///
  /// So, I gave the list of IceCandidates. Send it now!
  ///
  /// ### For Client 2
  /// When Client 1 request the communication, he will give you the offer
  ///
  /// Set up this offer for Client 2 peer connection.
  ///
  /// And next step is to send your answer to Client 1
  ///
  /// But you don't need the list of IceCandidates. This is only for the client of offered
  ///
  static Future<List<RTCIceCandidate>> setRemoteDescription({
    required String sdp,
    required String type,
  }) async {
    await _rtcPeerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, type),
    );
    return rtcIceCadidates;
  }

  /// ## 💁‍♀️ For Client 2
  /// When Client 1 requested and wanted to start communication, you need to generate your answer
  ///
  /// This will generate your answer and send it to Client 1.
  static Future<RTCSessionDescription> createAnswer({
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

  /// ## 💁‍♀️ For Client 2
  /// Add IceCandidates of Client 1 in your peer connection.
  ///
  /// And now you are successfully connected 🚀
  static Future<void> addCandidates({
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

  /// ## ❌ Everytime you leave the chat conversation, dispose peer connection.
  static Future<void> dispose() async {
    await _rtcPeerConnection?.dispose();
    await _rtcPeerConnection?.close();
    _rtcPeerConnection = null;
    rtcIceCadidates.clear();
    debugPrint(
      "----------------------Closed Web RTC Connection----------------------",
    );
  }

  /// Restart and re-initialize the peer connections
  static Future<void> restartConnections() async {
    await dispose();

    /// ✅ Everytime you want to start communication, open connection
    await setupPeerConnection();
    debugPrint(
      "----------------------Ready to restart peer connection----------------------",
    );
  }

  /// Check and ReInitialize peer connections
  static Future<void> checkAndReinitialize() async {
    SocketServices.initializeRequest();
    await RTCConnections.setupPeerConnection();
  }
}
