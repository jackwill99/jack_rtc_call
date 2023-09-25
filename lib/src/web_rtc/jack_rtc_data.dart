//
// Created by Jack Will on 28/06/2023.
// https://github.com/jackwill99
// This file is created for only public attributes of class

import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:jack_rtc_call/src/web_rtc/media_services.dart";
import "package:rxdart/rxdart.dart";

class JackRTCData {
  late Future<dynamic> Function() toRoute;

  ValueStream<RTCVideoRenderer?> get onLocalRTCMedia {
    return RTCMediaService.I.localRTCVideoRenderer.stream;
  }

  ValueStream<MediaStream?> get onLocalStream {
    return RTCMediaService.I.localStream.stream;
  }

  ValueStream<RTCVideoRenderer?> get onRemoteRTCMedia {
    return RTCMediaService.I.remoteRTCVideoRenderer.stream;
  }
}
