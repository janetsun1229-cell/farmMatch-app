import 'item_type.dart';

class TileCard {
  const TileCard({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.layer,
    required this.pile,
    required this.rot,
  });

  final String id;
  final ItemType type;
  final double x;
  final double y;
  final double w;
  final double h;
  final int layer;
  final bool pile;
  final double rot;

  TileCard copyWith({ItemType? type}) {
    return TileCard(
      id: id,
      type: type ?? this.type,
      x: x,
      y: y,
      w: w,
      h: h,
      layer: layer,
      pile: pile,
      rot: rot,
    );
  }
}
