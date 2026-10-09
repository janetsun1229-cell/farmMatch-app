import '../../game/domain/power.dart';

class IncomingGift {
  const IncomingGift({
    required this.id,
    required this.fromFriendId,
    required this.fromName,
    required this.tool,
    required this.dayKey,
    required this.claimed,
  });

  final String id;
  final String fromFriendId;
  final String fromName;
  final Power tool;
  final String dayKey;
  final bool claimed;

  IncomingGift copyWith({bool? claimed}) {
    return IncomingGift(
      id: id,
      fromFriendId: fromFriendId,
      fromName: fromName,
      tool: tool,
      dayKey: dayKey,
      claimed: claimed ?? this.claimed,
    );
  }
}
