import 'package:flutter/material.dart';

class NicknameField extends StatelessWidget {
  const NicknameField(
      {super.key, required this.controller, required this.onSave, this.error});

  final TextEditingController controller;
  final VoidCallback onSave;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nickname',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        TextField(
          key: const Key('nickname-field'),
          controller: controller,
          maxLength: 16,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFFF6E4),
            errorText: error,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onSubmitted: (_) => onSave(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: onSave, child: const Text('Save')),
        ),
      ],
    );
  }
}
