import '../gift_notice.dart';

/// System notifications. Tests and local play use a fake that records posts.
/// A store build can forward [show] to the platform. Permission is requested
/// only after the level-8 invite flow or the first gift, never at launch.
abstract class NotificationPort {
  Future<bool> requestPermission();

  Future<void> show(GiftNotice notice);

  List<GiftNotice> get posted;

  int get permissionRequests;
}
