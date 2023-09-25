import "package:jack_rtc_call/src/web_rtc/rtc_base.dart";

abstract class SocketDataChannelAbstract {
  final rtcConnection = RTCConnections();

  void initializeDataChannel();
}
