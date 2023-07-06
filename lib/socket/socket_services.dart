import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_it/get_it.dart';
import 'package:jack_rtc_call/callkit/callkit.dart';
import 'package:jack_rtc_call/web_rtc/rtc.dart';
import 'package:jack_rtc_call/web_rtc/media_services.dart';
import 'package:socket_io_client/socket_io_client.dart';

class SocketServices with SocketDataChannelService, SocketMediaService {
  SocketServices._();

  static void connectToServer() {
    final socketData = GetIt.instance<SocketData>();

    debugPrint(
        "----------------------connecting to server----------------------");
    socketData.getSocket.connect();
    socketData.getSocket.on("connect", (data) {
      // isConnect = true;
      print('Connected');
      _initialize();
    });

    //! Main For Both Client 1 and Client 2 to request the start of chat
    socketData.getSocket.on(
      'askRequestChatNotify',
      (data) {
        debugPrint(
            "----------------------askRequestChatNotify---${socketData.myCurrentChatId}-------------------");
        socketData.getSocket.emit(
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

  static void initializeRequest() {
    final socketData = GetIt.instance<SocketData>();

    debugPrint(
        "----------------------initialize------ ${socketData.myCurrentChatId}----------------");
    //!  For Client 1
    socketData.getSocket
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
    socketData.getSocket.on(
      'requestChatInfoNotify',
      (data) {
        socketData.partnerCurrentChatId = data['partner']['myCurrentChatId'];
        socketData.partnerHasSDP = data['partner']['hasSDP'];
        debugPrint(
            "----------------------my partner is chatting with ${socketData.partnerCurrentChatId}----------------------");

        if (socketData.partnerCurrentChatId.isNotEmpty &&
            socketData.myUserId == socketData.partnerCurrentChatId) {
          socketData.getSocket.emit(
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
    socketData.getSocket.on('updatePartnerInfoNotify', (data) async {
      debugPrint(
          "----------------------update partner info notify------${data['partner']['myCurrentChatId']}----------------");
      socketData.partnerCurrentChatId = data['partner']['myCurrentChatId'];
      debugPrint(
          "----------updatePartnerInfoNotify------------my partner is chatting with ${socketData.partnerCurrentChatId}----------------------");
      socketData.partnerHasSDP = data['partner']['hasSDP'];
    });

    SocketDataChannelService.initializeDataChannel();
    SocketMediaService.initializeMedia();
  }

  ///-----------------------------------------------------

  static void chatClose() {
    final socketData = GetIt.instance<SocketData>();

    if (socketData.partnerCurrentChatId.isNotEmpty &&
        socketData.myUserId == socketData.partnerCurrentChatId) {
      socketData.getSocket.emit(
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
  static void initializeDataChannel() {
    final socketData = GetIt.instance<SocketData>();

    //! For Client 1 / DataChannel
    socketData.getSocket.on("exchangeSDPAnswerNotify", (data) async {
      await SocketMediaService.socketSDPAnswer(
        data: data,
      );
    });

    //! For Client 2 / DataChannel
    socketData.getSocket.on("exchangeSDPOfferNotify", (data) async {
      RTCConnections.getRTCPeerConnection.onDataChannel = (ch) {
        RTCMediaService.channel = ch;
        // final chatSocketController = Get.find<ChatController>();

        ch.onDataChannelState = (state) {
          RTCMediaService.onDataChannelService(state: state);
        };
        ch.onMessage = (message) {
          RTCMediaService.onListenMessage(message);
        };
      };

      // listen for Remote IceCandidate
      socketData.getSocket.on("exchangeIceNotify", (data) {
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

      socketData.getSocket.emit("exchangeSDPAnswer", {
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
  static void initializeMedia() {
    final socketData = GetIt.instance<SocketData>();

    //! For Client 1 / Media Call
    socketData.getSocket.on("callAnswered", (data) async {
      await socketSDPAnswer(data: data, isVideo: true);
      socketData.myCurrentCallPartnerId = data['from'];
    });

    //! For Client 2 / MediaCall
    socketData.getSocket.on("newCall", (data) async {
      debugPrint("----------------------new call-------$data---------------");
      socketData.tempOffer = data;
      await CallKitVOIP.inComingCall(
        callerName: data['callerName'],
        callerId: data['from'],
        isVideo: data['video'],
        callerHandle: data['callerHandle'],
        callerAvatar: data['callerAvatar'],
      );
    });

    socketData.getSocket.on("callEndNotify", (data) {
      socketData.hasSDP = false;
      socketData.myCurrentCallPartnerId = "";
      RTCMediaService.onPartnerCallEnded();
    });

    socketData.getSocket.on("declineCallNotify", (data) async {
      // JackLocalNotificationApi.showNotification(title: "Called Declined");
    });
    socketData.getSocket.on("missedCallNotify", (data) async {});
    socketData.getSocket.on("videoMutedNotify", (data) async {
      RTCMediaService.isPartnerVideoOpen.add(data['status']);
    });
    socketData.getSocket.on("videoRequestNotify", (data) async {});
  }

  static Future<void> socketSDPAnswer({
    required dynamic data,
    bool isVideo = false,
  }) async {
    final socketData = GetIt.instance<SocketData>();

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
      socketData.getSocket.emit("exchangeIce", {
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
    socketData.getSocket.on("exchangeIceNotify", (data) {
      RTCConnections.addCandidates(
        candidate: data["ice"]["candidate"],
        sdpMid: data['ice']["sdpMid"],
        sdpMLineIndex: data['ice']["sdpMLineIndex"],
      );
    });

    socketData.getSocket.emit("answerCall", {
      {
        "to": socketData.tempOffer['from'],
        "answer": answer.toMap(),
      }
    });
  }

  static void videoMutedSocket(bool status) {
    final socketData = GetIt.instance<SocketData>();

    socketData.getSocket.emit("videoMuted", {
      "to": socketData.myCurrentCallPartnerId,
      "status": status,
    });
  }

  static void endCallSocket() {
    final socketData = GetIt.instance<SocketData>();

    socketData.hasSDP = false;
    socketData.getSocket.emit("callEnd", {
      "to": socketData.myCurrentCallPartnerId,
    });
    socketData.myCurrentCallPartnerId = "";
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

  Socket get getSocket => _socket!;

  set setSocket(Socket? value) {
    _socket = value;
    debugPrint(
        "----------------------setting socket is success----------------------");
  }

  void settingSocket() {
    final socketData = GetIt.instance<SocketData>();

    final socket = io(
      socketData.socketUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        //ToDo ! Own ID
        'query': {"userId": socketData.myUserId},
        'forceNew': true,
        // 'path': '/sockets.io',
      },
    );
    socketData.setSocket = socket;
  }

  dynamic tempOffer;

  /// my current partner id in media calling
  String myCurrentCallPartnerId = "";
}
