import '../domain/gift_notice.dart';
import '../domain/ports/notification_port.dart';

class FakeNotificationAdapter implements NotificationPort {
  final List<GiftNotice> _posted = [];
  var _permissionRequests = 0;

  @override
  List<GiftNotice> get posted => List.unmodifiable(_posted);

  @override
  int get permissionRequests => _permissionRequests;

  @override
  Future<bool> requestPermission() async {
    _permissionRequests += 1;
    return true;
  }

  @override
  Future<void> show(GiftNotice notice) async {
    _posted.add(notice);
  }
}
