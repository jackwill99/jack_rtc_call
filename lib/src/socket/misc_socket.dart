import "package:flutter/foundation.dart";
import "package:get_it/get_it.dart";
import "package:jack_rtc_call/model/socket/misc_socket_abstract.dart";
import "package:jack_rtc_call/src/socket/socket_services.dart";

@protected
class MiscSocketService extends MiscSocketServiceAbstract {
  factory MiscSocketService() {
    return I;
  }

  MiscSocketService._();

  static final MiscSocketService I = MiscSocketService._();

  @override
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
