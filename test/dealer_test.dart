import 'dart:convert';
import 'dart:io';

import 'package:farm_match/features/config/domain/game_config.dart';
import 'package:farm_match/features/game/domain/game_state.dart';
import 'package:farm_match/features/game/domain/level/dealer.dart';
import 'package:farm_match/features/game/domain/level/js_rng.dart';
import 'package:farm_match/features/game/domain/level/level_plan.dart';
import 'package:farm_match/features/game/domain/rules/cover.dart';
import 'package:farm_match/features/game/domain/rules/game_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/deals.json').readAsStringSync())
          as Map<String, dynamic>;

  test('deals match the HTML prototype for all 50 levels', () {
    for (var level = 1; level <= 50; level++) {
      final deal = Dealer.deal(level);
      final expected = fixtures['$level'] as List<dynamic>;
      expect(deal.cards.length, expected.length, reason: 'level $level count');
      for (var i = 0; i < expected.length; i++) {
        final row = expected[i] as Map<String, dynamic>;
        final card = deal.cards[i];
        expect(card.id, row['id'], reason: 'L$level id');
        expect(card.type.id, row['type'], reason: 'L$level ${card.id} type');
        expect(card.layer, row['layer'], reason: 'L$level ${card.id} layer');
        expect(card.pile, row['pile'], reason: 'L$level ${card.id} pile');
        expect(card.rot, 0);
        expect(card.x, closeTo((row['x'] as num).toDouble(), 0.001),
            reason: 'L$level ${card.id} x');
        expect(card.y, closeTo((row['y'] as num).toDouble(), 0.001),
            reason: 'L$level ${card.id} y');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('scripted solution clears every level', () {
    for (var level = 1; level <= 50; level++) {
      final deal = Dealer.deal(level);
      var state = GameState.opening(level: level, board: deal.cards);
      for (final id in deal.solution) {
        expect(GameRules.canTap(state, id), isTrue,
            reason: 'L$level $id not free');
        state = GameRules.tap(state, id);
        expect(state.status, isNot(GameStatus.fail),
            reason: 'L$level failed while following the deal');
      }
      expect(state.status, GameStatus.win, reason: 'level $level');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('band totals, veil, and opening constraints', () {
    final config = GameConfig.fallback();
    for (var level = 1; level <= 50; level++) {
      final plan = LevelPlan.forLevel(level);
      final band = config.bandFor(level);
      expect(plan.totalCards, band.cards, reason: 'level $level');
      expect(plan.types, band.types);
      expect(plan.piles, band.piles);
      final deal = Dealer.deal(level);
      expect(deal.cards.length, plan.types * 6);
      final counts = <String, int>{};
      for (final card in deal.cards) {
        counts[card.type.id] = (counts[card.type.id] ?? 0) + 1;
        expect(card.rot, 0);
      }
      expect(counts.length, plan.types);
      expect(counts.values.every((n) => n == 6), isTrue);
      final piles = <int, List<String>>{};
      for (final card in deal.cards.where((card) => card.pile)) {
        final key = jsRound((card.x - card.y) * 1000);
        piles.putIfAbsent(key, () => []).add(card.type.id);
      }
      expect(piles.length, plan.piles);
      for (final group in piles.values) {
        expect(group.length, plan.pileThick);
        expect(group.toSet().length, greaterThanOrEqualTo(3));
      }
      if (level == 1) {
        final layers = <int, int>{};
        for (final card in deal.cards) {
          layers[card.layer] = (layers[card.layer] ?? 0) + 1;
        }
        expect(layers[0], 12);
        expect(layers[1], 8);
        expect(layers[2], 4);
      }
      final freeCounts = <String, int>{};
      for (final card in freeCards(deal.cards)) {
        freeCounts[card.type.id] = (freeCounts[card.type.id] ?? 0) + 1;
      }
      final exposedTriple = freeCounts.values.any((n) => n >= 3);
      if (level <= 2) {
        expect(exposedTriple, isTrue, reason: 'level $level');
      } else {
        expect(exposedTriple, isFalse, reason: 'level $level');
      }
    }
    expect(veilOpacityForDepth(1), 0.25);
    expect(veilOpacityForDepth(2), 0.35);
    expect(veilOpacityForDepth(3), 0.45);
    expect(veilOpacityForDepth(6), 0.55);
  });
}
