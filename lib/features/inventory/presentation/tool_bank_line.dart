import 'package:flutter/material.dart';

import '../domain/tool_inventory.dart';

class ToolBankLine extends StatelessWidget {
  const ToolBankLine({super.key, required this.inventory});

  final ToolInventory inventory;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Move ${inventory.move}   Undo ${inventory.undo}   Shuffle ${inventory.shuffle}',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}
