import 'package:flutter/material.dart';

import '../features/game/domain/item_type.dart';

class ItemGlyph extends StatelessWidget {
  const ItemGlyph(
      {super.key, required this.type, this.padding = EdgeInsets.zero});

  final ItemType type;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Image.asset(
        type.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => _FallbackGlyph(type: type),
      ),
    );
  }
}

class _FallbackGlyph extends StatelessWidget {
  const _FallbackGlyph({required this.type});

  final ItemType type;

  static const _colors = {
    'scissors': Color(0xFF8D9AA6),
    'bucket': Color(0xFF3D8EF0),
    'brush': Color(0xFFC47A3A),
    'carrot': Color(0xFFF28A1A),
    'gloves': Color(0xFFF2D15A),
    'corn': Color(0xFFF2C230),
    'wool': Color(0xFFF7F7F2),
    'milk': Color(0xFFFFFDF8),
    'hay': Color(0xFFE2C16A),
    'fork': Color(0xFF9AA3A8),
    'pumpkin': Color(0xFFF07818),
    'apple': Color(0xFFE23B3B),
    'mower': Color(0xFF3CAA45),
    'boots': Color(0xFF8A5A32),
    'can': Color(0xFF3CB8C8),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[type.id] ?? const Color(0xFFCCCCCC);
    return DecoratedBox(
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Text(
          type.label.substring(0, 1),
          style: const TextStyle(
              fontWeight: FontWeight.w900, color: Color(0xFF3D2914)),
        ),
      ),
    );
  }
}
