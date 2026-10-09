import 'package:flutter/material.dart';

class GiftDot extends StatelessWidget {
  const GiftDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('gift-dot'),
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Color(0xFFE23B3B),
        shape: BoxShape.circle,
      ),
    );
  }
}
