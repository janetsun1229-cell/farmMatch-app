import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// Shows a one-shot growth message. Cold start sets the message before the
/// destination page subscribes, so the first frame also checks the current value.
class GrowthToastListener extends ConsumerStatefulWidget {
  const GrowthToastListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GrowthToastListener> createState() =>
      _GrowthToastListenerState();
}

class _GrowthToastListenerState extends ConsumerState<GrowthToastListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  void _show() {
    if (!mounted) return;
    final message = ref.read(growthToastProvider);
    if (message == null || message.isEmpty) return;
    ref.read(growthToastProvider.notifier).clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, key: const Key('growth-toast'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(growthToastProvider, (previous, next) {
      if (next == null || next.isEmpty || next == previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    });
    return widget.child;
  }
}
