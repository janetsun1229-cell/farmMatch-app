import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/farm_theme.dart';
import '../../../../shared/item_glyph.dart';
import '../../domain/item_type.dart';
import '../../domain/level/dealer.dart';
import '../../domain/rules/cover.dart';
import '../../domain/tile_card.dart';

class BoardMetrics {
  const BoardMetrics({
    required this.minX,
    required this.minY,
    required this.step,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  static const pad = 0.08;

  final double minX;
  final double minY;
  final double step;
  final double pixelWidth;
  final double pixelHeight;

  static double? _lockedStep;

  static BoardMetrics layout({
    required List<TileCard> cards,
    required double availWidth,
    required double scale,
    required int maxColumns,
  }) {
    var minX = 0.0;
    var minY = 0.0;
    var maxX = 1.0;
    var maxY = 1.0;
    if (cards.isNotEmpty) {
      minX = cards.map((card) => card.x).reduce(math.min);
      minY = cards.map((card) => card.y).reduce(math.min);
      maxX = cards.map((card) => card.x + card.w).reduce(math.max);
      maxY = cards.map((card) => card.y + card.h).reduce(math.max);
    }
    final fieldW = (maxX - minX) + pad * 2;
    final fieldH = (maxY - minY) + pad * 2;
    final l1 = Dealer.measure(1);
    final l1W = (l1.maxX - l1.minX) + pad * 2;
    final raw = availWidth / math.max(0.1, l1W);
    _lockedStep ??= raw.clamp(52.0, 104.0) * scale;
    final cap = math.min(availWidth, _lockedStep! * maxColumns);
    var step = _lockedStep!;
    if (fieldW > 0) step = math.min(step, cap / fieldW);
    step = math.max(34.0, step);
    return BoardMetrics(
      minX: minX - pad,
      minY: minY - pad,
      step: step,
      pixelWidth: fieldW * step,
      pixelHeight: fieldH * step,
    );
  }

  Rect rectFor(TileCard card) {
    return Rect.fromLTWH(
      (card.x - minX) * step,
      (card.y - minY) * step,
      card.w * step,
      card.h * step,
    );
  }
}

class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.cards,
    required this.metrics,
    required this.veilFor,
    required this.onTap,
    this.hintCardId,
  });

  final List<TileCard> cards;
  final BoardMetrics metrics;
  final double Function(int depth) veilFor;
  final void Function(TileCard card, Rect globalRect) onTap;
  final String? hintCardId;

  @override
  Widget build(BuildContext context) {
    final ordered = [...cards]..sort((a, b) {
        final za = a.layer * 1000 + (a.y * 100).round();
        final zb = b.layer * 1000 + (b.y * 100).round();
        return za.compareTo(zb);
      });
    TileCard? hint;
    if (hintCardId != null) {
      for (final card in cards) {
        if (card.id == hintCardId) hint = card;
      }
    }
    return SizedBox(
      width: metrics.pixelWidth,
      height: metrics.pixelHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final card in ordered)
            _Tile(
              card: card,
              rect: metrics.rectFor(card),
              covered: isCovered(card, cards),
              veil: veilFor(coverDepth(card, cards)),
              onTap: onTap,
            ),
          if (hint != null)
            Positioned(
              left: metrics.rectFor(hint).center.dx - 28,
              top: metrics.rectFor(hint).bottom - 8,
              child: const IgnorePointer(
                child: Image(
                  image: AssetImage('assets/images/ui/tip-hand.png'),
                  width: 56,
                  height: 56,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.card,
    required this.rect,
    required this.covered,
    required this.veil,
    required this.onTap,
  });

  final TileCard card;
  final Rect rect;
  final bool covered;
  final double veil;
  final void Function(TileCard card, Rect globalRect) onTap;

  @override
  Widget build(BuildContext context) {
    final hideFace = card.pile && covered;
    final wool = card.type == ItemType.wool;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: covered
                ? null
                : () {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null || !box.hasSize) return;
                    final topLeft = box.localToGlobal(Offset.zero);
                    onTap(card, topLeft & box.size);
                  },
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: wool
                      ? const [Color(0xFFE9F8D8), FarmColors.wool]
                      : const [Color(0xFFFFFAF0), FarmColors.creamDeep],
                ),
                border: Border.all(
                  color: covered ? const Color(0xFFDFC686) : FarmColors.gold,
                  width: 1.6,
                ),
                boxShadow: covered
                    ? const [
                        BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 2,
                            offset: Offset(0, 2))
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0x66B89252),
                            offset: Offset(0, 5),
                            blurRadius: 0),
                        BoxShadow(
                            color: Color(0x3328140A),
                            offset: Offset(0, 8),
                            blurRadius: 8),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!hideFace)
                      ItemGlyph(
                          type: card.type, padding: const EdgeInsets.all(5)),
                    if (veil > 0)
                      ColoredBox(
                          color: FarmColors.veil.withValues(alpha: veil)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
