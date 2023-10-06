import "package:socket_io_client/socket_io_client.dart";

class SocketData {
  factory SocketData() {
    return I;
  }

  SocketData._();

  static final SocketData I = SocketData._();

  /// WebSocket Server url
  late String socketUrl;

  /// My own user account id
  late String myUserId;

  /// default is `empty string`
  /// User Id that currently chat
  String myCurrentChatId = "";

  /// `Session Description Protocol` is created or not
  /// When user is connected to another communication, it will be true
  bool hasSDP = false;

  //!Client 1 is Subject Start -> Login Doctor

  /// Partner means the person that you want to chat
  /// [partnerCurrentChatId] is the Id of the user who is connected with your partner
  /// If this id and your user id are same, that means you both are connected with each other
  String partnerCurrentChatId = "";
  bool partnerHasSDP = false;

  Socket? socket;

  /// Set up and config the socket
  void settingSocket() {
    socket = io(
      socketUrl,
      <String, dynamic>{
        "transports": ["websocket"],
        "query": {"userId": myUserId},
        "forceNew": true,
        // 'path': '/sockets.io',
      },
    );
  }


  dynamic tempOffer;

  /// my current partner id in media calling
  String myCurrentCallPartnerId = "";
}
