import "package:jack_rtc_call/src/socket/socket_data.dart";

abstract class SocketServicesAbstract {
  final socketData = SocketData();

  void connectToServer(dynamic redirectToOffer);

  void initializeRequest();

  void chatClose();
}
