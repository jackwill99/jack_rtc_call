import "package:flutter_webrtc/flutter_webrtc.dart";

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
abstract class RTCConnectionsAbstract {
  // list of rtcCandidates to be sent over signalling
  final List<RTCIceCandidate> rtcIceCandidates = [];

  RTCPeerConnection get getRTCPeerConnection;

  /// ## ✅ Everytime you want to start communication, open connection
  Future<RTCPeerConnection> setupPeerConnection();

  /// ## 💁‍♂️ For Client 1
  /// This setup is after opening the RTC peer connections.
  /// Offer is generated for Client 1 and send this offer to Client 2.
  Future<RTCSessionDescription> createOffer();

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
  Future<List<RTCIceCandidate>> setRemoteDescription({
    required String sdp,
    required String type,
  });

  /// ## 💁‍♀️ For Client 2
  /// When Client 1 requested and wanted to start communication, you need to generate your answer
  ///
  /// This will generate your answer and send it to Client 1.
  Future<RTCSessionDescription> createAnswer({
    required String offerSDP,
    required String type,
  });

  /// ## 💁‍♀️ For Client 2
  /// Add IceCandidates of Client 1 in your peer connection.
  ///
  /// And now you are successfully connected 🚀
  Future<void> addCandidates({
    required String candidate,
    required String sdpMid,
    required int sdpMLineIndex,
  });

  /// ## ❌ Everytime you leave the chat conversation, dispose peer connection.
  Future<void> dispose();

  /// Restart and re-initialize the peer connections
  Future<void> restartConnections();

  /// Check and ReInitialize peer connections
  Future<void> checkAndReinitialize();
}
