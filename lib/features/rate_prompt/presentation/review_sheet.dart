import 'package:flutter/material.dart';

import '../../../core/theme/farm_theme.dart';

class ReviewOfferSheet extends StatelessWidget {
  const ReviewOfferSheet({
    super.key,
    required this.onRate,
    required this.onLater,
  });

  final VoidCallback onRate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          key: const Key('review-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enjoying Farm Match?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: FarmColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Rate Farm Match if the porch is treating you well. You can skip.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('review-rate'),
              onPressed: onRate,
              child: const Text('Rate'),
            ),
            TextButton(
              key: const Key('review-later'),
              onPressed: onLater,
              child: const Text(
                'Later',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
