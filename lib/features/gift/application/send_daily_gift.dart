import '../../game/domain/power.dart';
import '../domain/ports/gift_port.dart';

/// Sends from the free daily pool. Does not read or write tool inventory.
class SendDailyGift {
  const SendDailyGift(this._port);

  final GiftPort _port;

  Future<SendGiftResult> call({
    required String accountId,
    required String friendId,
    required Power tool,
    required String dayKey,
  }) {
    return _port.send(
      accountId: accountId,
      friendId: friendId,
      tool: tool,
      dayKey: dayKey,
    );
  }
}
