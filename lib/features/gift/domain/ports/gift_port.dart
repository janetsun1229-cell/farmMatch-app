import '../../../game/domain/power.dart';
import '../daily_gift_policy.dart';
import '../friend_profile.dart';
import '../incoming_gift.dart';

class SendGiftResult {
  const SendGiftResult({required this.deny, this.ledger, this.lockedTool});

  final GiftDeny deny;
  final OutboundDay? ledger;
  final Power? lockedTool;

  bool get ok => deny == GiftDeny.ok;
}

class InviteResult {
  const InviteResult({required this.friend, required this.code});

  final FriendProfile friend;
  final String code;
}

abstract class GiftPort {
  Future<List<FriendProfile>> listFriends(String accountId);
  Future<InviteResult> invite(String accountId);
  Future<OutboundDay> outbound(String accountId, String dayKey);
  Future<List<IncomingGift>> inbox(String accountId);
  Future<SendGiftResult> send({
    required String accountId,
    required String friendId,
    required Power tool,
    required String dayKey,
  });
  Future<IncomingGift?> claim({
    required String accountId,
    required String giftId,
  });
}
