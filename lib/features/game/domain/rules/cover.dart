import '../tile_card.dart';

bool tilesOverlap(TileCard a, TileCard b) {
  final iw = _min(a.x + a.w, b.x + b.w) - _max(a.x, b.x);
  final ih = _min(a.y + a.h, b.y + b.h) - _max(a.y, b.y);
  return iw > 0.02 && ih > 0.02;
}

bool isCovered(TileCard card, List<TileCard> cards) {
  for (final other in cards) {
    if (other.layer > card.layer && tilesOverlap(card, other)) return true;
  }
  return false;
}

int coverDepth(TileCard card, List<TileCard> cards) {
  final layers = <int>{};
  for (final other in cards) {
    if (other.layer <= card.layer) continue;
    if (tilesOverlap(card, other)) layers.add(other.layer);
  }
  return layers.length;
}

/// Veil opacity by cover depth. Param IDs VEIL_OPACITY_DEPTH_*.
double veilOpacityForDepth(int depth) {
  if (depth <= 0) return 0;
  if (depth == 1) return 0.25;
  if (depth == 2) return 0.35;
  if (depth == 3) return 0.45;
  return 0.55;
}

List<TileCard> freeCards(List<TileCard> cards) {
  return cards.where((card) => !isCovered(card, cards)).toList();
}

double _min(double a, double b) => a < b ? a : b;

double _max(double a, double b) => a > b ? a : b;
