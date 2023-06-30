import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:jack_rtc_call/callkit/callkit.dart';
import 'package:jack_rtc_call/web_rtc/rtc.dart';
import 'package:jack_rtc_call/web_rtc/media_services.dart';
import 'package:socket_io_client/socket_io_client.dart';

class SocketServices with SocketDataChannelService, SocketMediaService {
  SocketServices._();

  static void connectToServer({
    required String socketUrl,
    required String myId,
    required SocketData socketData,
  }) {
    socketData.myUserId = myId;
    socketData.socket = io(
      socketUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        //ToDo ! Own ID
        'query': {"userId": socketData.myUserId},
        // 'path': '/sockets.io',
      },
    );
    socketData.socket.connect();
    socketData.socket.on("connect", (data) {
      // isConnect = true;
      print('Connected');
      _initialize(socketData: socketData);
    });

    //! Main For Both Client 1 and Client 2 to request the start of chat
    socketData.socket.on(
      'askRequestChatNotify',
      (data) {
        debugPrint(
            "----------------------askRequestChatNotify---${socketData.myCurrentChatId}-------------------");
        socketData.socket.emit(
          'requestChatInfo',
          {
            "to": data['from'],
            "my": {
              "myCurrentChatId": socketData.myCurrentChatId,
              "hasSDP": socketData.hasSDP,
            }
          },
        );
      },
    );
  }

  static void initializeRequest({required SocketData socketData}) {
    debugPrint(
        "----------------------initialize------ ${socketData.myCurrentChatId}----------------");
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
  static void _initialize({required SocketData socketData}) {
    //! For Both Client 1 and Client 2 to share their current chatting user
    socketData.socket.on(
      'requestChatInfoNotify',
      (data) {
        socketData.partnerCurrentChatId = data['partner']['myCurrentChatId'];
        socketData.partnerHasSDP = data['partner']['hasSDP'];
        debugPrint(
            "----------------------my partner is chatting with ${socketData.partnerCurrentChatId}----------------------");

        if (socketData.partnerCurrentChatId.isNotEmpty &&
            socketData.myUserId == socketData.partnerCurrentChatId) {
          socketData.socket.emit(
            'updatePartnerInfo',
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
    socketData.socket.on('updatePartnerInfoNotify', (data) async {
      debugPrint(
          "----------------------update partner info notify------${data['partner']['myCurrentChatId']}----------------");
      socketData.partnerCurrentChatId = data['partner']['myCurrentChatId'];
      debugPrint(
          "----------updatePartnerInfoNotify------------my partner is chatting with ${socketData.partnerCurrentChatId}----------------------");
      socketData.partnerHasSDP = data['partner']['hasSDP'];
    });

    SocketDataChannelService.initializeDataChannel(socketData: socketData);
    SocketMediaService.initializeMedia(socketData: socketData);
  }

  ///-----------------------------------------------------

  static void chatClose({required SocketData socketData}) {
    if (socketData.partnerCurrentChatId.isNotEmpty &&
        socketData.myUserId == socketData.partnerCurrentChatId) {
      socketData.socket.emit(
        'updatePartnerInfo',
        {
          "to": socketData.myCurrentChatId,
          "my": {
            "myCurrentChatId": "",
            "hasSDP": false,
          }
        },
      );
    }

    socketData.myCurrentChatId = "";
    socketData.hasSDP = false;
  }
}

@protected
mixin SocketDataChannelService {
  static void initializeDataChannel({required SocketData socketData}) {
    //! For Client 1 / DataChannel
    socketData.socket.on("exchangeSDPAnswerNotify", (data) async {
      await SocketMediaService.socketSDPAnswer(
          data: data, socketData: socketData);
    });

    //! For Client 2 / DataChannel
    socketData.socket.on("exchangeSDPOfferNotify", (data) async {
      RTCConnections.getRTCPeerConnection.onDataChannel = (ch) {
        RTCMediaService.channel = ch;
        // final chatSocketController = Get.find<ChatController>();

        ch.onDataChannelState = (state) {
          RTCMediaService.onDataChannelService(
              state: state, socketData: socketData);
        };
        ch.onMessage = (message) {
          RTCMediaService.onListenMessage(message);
        };
      };

      // listen for Remote IceCandidate
      socketData.socket.on("exchangeIceNotify", (data) {
        RTCConnections.addCandidates(
          candidate: data["ice"]["candidate"],
          sdpMid: data['ice']["sdpMid"],
          sdpMLineIndex: data['ice']["sdpMLineIndex"],
        );
      });

      // create SDP answer
      RTCSessionDescription answer = await RTCConnections.createAnswer(
          offerSDP: data['offer']["sdp"], type: data['offer']["type"]);

      socketData.hasSDP = true;
      socketData.partnerHasSDP = true;

      socketData.socket.emit("exchangeSDPAnswer", {
        {
          "to": data['from'],
          "answer": answer.toMap(),
        }
      });
    });
  }
}

@protected
mixin SocketMediaService {
  static void initializeMedia({required SocketData socketData}) {
    //! For Client 1 / Media Call
    socketData.socket.on("callAnswered", (data) async {
      await socketSDPAnswer(data: data, socketData: socketData, isVideo: true);
      socketData.myCurrentCallPartnerId = data['from'];
    });

    //! For Client 2 / MediaCall
    socketData.socket.on("newCall", (data) async {
      debugPrint("----------------------new call-------$data---------------");
      socketData.tempOffer = data;
      await CallKitVOIP.inComingCall(
          callerName: "Jack Will", callerId: data['from']);
    });

    socketData.socket.on("callEndNotify", (data) {
      socketData.hasSDP = false;
      socketData.myCurrentCallPartnerId = "";
    });

    socketData.socket.on("declineCallNotify", (data) async {
      // JackLocalNotificationApi.showNotification(title: "Called Declined");
    });
    socketData.socket.on("missedCallNotify", (data) async {});
    socketData.socket.on("videoMutedNotify", (data) async {
      RTCMediaService.isPartnerVideoOpen.add(data['status']);
    });
    socketData.socket.on("videoRequestNotify", (data) async {});
  }

  static Future<void> socketSDPAnswer({
    required dynamic data,
    required SocketData socketData,
    bool isVideo = false,
  }) async {
    debugPrint(
        "---------------just-------${RTCConnections.getRTCPeerConnection.signalingState}----------------------");
    try {
      // set SDP answer as remoteDescription for peerConnection
      await RTCConnections.getRTCPeerConnection.setRemoteDescription(
        RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
      );
    } catch (_) {
      debugPrint(
          "----------------------remote description already set up----------------------");
    }
    socketData.partnerHasSDP = true;

    debugPrint(
        "-----------exchangeIce stack-----------${RTCConnections.rtcIceCadidates.length}----------------------");
    // send iceCandidate generated to remote peer over signalling
    for (RTCIceCandidate i in RTCConnections.rtcIceCadidates) {
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

  static Future<void> acceptCallSocket(
      RTCSessionDescription answer, SocketData socketData) async {
    // listen for Remote IceCandidate
    socketData.socket.on("exchangeIceNotify", (data) {
      RTCConnections.addCandidates(
        candidate: data["ice"]["candidate"],
        sdpMid: data['ice']["sdpMid"],
        sdpMLineIndex: data['ice']["sdpMLineIndex"],
      );
    });

    socketData.socket.emit("answerCall", {
      {
        "to": socketData.tempOffer['from'],
        "answer": answer.toMap(),
      }
    });
  }

  static void videoMutedSocket(bool status, SocketData socketData) {
    socketData.socket.emit("videoMuted", {
      "to": socketData.myCurrentCallPartnerId,
      "status": status,
    });
  }

  static void endCallSocket(SocketData socketData) {
    socketData.hasSDP = false;
    socketData.socket.emit("callEnd", {
      "to": socketData.myCurrentCallPartnerId,
    });
    socketData.myCurrentCallPartnerId = "";
  }
}

class SocketData {
  // RxBool isConnect = false.obs;

  late String myUserId;

  /// default is `empty string`
  String myCurrentChatId = "";

  bool hasSDP = false;

  //!Client 1 is Subject Start -> Login Doctor

  String partnerCurrentChatId = "";
  bool partnerHasSDP = false;

  late Socket socket;

  dynamic tempOffer;

  /// my current partner id in media calling
  String myCurrentCallPartnerId = "";
}
