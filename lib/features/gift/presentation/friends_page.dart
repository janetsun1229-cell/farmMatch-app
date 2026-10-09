import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/farm_theme.dart';
import '../../auth/domain/auth_provider_kind.dart';
import '../../deeplink/presentation/growth_toast.dart';
import '../../game/domain/power.dart';
import '../application/claim_daily_gift.dart';
import '../application/send_daily_gift.dart';
import '../domain/daily_gift_policy.dart';
import '../domain/friend_profile.dart';
import '../domain/incoming_gift.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  List<FriendProfile> _friends = const [];
  List<IncomingGift> _inbox = const [];
  OutboundDay? _outbound;
  var _loading = true;
  String? _inviteCode;
  String? _inviteLink;
  Power _tool = Power.move;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(giftRemindProvider.notifier)
          .markFriendsOpened(DateTime.now());
      await _reload();
    });
  }

  Future<void> _reload() async {
    final link = ref.read(authStateProvider).link;
    if (link == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _friends = const [];
          _inbox = const [];
          _outbound = null;
        });
      }
      return;
    }
    final port = ref.read(giftPortProvider);
    final day = DailyGiftPolicy.dayKey(DateTime.now());
    final friends = await port.listFriends(link.accountId);
    final inbox = await port.inbox(link.accountId);
    final outbound = await port.outbound(link.accountId, day);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _friends = friends;
      _inbox = inbox;
      _outbound = outbound;
      if (outbound.tool != null) _tool = outbound.tool!;
    });
  }

  Future<void> _bind(AuthProviderKind provider) async {
    final error = await ref.read(authStateProvider.notifier).bind(provider);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _reload();
  }

  Future<void> _shareGame() async {
    final user = ref.read(identityProvider);
    final issued = await ref.read(inviteDirectoryProvider).issue(
          accountId: user.id,
          displayName: user.nickname,
          bound: false,
        );
    await Clipboard.setData(ClipboardData(text: issued.link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Link copied. Boosts for both of you start after you link X or Facebook.',
        ),
      ),
    );
  }

  Future<void> _invite() async {
    final link = ref.read(authStateProvider).link;
    if (link == null) return;
    final issued = await ref.read(inviteDirectoryProvider).issue(
          accountId: link.accountId,
          displayName: link.displayName,
          bound: true,
        );
    final result = await ref.read(giftPortProvider).invite(link.accountId);
    if (!mounted) return;
    setState(() {
      _inviteLink = issued.link;
      _inviteCode = result.code;
    });
    await _reload();
    await ref.read(giftRemindProvider.notifier).noteForegroundGift();
  }

  Future<void> _send(FriendProfile friend) async {
    final link = ref.read(authStateProvider).link;
    if (link == null) return;
    final day = DailyGiftPolicy.dayKey(DateTime.now());
    final result = await SendDailyGift(ref.read(giftPortProvider)).call(
      accountId: link.accountId,
      friendId: friend.id,
      tool: _tool,
      dayKey: day,
    );
    if (!mounted) return;
    final locked = result.lockedTool ?? _outbound?.tool;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Gift sent. Your own tools stay put.'
              : giftDenyMessage(result.deny, lockedTool: locked),
        ),
      ),
    );
    await _reload();
  }

  Future<void> _claim(IncomingGift gift) async {
    final link = ref.read(authStateProvider).link;
    if (link == null || gift.claimed) return;
    final next = await ClaimDailyGift(
      port: ref.read(giftPortProvider),
      inventory: ref.read(inventoryRepoProvider),
    ).call(accountId: link.accountId, giftId: gift.id);
    if (next != null) {
      await ref.read(localRevisionProvider).touch();
      await ref.read(authStateProvider.notifier).syncFromCloud();
    }
    await ref.read(giftRemindProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next == null
              ? 'That gift was already claimed.'
              : '${gift.tool.label} added to your tools.',
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final day = _outbound;
    final sendsLeft = day?.sendsLeft ?? OutboundDay.maxSends;
    return GrowthToastListener(
      child: SkyBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: FarmColors.ink,
            title: const Text(
              'Friends & gifts',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                if (!auth.bound) ...[
                  const Text(
                    'Link X or Facebook to gift free daily tools and save progress. You can keep playing either way.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('friends-bind-x'),
                    onPressed: () => _bind(AuthProviderKind.x),
                    child: const Text('Link X'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('friends-bind-facebook'),
                    onPressed: () => _bind(AuthProviderKind.facebook),
                    child: const Text('Link Facebook'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('share-game'),
                    onPressed: _shareGame,
                    child: const Text('Share the game'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sharing before you link copies the game only. Boosts for both of you start after you link X or Facebook.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Free gifts left today: $sendsLeft',
                    key: const Key('gifts-left'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pick one tool for today. Sends come from a free pool and do not use your own tools.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final power in Power.values) ...[
                        if (power != Power.move) const SizedBox(width: 8),
                        Expanded(
                          child: _ToolPick(
                            power: power,
                            selected: _tool == power,
                            enabled: day?.tool == null || day!.tool == power,
                            onPressed: () => setState(() => _tool = power),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Invite friends — you both get free boosts.',
                    key: Key('invite-rewards-copy'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('invite-friend'),
                    onPressed: _loading ? null : _invite,
                    child: const Text('Invite a friend'),
                  ),
                  if (_inviteLink != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _inviteLink!,
                      key: const Key('invite-link'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton(
                      key: const Key('copy-invite-link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _inviteLink!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite link copied.')),
                        );
                      },
                      child: const Text('Copy invite link'),
                    ),
                  ],
                  if (_inviteCode != null) ...[
                    Text(
                      'Invite code: $_inviteCode',
                      key: const Key('invite-code'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_friends.isEmpty)
                    const Text(
                      'Invite a friend to gift free daily tools.',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    )
                  else
                    for (final friend in _friends)
                      _FriendRow(
                        friend: friend,
                        sent: day?.sentFriendIds.contains(friend.id) ?? false,
                        canSend: sendsLeft > 0 &&
                            !(day?.sentFriendIds.contains(friend.id) ?? false),
                        onSend: () => _send(friend),
                      ),
                  const SizedBox(height: 18),
                  Text(
                    _inbox.where((gift) => !gift.claimed).isEmpty
                        ? 'Gifts for you'
                        : 'Gifts for you (${_inbox.where((gift) => !gift.claimed).length})',
                    key: const Key('gifts-unread'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_inbox.isEmpty)
                    const Text(
                      'No gifts yet today.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    )
                  else
                    for (final gift in _inbox)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${gift.fromName} sent ${gift.tool.label}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(gift.dayKey),
                        trailing: gift.claimed
                            ? const Text(
                                'Claimed',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              )
                            : FilledButton(
                                key: Key('claim-${gift.id}'),
                                onPressed: () => _claim(gift),
                                child: const Text('Claim'),
                              ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolPick extends StatelessWidget {
  const _ToolPick({
    required this.power,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final Power power;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: Key('gift-tool-${power.name}'),
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? FarmColors.leaf : FarmColors.cream,
        foregroundColor: selected ? Colors.white : FarmColors.ink,
        side: BorderSide(
          color: selected ? FarmColors.leaf : const Color(0xFF8A6340),
          width: 2,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
      child: Text(power.label),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.sent,
    required this.canSend,
    required this.onSend,
  });

  final FriendProfile friend;
  final bool sent;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FarmColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8A6340)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              friend.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          if (sent)
            const Text('Sent', style: TextStyle(fontWeight: FontWeight.w800))
          else
            FilledButton(
              key: Key('send-${friend.id}'),
              onPressed: canSend ? onSend : null,
              child: const Text('Send'),
            ),
        ],
      ),
    );
  }
}
