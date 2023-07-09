import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:jack_rtc_call/socket/socket_services.dart';
import 'package:rxdart/rxdart.dart';

class MiscSocketService {
  MiscSocketService._();

  static final isOnline = BehaviorSubject<bool>.seeded(true);
  static String? id;

  static final callerName = BehaviorSubject<String?>.seeded(null);
  static String? callHandler;
  static String? avatar;

  static Future<void> initialize() async {
    final socketData = GetIt.instance<SocketData>();

    socketData.getSocket.on("onlineStatusNotify", (data) async {
      debugPrint(
          "----------------------onlineStatusNotify $data----------------------");
      id = data['id'];
      isOnline.add(data['status'] == 0 ? false : true);
    });
  }
}
