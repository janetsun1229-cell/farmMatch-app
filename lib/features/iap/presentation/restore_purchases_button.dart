import 'package:flutter/material.dart';

class RestorePurchasesButton extends StatelessWidget {
  const RestorePurchasesButton(
      {super.key, required this.onPressed, required this.busy});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('restore-purchases'),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Restore Purchases'),
    );
  }
}
