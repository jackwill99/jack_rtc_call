import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:jack_rtc_call/src/socket/socket_data.dart";
import "package:jack_rtc_call/src/web_rtc/rtc_connection.dart";

abstract class SocketMediaAbstract {
  final socketData = SocketData();

  final rtcConnection = RTCConnections();

  void initializeMedia();

  Future<void> socketSDPAnswer({
    required Map<String, dynamic> data,
    bool isVideo = false,
  });

  Future<void> acceptCallSocket(RTCSessionDescription answer);

  void videoMutedSocket({required bool status});

  void endCallSocket();

  void cancelCallSocket();
}
