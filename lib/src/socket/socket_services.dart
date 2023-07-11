// ignore_for_file: invalid_use_of_protected_member, avoid_positional_boolean_parameters

import "dart:async";

import "package:flutter/foundation.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/jack_rtc_call.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/misc_socket.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";
import "package:jack_rtc_call/src/web_rtc/rtc_base.dart";
import "package:socket_io_client/socket_io_client.dart";

class SocketServices with SocketDataChannelService, SocketMediaService {
  SocketServices._();

  static void connectToServer(dynamic redirectToOffer) {
    final socketData = GetIt.instance<SocketData>();

    debugPrint(
      "----------------------connecting to server----------------------",
    );
    socketData.socket.connect();
    socketData.socket.on("connect", (data) {
      // isConnect = true;
      debugPrint("Connected");
      _initialize();
      if (redirectToOffer != null) {
        unawaited(
          RTCMediaService.acceptCall(
            toRoute: CallKitVOIP.toRoute,
            offer: redirectToOffer,
          ),
        );
      }
    });

    //! Main For Both Client 1 and Client 2 to request the start of chat
    socketData.socket.on(
      "askRequestChatNotify",
      (data) {
        debugPrint(
          "----------------------askRequestChatNotify---${socketData.myCurrentChatId}-------------------",
        );
        socketData.socket.emit(
          "requestChatInfo",
          {
            "to": (data as Map<String, dynamic>)["from"],
            "my": {
              "myCurrentChatId": socketData.myCurrentChatId,
              "hasSDP": socketData.hasSDP,
            }
          },
        );
      },
    );
  }

  static void initializeRequest() {
    final socketData = GetIt.instance<SocketData>();

    debugPrint(
      "----------------------initialize------ ${socketData.myCurrentChatId}----------------",
    );
    //!  For Client 1
    socketData.socket
        .emit("askRequestChat", {"to": socketData.myCurrentChatId});
  }

  /// ## Assume there has Client 1 and Client 2.
  ///
  /// 🙋‍♂️ Client 1 is the sender or request to start the real time communication.
  ///
  /// 🙆‍♀️ Client 2 will be accept the request from Client 2.
  ///
  /// 📲 Assume like that flow ...
  ///
  static void _initialize() {
    final socketData = GetIt.instance<SocketData>();
    //! For Both Client 1 and Client 2 to share their current chatting user
    socketData.socket.on(
      "requestChatInfoNotify",
      (data) {
        socketData
          ..partnerCurrentChatId =
              (data as Map<String, Map<String, dynamic>>)["partner"]
                  ?["myCurrentChatId"]
          ..partnerHasSDP = data["partner"]?["hasSDP"];
        debugPrint(
          "----------------------my partner is chatting with ${socketData.partnerCurrentChatId}----------------------",
        );

        if (socketData.partnerCurrentChatId.isNotEmpty &&
            socketData.myUserId == socketData.partnerCurrentChatId) {
          socketData.socket.emit(
            "updatePartnerInfo",
            {
              "to": socketData.myCurrentChatId,
              "my": {
                "myCurrentChatId": socketData.myCurrentChatId,
                "hasSDP": socketData.hasSDP,
              }
            },
          );
        }
      },
    );

    //! For Both Client 1 and Client 2 to update their current chatting user
    socketData.socket.on("updatePartnerInfoNotify", (data) async {
      debugPrint(
        "----------------------update partner info notify------${(data as Map<String, Map<String, dynamic>>)['partner']?['myCurrentChatId']}----------------",
      );
      socketData.partnerCurrentChatId = data["partner"]?["myCurrentChatId"];
      debugPrint(
        "----------updatePartnerInfoNotify------------my partner is chatting with ${socketData.partnerCurrentChatId}----------------------",
      );
      socketData.partnerHasSDP = data["partner"]?["hasSDP"];
    });

    SocketDataChannelService.initializeDataChannel();
    SocketMediaService.initializeMedia();

    /// Miscellaneous socket service

    unawaited(MiscSocketService.initialize());
  }

  ///-----------------------------------------------------

  static void chatClose() {
    final socketData = GetIt.instance<SocketData>();

    if (socketData.partnerCurrentChatId.isNotEmpty &&
        socketData.myUserId == socketData.partnerCurrentChatId) {
      socketData.socket.emit(
        "updatePartnerInfo",
        {
          "to": socketData.myCurrentChatId,
          "my": {
            "myCurrentChatId": "",
            "hasSDP": false,
          }
        },
      );
    }

    socketData
      ..myCurrentChatId = ""
      ..hasSDP = false;
  }
}

@protected
mixin SocketDataChannelService {
  static void initializeDataChannel() {
    final socketData = GetIt.instance<SocketData>();

    //! For Client 1 / DataChannel
    socketData.socket.on("exchangeSDPAnswerNotify", (data) async {
      await SocketMediaService.socketSDPAnswer(
        data: data,
      );
    });

    //! For Client 2 / DataChannel
    socketData.socket.on("exchangeSDPOfferNotify", (data) async {
      RTCConnections.getRTCPeerConnection.onDataChannel = (ch) {
        RTCMediaService.channel = ch
          ..onDataChannelState = (state) {
            RTCMediaService.onDataChannelService(state: state);
          }
          ..onMessage = (message) {
            RTCMediaService.onListenMessage(message);
          };
      };

      // listen for Remote IceCandidate
      socketData.socket.on("exchangeIceNotify", (data) {
        RTCConnections.addCandidates(
          candidate: (data as Map<String, Map<String, dynamic>>)["ice"]
              ?["candidate"],
          sdpMid: data["ice"]?["sdpMid"],
          sdpMLineIndex: data["ice"]?["sdpMLineIndex"],
        );
      });

      // create SDP answer
      final RTCSessionDescription answer = await RTCConnections.createAnswer(
        offerSDP: (data as Map<String, Map<String, dynamic>>)["offer"]?["sdp"],
        type: data["offer"]?["type"],
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

@protected
mixin SocketMediaService {
  static void initializeMedia() {
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
      await CallKitVOIP.inComingCall(
        callerName: data["callerName"],
        callerId: data["from"],
        isVideo: data["video"],
        callerHandle: data["callerHandle"],
        callerAvatar: data["callerAvatar"],
      );

      MiscSocketService.callHandler = data["callerHandle"];
      MiscSocketService.avatar = data["callerAvatar"];
      MiscSocketService.callerName.add(data["callerName"]);
    });

    socketData.socket.on("callEndNotify", (data) {
      socketData
        ..hasSDP = false
        ..myCurrentCallPartnerId = "";
      RTCMediaService.onPartnerCallEnded();
    });

    socketData.socket.on("declineCallNotify", (data) async {
      JackRTCService.onListenDeclineCall?.call();
    });

    socketData.socket.on("callCancelNotify", (data) async {
      await CallKitVOIP.callEnd();
      JackRTCService.onListenCancelCall?.call();
    });

    socketData.socket.on("missedCallNotify", (data) async {});
    socketData.socket.on("videoMutedNotify", (data) async {
      RTCMediaService.isPartnerVideoOpen
          .add((data as Map<String, dynamic>)["status"]);
    });
    socketData.socket.on("videoRequestNotify", (data) async {});
  }

  static Future<void> socketSDPAnswer({
    required Map<String, Map<String, dynamic>> data,
    bool isVideo = false,
  }) async {
    final socketData = GetIt.instance<SocketData>();

    debugPrint(
      "---------------just-------${RTCConnections.getRTCPeerConnection.signalingState}----------------------",
    );
    try {
      // set SDP answer as remoteDescription for peerConnection
      await RTCConnections.getRTCPeerConnection.setRemoteDescription(
        RTCSessionDescription(data["answer"]?["sdp"], data["answer"]?["type"]),
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
      socketData.socket.emit("exchangeIce", {
        "to": socketData.myCurrentChatId,
        "ice": {
          "sdpMid": i.sdpMid,
          "sdpMLineIndex": i.sdpMLineIndex,
          "candidate": i.candidate,
        }
      });
    }
  }

  static Future<void> acceptCallSocket(RTCSessionDescription answer) async {
    final socketData = GetIt.instance<SocketData>();

    // listen for Remote IceCandidate
    socketData.socket.on("exchangeIceNotify", (data) {
      RTCConnections.addCandidates(
        candidate: (data as Map<String, Map<String, dynamic>>)["ice"]
            ?["candidate"],
        sdpMid: data["ice"]?["sdpMid"],
        sdpMLineIndex: data["ice"]?["sdpMLineIndex"],
      );
    });

    socketData.socket.emit("answerCall", {
      {
        "to": (socketData.tempOffer as Map<String, dynamic>)["from"],
        "answer": answer.toMap(),
      }
    });
  }

  static void videoMutedSocket(bool status) {
    final socketData = GetIt.instance<SocketData>();

    socketData.socket.emit("videoMuted", {
      "to": socketData.myCurrentCallPartnerId,
      "status": status,
    });
  }

  static void endCallSocket() {
    final socketData = GetIt.instance<SocketData>()
      ..hasSDP = false
      ..myCurrentCallPartnerId = "";
    socketData.socket.emit("callEnd", {
      "to": socketData.myCurrentCallPartnerId,
    });
  }

  static void cancelCallSocket() {
    final socketData = GetIt.instance<SocketData>();

    RTCMediaService.isCallingMedia.add(false);
    socketData.socket.emit("callCancel", {
      "to": socketData.myCurrentChatId,
    });
  }
}

class SocketData {
  // RxBool isConnect = false.obs;

  late String socketUrl;

  late String myUserId;

  /// default is `empty string`
  String myCurrentChatId = "";

  bool hasSDP = false;

  //!Client 1 is Subject Start -> Login Doctor

  String partnerCurrentChatId = "";
  bool partnerHasSDP = false;

  Socket? _socket;

  Socket get socket => _socket!;

  set socket(Socket? value) {
    _socket = value;
    debugPrint(
      "----------------------setting socket is success----------------------",
    );
  }

  void settingSocket() {
    final socketData = GetIt.instance<SocketData>();

    final socket = io(
      socketData.socketUrl,
      <String, dynamic>{
        "transports": ["websocket"],
        "query": {"userId": socketData.myUserId},
        "forceNew": true,
        // 'path': '/sockets.io',
      },
    );
    socketData.socket = socket;
  }

  dynamic tempOffer;

  /// my current partner id in media calling
  String myCurrentCallPartnerId = "";
}
