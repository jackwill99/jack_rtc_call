import "package:rxdart/rxdart.dart";

abstract class MiscSocketServiceAbstract {
  /// Reactive status of user online
  final isOnline = BehaviorSubject<bool>.seeded(true);

  /// User id who becomes active online. When isOnline status changes, update the id to the current active user.
  String? id;

  /// Reactive caller name. When any call is incoming, update the caller name by reactive. At the same time, you can get the update data of callHandler and avatar of incoming call
  final callerName = BehaviorSubject<String?>.seeded(null);

  String? callHandler;
  String? avatar;

  Future<void> initialize();
}
