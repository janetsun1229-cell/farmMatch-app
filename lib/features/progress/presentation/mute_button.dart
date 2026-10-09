import 'package:flutter/material.dart';

class MuteButton extends StatelessWidget {
  const MuteButton({super.key, required this.muted, required this.onPressed});

  final bool muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: muted ? 'Unmute' : 'Mute',
      child: IconButton(
        key: const Key('mute'),
        onPressed: onPressed,
        iconSize: 44,
        icon: Image.asset(
          muted
              ? 'assets/images/ui/mute-off.png'
              : 'assets/images/ui/mute-on.png',
          width: 44,
          height: 44,
        ),
      ),
    );
  }
}
