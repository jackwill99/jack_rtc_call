import "package:jack_rtc_call/src/web_rtc/rtc_connection.dart";

abstract class SocketDataChannelAbstract {
  final RTCConnections rtcConnection = RTCConnections();

  void initializeDataChannel();
}
