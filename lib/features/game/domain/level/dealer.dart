import 'dart:math' as math;

import '../item_type.dart';
import '../tile_card.dart';
import 'js_rng.dart';
import 'level_plan.dart';

/// Layout unit used by the HTML prototype. Pixel scale is applied in the view
/// (`CARD_SCALE_VS_L1` = 0.85) so every level shares one card size.
const double kLayoutCard = 0.88;

class DealResult {
  const DealResult({required this.cards, required this.solution});

  final List<TileCard> cards;

  /// A known clearing order: each group of three shares a type and is free
  /// when picked. Used to prove the deal is solvable.
  final List<String> solution;
}

class _Slot {
  _Slot({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.layer,
    this.pile = false,
    this.rot = 0,
    this.col,
    this.row,
  });

  double x;
  double y;
  double w;
  double h;
  int layer;
  bool pile;
  double rot;
  int? col;
  int? row;
  String? type;
  String id = '';
}

class Dealer {
  Dealer._();

  static final Map<int, DealResult> _cache = {};

  static DealResult deal(int level) {
    final cached = _cache[level];
    if (cached != null) {
      return DealResult(
        cards: List<TileCard>.from(cached.cards),
        solution: List<String>.from(cached.solution),
      );
    }
    final dealt = _deal(level);
    _cache[level] = dealt;
    return DealResult(
      cards: List<TileCard>.from(dealt.cards),
      solution: List<String>.from(dealt.solution),
    );
  }

  static ({double minX, double minY, double maxX, double maxY}) measure(
      int level) {
    final spots = _positions(level, 0);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    for (final card in spots) {
      minX = math.min(minX, card.x);
      minY = math.min(minY, card.y);
      maxX = math.max(maxX, card.x + card.w);
      maxY = math.max(maxY, card.y + card.h);
    }
    return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  static DealResult _deal(int level) {
    for (var bump = 0; bump < 16; bump++) {
      final spots = _positions(level, bump);
      for (var i = 0; i < spots.length; i++) {
        spots[i].id = 'c${i + 1}';
      }
      final solution = _assign(spots, level);
      if (solution != null) {
        return DealResult(
          cards: spots.map(_freeze).toList(),
          solution: solution,
        );
      }
    }
    throw StateError('layout cannot be dealt $level');
  }

  static TileCard _freeze(_Slot slot) {
    return TileCard(
      id: slot.id,
      type: ItemType.byId(slot.type!),
      x: slot.x,
      y: slot.y,
      w: slot.w,
      h: slot.h,
      layer: slot.layer,
      pile: slot.pile,
      rot: slot.rot,
    );
  }

  static double _pileSlide() => kLayoutCard / 10;

  static bool _overlaps(_Slot a, _Slot b) {
    final iw = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x);
    final ih = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y);
    return iw > 0.02 && ih > 0.02;
  }

  static bool _isCovered(_Slot card, List<_Slot> cards) {
    for (final other in cards) {
      if (other.layer > card.layer && _overlaps(card, other)) return true;
    }
    return false;
  }

  static List<_Slot> _freeCards(List<_Slot> cards) {
    return cards.where((card) => !_isCovered(card, cards)).toList();
  }

  static void _nudgeField(List<_Slot> cards, int level, int bump) {
    final rand = JsRng(level * 6271 + 29 + bump * 7919);
    final px = rand.next() * math.pi * 2;
    final py = rand.next() * math.pi * 2;
    final ax = kLayoutCard * 0.25;
    final ay = kLayoutCard * 0.2;
    for (final card in cards) {
      if (card.pile) continue;
      card.x += ax * math.sin(card.x * 0.2 + px);
      card.y += ay * math.sin(card.y * 0.22 + py);
    }
  }

  static ({double maxX, double maxY}) _staggerBand(int level) {
    if (level <= 2) return (maxX: 0.08, maxY: 0.06);
    if (level <= 10) {
      final progress = (level - 3) / 7;
      return (maxX: 0.18 + progress * 0.07, maxY: 0.12 + progress * 0.08);
    }
    if (level <= 25) {
      final progress = (level - 11) / 14;
      return (maxX: 0.26 + progress * 0.07, maxY: 0.18 + progress * 0.07);
    }
    final progress = (level - 26) / 24;
    return (maxX: 0.32 + progress * 0.08, maxY: 0.24 + progress * 0.09);
  }

  static void _staggerLayers(int level, List<List<_Slot>> grids, int bump) {
    final rand = JsRng(level * 503 + 11 + bump * 9973);
    final band = _staggerBand(level);
    final plan = LevelPlan.forLevel(level);
    final neat = level <= 2;
    final sx = rand.next() < 0.5 ? -1.0 : 1.0;
    final sy = rand.next() < 0.5 ? -1.0 : 1.0;
    for (var li = 1; li < grids.length; li++) {
      final upper = grids[li];
      final lower = grids[li - 1];
      final below = plan.grids[li - 1];
      final current = plan.grids[li];
      final startC = ((below[0] - current[0]) / 2).floor();
      final startR = ((below[1] - current[1]) / 2).floor();
      for (final card in upper) {
        final pc = startC + card.col!;
        final pr = startR + card.row!;
        final parent = lower[pr * below[0] + pc];
        if (neat) {
          final ox = sx * kLayoutCard * (0.14 + rand.next() * 0.04);
          final oy = sy * kLayoutCard * (0.1 + rand.next() * 0.03);
          card.x = parent.x + ox;
          card.y = parent.y + oy;
          card.rot = 0;
          continue;
        }
        final easy = level == 5 || level == 8 || level == 12;
        final shrink = easy ? 0.72 : 1.0;
        final dx = (rand.next() * 2 - 1) * kLayoutCard * band.maxX * shrink;
        final dy = (rand.next() * 2 - 1) * kLayoutCard * band.maxY * shrink;
        var ox = dx / kLayoutCard;
        var oy = dy / kLayoutCard;
        final cover = (1 - ox.abs()) * (1 - oy.abs());
        if (cover < 0.26) {
          final scale = math.sqrt(0.3 / math.max(0.08, cover));
          ox /= scale;
          oy /= scale;
        }
        if (cover > 0.42) {
          final bumpCover = 0.34 / cover;
          final extra = 1 + (1 - bumpCover) * 0.35;
          ox *= extra;
          oy *= extra;
          final limX = band.maxX * shrink;
          final limY = band.maxY * shrink;
          if (ox.abs() > limX) ox = ox.sign * limX;
          if (oy.abs() > limY) oy = oy.sign * limY;
        }
        card.x = parent.x + ox * kLayoutCard;
        card.y = parent.y + oy * kLayoutCard;
        card.rot = 0;
      }
    }
  }

  static void _tightenGaps(List<_Slot> cards) {
    final cell = kLayoutCard * 1.1;
    final limit = kLayoutCard / 8;
    for (var pass = 0; pass < 10; pass++) {
      for (var i = 0; i < cards.length; i++) {
        for (var j = i + 1; j < cards.length; j++) {
          final a = cards[i];
          final b = cards[j];
          if (a.pile || b.pile || a.layer != b.layer) continue;
          final ix = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x);
          final iy = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y);
          final cx = ((a.x + a.w / 2) - (b.x + b.w / 2)).abs();
          final cy = ((a.y + a.h / 2) - (b.y + b.h / 2)).abs();
          var axis = '';
          var gap = 0.0;
          if (ix > kLayoutCard * 0.35 && cy < cell * 1.35 && iy < 0) {
            axis = 'y';
            gap = -iy;
          } else if (iy > kLayoutCard * 0.35 && cx < cell * 1.35 && ix < 0) {
            axis = 'x';
            gap = -ix;
          }
          if (axis.isEmpty || gap <= limit) continue;
          final pull = (gap - limit) / 2 + 0.004;
          if (axis == 'x') {
            if (a.x < b.x) {
              a.x += pull;
              b.x -= pull;
            } else {
              a.x -= pull;
              b.x += pull;
            }
          } else if (a.y < b.y) {
            a.y += pull;
            b.y -= pull;
          } else {
            a.y -= pull;
            b.y += pull;
          }
        }
      }
    }
  }

  static void _addPile(List<_Slot> cards, int count, double x, double yTop) {
    final slide = _pileSlide();
    for (var i = 0; i < count; i++) {
      final down = count - 1 - i;
      cards.add(
        _Slot(
          x: x + down * slide,
          y: yTop + down * slide,
          w: kLayoutCard,
          h: kLayoutCard,
          layer: 20 + i,
          pile: true,
          rot: 0,
        ),
      );
    }
  }

  static void _placePiles(List<_Slot> cards, int level, int count, int thick) {
    if (count == 0 || thick == 0) return;
    final rand = JsRng(level * 9176 + 13);
    final extra = (thick - 1) * _pileSlide();
    final pileW = kLayoutCard + extra;
    final pileH = kLayoutCard + extra;
    var minX = cards.map((card) => card.x).reduce(math.min);
    var minY = cards.map((card) => card.y).reduce(math.min);
    var maxX = cards.map((card) => card.x + card.w).reduce(math.max);
    var maxY = cards.map((card) => card.y + card.h).reduce(math.max);
    var overlap = kLayoutCard * 0.5;

    ({double left, double room, int cap}) band() {
      var left = minX + overlap - pileW;
      var xMax = maxX - overlap - pileW;
      if (xMax < left) {
        left = (minX + maxX) / 2 - pileW / 2;
        xMax = left;
      }
      final room = math.max(0.0, xMax - left);
      final cap = math.max(1, ((room + pileW + 0.001) / pileW).floor());
      return (left: left, room: room, cap: cap);
    }

    var fit = band();
    if (count > fit.cap * 2) {
      overlap = 0;
      fit = band();
    }
    if (count > fit.cap * 2) {
      overlap = -kLayoutCard * 0.2;
      fit = band();
    }
    var topN = 0;
    for (var i = 0; i < count; i++) {
      if (rand.next() < 0.5) topN += 1;
    }
    var botN = count - topN;
    while (topN > fit.cap && botN < fit.cap) {
      topN -= 1;
      botN += 1;
    }
    while (botN > fit.cap && topN < fit.cap) {
      botN -= 1;
      topN += 1;
    }
    if (topN > fit.cap || botN > fit.cap) {
      topN = math.min(fit.cap, (count / 2).ceil());
      botN = count - topN;
      if (botN > fit.cap) {
        botN = fit.cap;
        topN = count - botN;
      }
    }

    void row(int rowCount, double yBase, double outward) {
      if (rowCount == 0) return;
      final slack = math.max(0.0, fit.room - (rowCount - 1) * pileW);
      final weights = <double>[];
      var sum = 0.0;
      for (var i = 0; i < rowCount + 1; i++) {
        final weight = 0.25 + rand.next();
        weights.add(weight);
        sum += weight;
      }
      var x = fit.left;
      for (var i = 0; i < rowCount; i++) {
        x += slack * (weights[i] / sum);
        final y = yBase + outward * rand.next() * kLayoutCard * 0.1;
        _addPile(cards, thick, x, y);
        x += pileW;
      }
    }

    row(topN, minY - pileH, -1);
    row(botN, maxY, 1);
  }

  static List<_Slot> _positions(int level, int bump) {
    final plan = LevelPlan.forLevel(level);
    final cell = kLayoutCard + kLayoutCard / 10;
    final grids = <List<_Slot>>[];
    for (var layer = 0; layer < plan.grids.length; layer++) {
      final cols = plan.grids[layer][0];
      final rows = plan.grids[layer][1];
      final grid = <_Slot>[];
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          grid.add(
            _Slot(
              x: c * cell,
              y: r * cell,
              w: kLayoutCard,
              h: kLayoutCard,
              layer: layer,
              col: c,
              row: r,
            ),
          );
        }
      }
      grids.add(grid);
    }
    final cards = grids.expand((grid) => grid).toList();
    _nudgeField(cards, level, bump);
    _staggerLayers(level, grids, bump);
    _tightenGaps(cards);
    for (final card in cards) {
      card.rot = 0;
    }
    _placePiles(cards, level, plan.piles, plan.pileThick);
    return cards;
  }

  static int? _pileId(_Slot card) {
    if (!card.pile) return null;
    return jsRound((card.x - card.y) * 1000);
  }

  static bool _touches(_Slot a, _Slot b) {
    final dx = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x);
    final dy = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y);
    if (dx > 0.04 && dy > 0.04) return true;
    if (dx > kLayoutCard * 0.45 && dy > -kLayoutCard / 8 && dy <= 0.04) {
      return true;
    }
    if (dy > kLayoutCard * 0.45 && dx > -kLayoutCard / 8 && dx <= 0.04) {
      return true;
    }
    return false;
  }

  static Map<_Slot, Set<_Slot>> _buildAdj(List<_Slot> cards) {
    final adj = <_Slot, Set<_Slot>>{};
    for (final card in cards) {
      adj[card] = <_Slot>{};
    }
    for (var i = 0; i < cards.length; i++) {
      for (var j = i + 1; j < cards.length; j++) {
        final a = cards[i];
        final b = cards[j];
        final pa = _pileId(a);
        final pb = _pileId(b);
        if (pa != null && pa == pb) continue;
        if (!_touches(a, b)) continue;
        adj[a]!.add(b);
        adj[b]!.add(a);
      }
    }
    return adj;
  }

  static bool _clumpOk(
      List<_Slot> list, Map<_Slot, Set<_Slot>> adj, String mode) {
    if (mode == 'strict') {
      for (var i = 0; i < list.length; i++) {
        final near = adj[list[i]]!;
        for (var j = i + 1; j < list.length; j++) {
          if (near.contains(list[j])) return false;
        }
      }
      return true;
    }
    final seen = <_Slot>{};
    for (final start in list) {
      if (seen.contains(start)) continue;
      final stack = <_Slot>[start];
      seen.add(start);
      var size = 0;
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        size += 1;
        if (size > 2) return false;
        for (final other in adj[cur]!) {
          if (list.contains(other) && !seen.contains(other)) {
            seen.add(other);
            stack.add(other);
          }
        }
      }
    }
    return true;
  }

  static List<List<_Slot>>? _buildChunks(
    List<_Slot> cards,
    double Function() rand,
    int maxInitial,
    Map<_Slot, Set<_Slot>> adj,
  ) {
    final free0 = _freeCards(cards).toSet();
    final alive = List<_Slot>.from(cards);
    final chunks = <List<_Slot>>[];
    while (alive.isNotEmpty) {
      final chunk = <_Slot>[];
      for (var k = 0; k < 3; k++) {
        final open = _freeCards(alive);
        if (open.isEmpty) return null;
        final buried = open.where((card) => !free0.contains(card)).toList();
        final ini = open.where((card) => free0.contains(card)).toList();
        final used = chunk.where(free0.contains).length;
        List<_Slot> pool;
        if (used >= maxInitial) {
          if (buried.isEmpty) return null;
          pool = buried;
        } else if (ini.isNotEmpty) {
          pool = ini;
        } else {
          pool = open;
        }
        final spread = pool
            .where((card) => !chunk.any((other) => adj[card]!.contains(other)))
            .toList();
        if (spread.isNotEmpty) pool = spread;
        chunk.add(pool[(rand() * pool.length).floor()]);
        alive.remove(chunk.last);
      }
      chunks.add(chunk);
    }
    return chunks;
  }

  static bool _pilesOk(List<_Slot> cards) {
    final piles = <int, List<_Slot>>{};
    for (final card in cards) {
      final id = _pileId(card);
      if (id == null) continue;
      piles.putIfAbsent(id, () => []).add(card);
    }
    for (final group in piles.values) {
      final kinds = group.map((card) => card.type).toSet();
      if (kinds.length < 3) return false;
    }
    return true;
  }

  static bool _topSplitOk(
      List<_Slot> cards, Map<_Slot, Set<_Slot>> adj, int level) {
    if (level < 31) return true;
    final free = _freeCards(cards);
    for (var i = 0; i < free.length; i++) {
      for (var j = i + 1; j < free.length; j++) {
        if (free[i].type == free[j].type && adj[free[i]]!.contains(free[j])) {
          return false;
        }
      }
    }
    return true;
  }

  static Map<int, int> _pileSizes(List<_Slot> cards) {
    final sizes = <int, int>{};
    for (final card in cards) {
      final id = _pileId(card);
      if (id == null) continue;
      sizes[id] = (sizes[id] ?? 0) + 1;
    }
    return sizes;
  }

  static bool _pileRoom(List<_Slot> list, Map<int, int> sizes) {
    final count = <int, int>{};
    for (final card in list) {
      final id = _pileId(card);
      if (id == null) continue;
      count[id] = (count[id] ?? 0) + 1;
    }
    for (final entry in count.entries) {
      if (entry.value > sizes[entry.key]! - 2) return false;
    }
    return true;
  }

  static bool _pairGroups(
    List<({List<_Slot> cards, int free})> groups,
    List<String> types,
    Map<_Slot, Set<_Slot>> adj,
    double Function() rand,
    String mode,
    int level,
    Map<int, int> sizes,
  ) {
    final nTypes = types.length;
    final opening = level <= 2;
    final used = List<bool>.filled(groups.length, false);
    var nodes = 0;

    bool search(int index, bool opener) {
      if (index == nTypes) return !opening || opener;
      if (++nodes > 12000) return false;
      var pick = -1;
      var most = -1;
      for (var i = 0; i < groups.length; i++) {
        if (used[i]) continue;
        if (groups[i].free > most) {
          most = groups[i].free;
          pick = i;
        }
      }
      if (pick < 0) return false;
      final order = <int>[];
      for (var j = 0; j < groups.length; j++) {
        if (j != pick && !used[j]) order.add(j);
      }
      jsShuffle(order, rand);
      order.sort((a, b) {
        final sa = groups[pick].free + groups[a].free;
        final sb = groups[pick].free + groups[b].free;
        int rank(int sum) {
          if (opening && !opener) return sum >= 3 ? 0 : 2;
          if (!opening && sum <= 2) return 0;
          return 1;
        }

        return rank(sa) - rank(sb);
      });
      var tries = 0;
      for (final j in order) {
        final sum = groups[pick].free + groups[j].free;
        if (opening) {
          if (!opener && index == nTypes - 1 && sum < 3) continue;
        } else if (sum > 2) {
          continue;
        }
        final six = <_Slot>[...groups[pick].cards, ...groups[j].cards];
        if (!_clumpOk(six, adj, mode) || !_pileRoom(six, sizes)) continue;
        used[pick] = true;
        used[j] = true;
        for (final card in six) {
          card.type = types[index];
        }
        if (search(index + 1, opener || sum >= 3)) return true;
        used[pick] = false;
        used[j] = false;
        tries += 1;
        if (most == 0 && tries >= 6) break;
      }
      return false;
    }

    return search(0, false);
  }

  static List<String>? _assign(List<_Slot> cards, int level) {
    final plan = LevelPlan.forLevel(level);
    final types =
        ItemType.addOrder.take(plan.types).map((type) => type.id).toList();
    final adj = _buildAdj(cards);
    final maxInitial = level <= 2 ? 3 : 2;
    final sizes = _pileSizes(cards);
    for (final mode in ['strict', 'pairs']) {
      for (var attempt = 0; attempt < 40; attempt++) {
        final rand = JsRng(
            level * 4409 + 91 + attempt * 131 + (mode == 'pairs' ? 7000 : 0));
        final chunks = _buildChunks(cards, rand.next, maxInitial, adj);
        if (chunks == null) continue;
        final face =
            JsRng(level * 8803 + attempt * 17 + (mode == 'pairs' ? 300 : 0));
        final bag = List<String>.from(types);
        jsShuffle(bag, face.next);
        final groups = chunks
            .map(
              (chunk) => (
                cards: chunk,
                free: chunk.where((card) => !_isCovered(card, cards)).length,
              ),
            )
            .toList();
        if (!_pairGroups(groups, bag, adj, face.next, mode, level, sizes)) {
          continue;
        }
        if (!_pilesOk(cards) || !_topSplitOk(cards, adj, level)) continue;
        final freeness = <String, int>{};
        for (final card in _freeCards(cards)) {
          final type = card.type!;
          freeness[type] = (freeness[type] ?? 0) + 1;
        }
        final counts = freeness.values.toList();
        if (counts.isEmpty) continue;
        if (level <= 2 && !counts.any((n) => n >= 3)) continue;
        if (level >= 3 && counts.any((n) => n >= 3)) continue;
        final solution = <String>[];
        for (final chunk in chunks) {
          for (final card in chunk) {
            solution.add(card.id);
          }
        }
        return solution;
      }
    }
    return null;
  }
}
