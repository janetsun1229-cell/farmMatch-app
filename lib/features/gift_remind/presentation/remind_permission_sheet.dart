import 'package:flutter/material.dart';

import '../../../core/theme/farm_theme.dart';

class RemindPermissionSheet extends StatelessWidget {
  const RemindPermissionSheet({
    super.key,
    required this.onAllow,
    required this.onLater,
  });

  final VoidCallback onAllow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          key: const Key('remind-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Allow reminders?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: FarmColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Friends can send you a tool. You can skip.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('remind-allow'),
              onPressed: onAllow,
              child: const Text('Allow'),
            ),
            TextButton(
              key: const Key('remind-skip'),
              onPressed: onLater,
              child: const Text(
                'Not now',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
