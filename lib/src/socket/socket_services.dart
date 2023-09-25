import "dart:async";

import "package:flutter/foundation.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/misc_socket.dart";
import "package:jack_rtc_call/src/socket/socket_data_channel_services.dart";
import "package:jack_rtc_call/src/socket/socket_media_services.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";
import "package:socket_io_client/socket_io_client.dart";

class SocketServices {
  factory SocketServices() {
    return I;
  }

  SocketServices._();

  static final SocketServices I = SocketServices._();

  void connectToServer(dynamic redirectToOffer) {
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
          RTCMediaService.I.acceptCall(
            toRoute: CallKitVOIP.I.toRoute,
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
            },
          },
        );
      },
    );
  }

  void initializeRequest() {
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
  void _initialize() {
    final socketData = GetIt.instance<SocketData>();
    //! For Both Client 1 and Client 2 to share their current chatting user
    socketData.socket.on(
      "requestChatInfoNotify",
      (data) {
        final partner =
            (data as Map<String, dynamic>)["partner"] as Map<String, dynamic>;
        socketData
          ..partnerCurrentChatId = partner["myCurrentChatId"]
          ..partnerHasSDP = partner["hasSDP"];
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
              },
            },
          );
        }
      },
    );

    //! For Both Client 1 and Client 2 to update their current chatting user
    socketData.socket.on("updatePartnerInfoNotify", (data) async {
      final partner =
          (data as Map<String, dynamic>)["partner"] as Map<String, dynamic>;
      debugPrint(
        "----------------------update partner info notify------${partner['myCurrentChatId']}----------------",
      );
      socketData.partnerCurrentChatId = partner["myCurrentChatId"];
      debugPrint(
        "----------updatePartnerInfoNotify------------my partner is chatting with ${socketData.partnerCurrentChatId}----------------------",
      );
      socketData.partnerHasSDP = partner["hasSDP"];
    });

    SocketDataChannelService.I.initializeDataChannel();
    SocketMediaService.I.initializeMedia();

    /// Miscellaneous socket service

    unawaited(MiscSocketService.I.initialize());
  }

  ///-----------------------------------------------------

  void chatClose() {
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
          },
        },
      );
    }

    socketData
      ..myCurrentChatId = ""
      ..hasSDP = false;
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
