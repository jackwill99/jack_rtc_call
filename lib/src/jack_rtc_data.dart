//
// Created by Jack Will on 28/06/2023.
// https://github.com/jackwill99
// This file is created for only public attributes of class

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:jack_rtc_call/socket/socket_services.dart';
import 'package:jack_rtc_call/web_rtc/media_services.dart';
import 'package:rxdart/rxdart.dart';

class JackRTCData {
  final socketData = SocketData();

  late Future<dynamic> Function() toRoute;

  ValueStream<RTCVideoRenderer?> get onLocalRTCMedia {
    return RTCMediaService.localRTCVideoRenderer.stream;
  }

  ValueStream<MediaStream?> get onLocalStream {
    return RTCMediaService.localStream.stream;
  }

  ValueStream<RTCVideoRenderer?> get onRemoteRTCMedia {
    return RTCMediaService.remoteRTCVideoRenderer.stream;
  }

  /// To change the chat id that I want
  void setMyCurrentChatId(String value) {
    socketData.myCurrentChatId = value;
  }

  String get getMyCurrentChatId => socketData.myCurrentChatId;

  /// To set status that have I SDP
  void setMyOwnSDP(bool value) {
    socketData.hasSDP = value;
  }
}
