import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/farm_theme.dart';
import '../domain/gift_remind_policy.dart';
import 'remind_permission_sheet.dart';

/// Shows the notification permission sheet only after a session asks for it.
/// The initial value is [RemindAsk.none], so a cold start does not prompt.
class GiftRemindHost extends ConsumerStatefulWidget {
  const GiftRemindHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GiftRemindHost> createState() => _GiftRemindHostState();
}

class _GiftRemindHostState extends ConsumerState<GiftRemindHost> {
  var _showing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<RemindAsk>(remindPromptProvider, (previous, next) {
      if (next == RemindAsk.none || next == previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(next));
    });
    return widget.child;
  }

  Future<void> _show(RemindAsk ask) async {
    if (!mounted || _showing) return;
    if (ref.read(remindPromptProvider) != ask) return;
    _showing = true;
    final allow = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: FarmColors.cream,
      builder: (sheetContext) {
        return RemindPermissionSheet(
          onAllow: () => Navigator.pop(sheetContext, true),
          onLater: () => Navigator.pop(sheetContext, false),
        );
      },
    );
    _showing = false;
    if (!mounted) return;
    final store = ref.read(giftRemindStoreProvider);
    if (ask == RemindAsk.afterInvite) {
      await store.markAskedInvite();
    } else if (ask == RemindAsk.afterFirstGift) {
      await store.markAskedGift();
    }
    if (allow == true) {
      await ref.read(notificationPortProvider).requestPermission();
      await store.setGranted(true);
    }
    ref.read(remindPromptProvider.notifier).clear();
  }
}
