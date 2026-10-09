import 'package:flutter/material.dart';

class AdsStatusLine extends StatelessWidget {
  const AdsStatusLine({super.key, required this.removeAds});

  final bool removeAds;

  @override
  Widget build(BuildContext context) {
    if (!removeAds) return const SizedBox.shrink();
    return const Text('Ads removed.',
        style: TextStyle(fontWeight: FontWeight.w800));
  }
}
