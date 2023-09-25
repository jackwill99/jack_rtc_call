import "package:flutter/foundation.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";
import "package:rxdart/rxdart.dart";

@protected
class MiscSocketService {
  factory MiscSocketService() {
    return I;
  }

  MiscSocketService._();

  static final MiscSocketService I = MiscSocketService._();

  final isOnline = BehaviorSubject<bool>.seeded(true);
  String? id;

  final callerName = BehaviorSubject<String?>.seeded(null);
  String? callHandler;
  String? avatar;

  Future<void> initialize() async {
    final socketData = GetIt.instance<SocketData>();

    socketData.socket.on("onlineStatusNotify", (data) async {
      debugPrint(
        "----------------------onlineStatusNotify $data----------------------",
      );
      id = (data as Map<String, dynamic>)["id"];
      isOnline.add(data["status"] == 1);
    });
  }
}
