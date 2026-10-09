/// Column/row scripts from the HTML prototype. Totals match the difficulty bands.
class LevelPlan {
  const LevelPlan({
    required this.types,
    required this.copies,
    required this.piles,
    required this.pileThick,
    required this.grids,
  });

  final int types;
  final int copies;
  final int piles;
  final int pileThick;

  /// Each entry is `[columns, rows]` from bottom layer to top.
  final List<List<int>> grids;

  int get offsetCards {
    var n = 0;
    for (final grid in grids) {
      n += grid[0] * grid[1];
    }
    return n;
  }

  int get totalCards => offsetCards + piles * pileThick;

  static LevelPlan forLevel(int level) {
    if (level < 1 || level > 50) {
      throw ArgumentError('bad level');
    }
    if (level == 1) {
      return const LevelPlan(
        types: 4,
        copies: 6,
        piles: 0,
        pileThick: 0,
        grids: [
          [4, 3],
          [4, 2],
          [2, 2],
        ],
      );
    }
    if (level == 2) {
      return const LevelPlan(
        types: 4,
        copies: 6,
        piles: 0,
        pileThick: 0,
        grids: [
          [4, 3],
          [4, 3],
        ],
      );
    }
    if (level <= 5) {
      return const LevelPlan(
        types: 4,
        copies: 6,
        piles: 2,
        pileThick: 4,
        grids: [
          [3, 2],
          [3, 2],
          [2, 2],
        ],
      );
    }
    if (level <= 10) {
      return const LevelPlan(
        types: 6,
        copies: 6,
        piles: 2,
        pileThick: 4,
        grids: [
          [5, 2],
          [5, 2],
          [4, 2],
        ],
      );
    }
    if (level <= 15) {
      return const LevelPlan(
        types: 8,
        copies: 6,
        piles: 3,
        pileThick: 5,
        grids: [
          [4, 3],
          [4, 3],
          [3, 3],
        ],
      );
    }
    if (level <= 25) {
      return const LevelPlan(
        types: 10,
        copies: 6,
        piles: 3,
        pileThick: 5,
        grids: [
          [5, 3],
          [5, 3],
          [5, 3],
        ],
      );
    }
    if (level <= 40) {
      return const LevelPlan(
        types: 12,
        copies: 6,
        piles: 4,
        pileThick: 6,
        grids: [
          [4, 4],
          [4, 3],
          [4, 3],
          [4, 2],
        ],
      );
    }
    return const LevelPlan(
      types: 15,
      copies: 6,
      piles: 5,
      pileThick: 7,
      grids: [
        [5, 4],
        [5, 3],
        [4, 3],
        [4, 2],
      ],
    );
  }
}
