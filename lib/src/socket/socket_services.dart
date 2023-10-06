import "dart:async";

import "package:flutter/foundation.dart";
import "package:jack_rtc_call/model/socket/socket_services_abstract.dart";
import "package:jack_rtc_call/src/callkit/callkit.dart";
import "package:jack_rtc_call/src/socket/misc_socket.dart";
import "package:jack_rtc_call/src/socket/socket_data.dart";
import "package:jack_rtc_call/src/socket/socket_data_channel_services.dart";
import "package:jack_rtc_call/src/socket/socket_media_services.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";

class SocketServices extends SocketServicesAbstract
    with _SocketServiceInitialize {
  factory SocketServices() {
    return I;
  }

  SocketServices._();

  static final SocketServices I = SocketServices._();

  @override
  void connectToServer(dynamic redirectToOffer) {
    debugPrint(
      "----------------------connecting to server----------------------",
    );
    socketData.socket?.connect();
    socketData.socket?.on("connect", (data) {
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
    socketData.socket?.on(
      "askRequestChatNotify",
      (data) {
        debugPrint(
          "----------------------askRequestChatNotify---${socketData.myCurrentChatId}-------------------",
        );
        socketData.socket?.emit(
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

  @override
  void initializeRequest() {
    debugPrint(
      "----------------------initialize------ ${socketData.myCurrentChatId}----------------",
    );
    //!  For Client 1
    socketData.socket
        ?.emit("askRequestChat", {"to": socketData.myCurrentChatId});
  }

  ///-----------------------------------------------------
  @override
  void chatClose() {
    if (socketData.partnerCurrentChatId.isNotEmpty &&
        socketData.myUserId == socketData.partnerCurrentChatId) {
      socketData.socket?.emit(
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

mixin _SocketServiceInitialize {
  /// ## Assume there has Client 1 and Client 2.
  ///
  /// 🙋‍♂️ Client 1 is the sender or request to start the real time communication.
  ///
  /// 🙆‍♀️ Client 2 will be accept the request from Client 2.
  ///
  /// 📲 Assume like that flow ...
  ///
  void _initialize() {
    final socketData = SocketData();
    //! For Both Client 1 and Client 2 to share their current chatting user
    socketData.socket?.on(
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
          socketData.socket?.emit(
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
    socketData.socket?.on("updatePartnerInfoNotify", (data) async {
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
}
