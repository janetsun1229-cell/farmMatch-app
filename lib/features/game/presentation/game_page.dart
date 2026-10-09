import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/theme/farm_theme.dart';
import '../../../shared/item_glyph.dart';
import '../../config/domain/game_config.dart';
import '../../inventory/domain/tool_inventory.dart';
import '../domain/game_state.dart';
import '../domain/item_type.dart';
import '../domain/power.dart';
import '../domain/rules/game_rules.dart';
import '../domain/tile_card.dart';
import 'game_controller.dart';
import 'widgets/board_view.dart';

class GamePage extends ConsumerStatefulWidget {
  const GamePage({super.key, required this.level});

  final int level;

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _Fly {
  const _Fly({required this.from, required this.to, required this.type});

  final Rect from;
  final Rect to;
  final ItemType type;
}

class _GamePageState extends ConsumerState<GamePage>
    with TickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final _slotKeys = List<GlobalKey>.generate(7, (_) => GlobalKey());
  late final AnimationController _fly;
  late final AnimationController _pop;
  late final AnimationController _confetti;
  late final SfxPlayer _sfx;
  _Fly? _flying;
  MatchPlan? _popping;
  var _busy = false;
  var _celebrating = false;
  var _hintsSent = false;

  @override
  void initState() {
    super.initState();
    final timing = ref.read(configProvider).timing;
    _fly = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (timing.flySeconds * 1000).round()),
    );
    _pop = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (timing.sparkSeconds * 1000).round()),
    );
    _confetti = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (timing.confettiSeconds * 1000).round()),
    );
    _sfx = SfxPlayer();
    _fly.addListener(() => setState(() {}));
    _pop.addListener(() => setState(() {}));
    _confetti.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fly.dispose();
    _pop.dispose();
    _confetti.dispose();
    _sfx.dispose();
    super.dispose();
  }

  GameController get _controller =>
      ref.read(gameControllerProvider(widget.level).notifier);

  void _syncMute() {
    _sfx.muted = ref.read(progressProvider).muted;
  }

  Future<void> _maybeHints(GameVm vm) async {
    if (_hintsSent || vm.loading || vm.game == null) return;
    if (!vm.showL1Hint && vm.powerHint == null) return;
    _hintsSent = true;
    await _controller.acknowledgeHints();
  }

  Rect? _slotRect(int index) {
    final clamped = index.clamp(0, _slotKeys.length - 1);
    final context = _slotKeys[clamped].currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  Offset _local(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return global;
    return box.globalToLocal(global);
  }

  Future<void> _arrive(TileCard card, Rect? from) async {
    _syncMute();
    final index = _controller.snapshot.game?.tray.length ?? 0;
    if (from != null) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final to = _slotRect(index);
      if (to != null) {
        setState(() => _flying = _Fly(from: from, to: to, type: card.type));
        await _fly.forward(from: 0);
        if (!mounted) return;
      }
    }
    _controller.finishDrop();
    setState(() => _flying = null);
    final plan = _controller.peek();
    if (plan != null) {
      setState(() => _popping = plan);
      await _sfx.play('pop');
      await _pop.forward(from: 0);
      if (!mounted) return;
      _controller.commitStrip(plan);
      setState(() => _popping = null);
    } else {
      _controller.commitJudge();
      await _sfx.play('tap');
    }
    final bank = ref.read(inventoryProvider);
    _controller.onSettled(bank);
    final status = _controller.snapshot.game?.status;
    if (status == GameStatus.win) {
      await _celebrate();
    } else if (status == GameStatus.fail) {
      await _sfx.play('regret');
    }
  }

  Future<void> _celebrate() async {
    if (_celebrating) return;
    _celebrating = true;
    await _controller.persistWin();
    if (!mounted) return;
    _syncMute();
    await _sfx.play('cheer');
    await _confetti.forward(from: 0);
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _onTapCard(TileCard card, Rect rect) async {
    if (_busy) return;
    final vm = ref.read(gameControllerProvider(widget.level));
    if (vm.game?.status != GameStatus.play) return;
    final lifted = _controller.liftBoard(card.id);
    if (lifted == null) return;
    setState(() => _busy = true);
    try {
      await _arrive(lifted, rect);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onHold(TileCard card, Rect rect) async {
    if (_busy) return;
    final lifted = _controller.liftHold(card.id);
    if (lifted == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open tray slot.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _arrive(lifted, rect);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _use(Power power) {
    if (_busy) return;
    final bank = ref.read(inventoryProvider);
    final ok = switch (power) {
      Power.move => _controller.useMove(bank),
      Power.undo => _controller.useUndo(bank),
      Power.shuffle => _controller.useShuffle(bank),
    };
    if (ok) {
      _syncMute();
      _sfx.play('tap');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(gameControllerProvider(widget.level));
    final config = ref.watch(configProvider);
    final bank = ref.watch(inventoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeHints(vm);
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _busy) return;
        context.go('/');
      },
      child: SkyBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              key: _stackKey,
              children: [
                Column(
                  children: [
                    _Header(
                      level: widget.level,
                      busy: _busy || vm.loading,
                      onHome: () => context.go('/'),
                      onRetry: () {
                        setState(() => _hintsSent = false);
                        _controller.retry();
                      },
                    ),
                    Expanded(child: _body(vm, config, bank)),
                  ],
                ),
                if (_flying != null) _flyWidget(),
                if (_popping != null) _sparks(),
                if (_celebrating || vm.game?.status == GameStatus.win)
                  _confettiLayer(),
                if (vm.game?.status == GameStatus.fail && !_busy)
                  _failOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(GameVm vm, GameConfig config, ToolInventory bank) {
    if (vm.loading) {
      return const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: FarmColors.ink),
          SizedBox(height: 12),
          Text('Setting up the porch...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ));
    }
    if (vm.error != null) {
      return _MessagePane(
        text: vm.error!,
        action: 'Home',
        onPressed: () => context.go('/'),
      );
    }
    if (vm.lockedSku != null) {
      return _MessagePane(
        text: 'This part of the farm is still shut.',
        action: 'See the stand',
        onPressed: () => context.push('/store?focus=${vm.lockedSku}'),
        second: 'Home',
        onSecond: () => context.go('/'),
      );
    }
    final game = vm.game!;
    final warnAt = game.trayCapacity - config.softHelp.trayWarnSlotsLeft;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = BoardMetrics.layout(
                cards: game.board,
                availWidth: constraints.maxWidth - 12,
                scale: config.cardScaleVsL1,
                maxColumns: config.boardMaxColumns,
              );
              final board = BoardView(
                cards: game.board,
                metrics: metrics,
                veilFor: config.veilOpacity,
                hintCardId: vm.showL1Hint ? _hintCard(game) : null,
                onTap: _onTapCard,
              );
              if (metrics.pixelHeight <= constraints.maxHeight) {
                return Center(child: board);
              }
              return ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [Center(child: board)],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(
            children: [
              if (game.hold.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final card in game.hold)
                        _HoldChip(
                            card: card, onTap: (rect) => _onHold(card, rect)),
                    ],
                  ),
                ),
              _Tray(
                cards: game.tray,
                capacity: game.trayCapacity,
                warn: game.tray.length >= warnAt &&
                    game.status == GameStatus.play,
                slotKeys: _slotKeys,
                popping: _popping,
                popT: _pop.value,
                popScale: config.timing.matchPopScale,
              ),
              const SizedBox(height: 10),
              _Powers(
                vm: vm,
                bank: bank,
                controller: _controller,
                busy: _busy,
                onUse: _use,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _hintCard(GameState game) {
    for (final card in game.board) {
      if (GameRules.canTap(game, card.id)) return card.id;
    }
    return null;
  }

  Widget _flyWidget() {
    final fly = _flying!;
    final t = Curves.easeInOut.transform(_fly.value);
    final from = _local(fly.from.center);
    final to = _local(fly.to.center);
    final peak = Offset((from.dx + to.dx) / 2, math.min(from.dy, to.dy) - 42);
    final u = 1 - t;
    final pos = from * (u * u) + peak * (2 * u * t) + to * (t * t);
    final size = Size.lerp(fly.from.size, fly.to.size, t)!;
    return Positioned(
      left: pos.dx - size.width / 2,
      top: pos.dy - size.height / 2,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFAF0), FarmColors.creamDeep],
            ),
            border: Border.all(color: const Color(0xFFDFC686), width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 10,
                  offset: Offset(0, 6))
            ],
          ),
          child: ItemGlyph(type: fly.type, padding: const EdgeInsets.all(5)),
        ),
      ),
    );
  }

  Widget _sparks() {
    final count = ref.read(configProvider).timing.sparkCountMax;
    return IgnorePointer(
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            _Spark(index: i, count: count, t: _pop.value),
        ],
      ),
    );
  }

  Widget _confettiLayer() {
    return IgnorePointer(
      child: Stack(
        children: [
          for (var i = 0; i < 48; i++)
            _ConfettiBit(index: i, t: _confetti.value),
        ],
      ),
    );
  }

  Widget _failOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x94333338),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF4DC), Color(0xFFF5E2B8)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7A5430), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Try this level again?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: FarmColors.ink),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceButton(
                        key: const Key('fail-again'),
                        label: 'Try again',
                        fill: const Color(0xFF3EC848),
                        edge: const Color(0xFF0E5A1C),
                        onPressed: () {
                          setState(() => _hintsSent = false);
                          _controller.retry();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChoiceButton(
                        key: const Key('fail-home'),
                        label: 'Home',
                        fill: const Color(0xFFF0D9A0),
                        edge: const Color(0xFF8A5A28),
                        foreground: FarmColors.ink,
                        onPressed: () => context.go('/'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.level,
      required this.busy,
      required this.onHome,
      required this.onRetry});

  final int level;
  final bool busy;
  final VoidCallback onHome;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _TinyButton(label: 'Home', onPressed: busy ? null : onHome),
          const SizedBox(width: 8),
          _TinyButton(label: 'Retry', onPressed: busy ? null : onRetry),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF5C3A1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6B4A2A)),
            ),
            child: Text(
              'Level $level',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyButton extends StatelessWidget {
  const _TinyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF0C878),
        foregroundColor: FarmColors.ink,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.cards,
    required this.capacity,
    required this.warn,
    required this.slotKeys,
    required this.popping,
    required this.popT,
    required this.popScale,
  });

  final List<TileCard> cards;
  final int capacity;
  final bool warn;
  final List<GlobalKey> slotKeys;
  final MatchPlan? popping;
  final double popT;
  final double popScale;

  @override
  Widget build(BuildContext context) {
    final popIds = popping?.ids.toSet() ?? const <String>{};
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 74,
      decoration: BoxDecoration(
        color: warn ? FarmColors.warn : FarmColors.wood,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(14), bottom: Radius.circular(20)),
        border: Border.all(
            color: warn ? const Color(0xFFD07030) : FarmColors.woodEdge,
            width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < capacity; i++)
            Expanded(
              child: Container(
                key: i < slotKeys.length ? slotKeys[i] : null,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: FarmColors.woodDark,
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0 ? const Radius.circular(10) : Radius.zero,
                    right: i == capacity - 1
                        ? const Radius.circular(12)
                        : Radius.zero,
                  ),
                ),
                child: i < cards.length
                    ? _slotFace(i, cards[i], popIds)
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slotFace(int index, TileCard card, Set<String> popIds) {
    final popping = popIds.contains(card.id);
    final mid = popping ? (popIds.length - 1) / 2 : index.toDouble();
    final shift = popping ? (mid - index) * 18 * popT : 0.0;
    final scale = popping
        ? 1 +
            (popScale - 1) *
                (popT < 0.45 ? popT / 0.45 : 1 - (popT - 0.45) / 0.55)
        : 1.0;
    return Opacity(
      opacity: popping ? (1 - popT).clamp(0.0, 1.0) : 1,
      child: Transform.translate(
        offset: Offset(shift, popping ? -16 * popT : 0),
        child: Transform.scale(
          scale: scale,
          child: ItemGlyph(type: card.type, padding: const EdgeInsets.all(4)),
        ),
      ),
    );
  }
}

class _HoldChip extends StatelessWidget {
  const _HoldChip({required this.card, required this.onTap});

  final TileCard card;
  final void Function(Rect rect) onTap;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize) return;
            onTap(box.localToGlobal(Offset.zero) & box.size);
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: card.type == ItemType.wool
                  ? FarmColors.wool
                  : FarmColors.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDFC686), width: 1.5),
            ),
            child: ItemGlyph(type: card.type, padding: const EdgeInsets.all(4)),
          ),
        );
      },
    );
  }
}

class _Powers extends StatelessWidget {
  const _Powers({
    required this.vm,
    required this.bank,
    required this.controller,
    required this.busy,
    required this.onUse,
  });

  final GameVm vm;
  final ToolInventory bank;
  final GameController controller;
  final bool busy;
  final void Function(Power power) onUse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final power in Power.values) ...[
          if (power != Power.move) const SizedBox(width: 8),
          Expanded(
            child: _PowerButton(
              power: power,
              vm: vm,
              bank: bank,
              controller: controller,
              busy: busy,
              onUse: onUse,
            ),
          ),
        ],
      ],
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.power,
    required this.vm,
    required this.bank,
    required this.controller,
    required this.busy,
    required this.onUse,
  });

  final Power power;
  final GameVm vm;
  final ToolInventory bank;
  final GameController controller;
  final bool busy;
  final void Function(Power power) onUse;

  @override
  Widget build(BuildContext context) {
    final level = vm.game?.level ?? vm.level;
    final unlock = controller.unlockLevel(power);
    final locked = level < unlock;
    final uses = vm.freeFor(power) + bank.of(power);
    final enabled = !busy && !locked && controller.canUse(power, bank);
    final flash = vm.flashToken > 0 &&
        (power == Power.move || power == Power.shuffle) &&
        enabled;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _Flash(
          token: flash ? vm.flashToken : 0,
          child: SizedBox(
            height: 64,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled ? () => onUse(power) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    locked ? const Color(0xFFCBB892) : const Color(0xFF2F86EF),
                disabledBackgroundColor:
                    locked ? const Color(0xFFCBB892) : const Color(0xFFB89A72),
                foregroundColor:
                    locked ? const Color(0xFF5A4430) : Colors.white,
                disabledForegroundColor:
                    locked ? const Color(0xFF5A4430) : const Color(0xFF6B5340),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(power.label),
                  Text(
                    locked ? 'Lv.$unlock' : '$uses',
                    style: TextStyle(
                      fontSize: locked ? 12 : 18,
                      fontWeight: FontWeight.w900,
                      color: locked ? const Color(0xFF6B4423) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (locked)
          const Positioned(
            right: -4,
            top: -6,
            child: Image(
                image: AssetImage('assets/images/ui/power-lock.png'),
                width: 26,
                height: 26),
          ),
        if (vm.powerHint == power)
          const Positioned(
            right: 8,
            bottom: -18,
            child: Image(
                image: AssetImage('assets/images/ui/tip-hand.png'),
                width: 36,
                height: 36),
          ),
      ],
    );
  }
}

class _Flash extends StatefulWidget {
  const _Flash({required this.token, required this.child});

  final int token;
  final Widget child;

  @override
  State<_Flash> createState() => _FlashState();
}

class _FlashState extends State<_Flash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    if (widget.token > 0) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _Flash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token && widget.token > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = t == 0 ? 1.0 : 1 + 0.08 * math.sin(t * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.index, required this.count, required this.t});

  final int index;
  final int count;
  final double t;

  @override
  Widget build(BuildContext context) {
    final angle = (math.pi * 2 * index) / count;
    final dist = (28 + (index % 3) * 12) * t;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(math.cos(angle) * dist, -80 + math.sin(angle) * dist),
        child: Opacity(
          opacity: (1 - t).clamp(0, 1),
          child: index.isEven
              ? const Image(
                  image: AssetImage('assets/images/ui/star-spark.png'),
                  width: 18,
                  height: 18)
              : Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFD84A), shape: BoxShape.circle),
                ),
        ),
      ),
    );
  }
}

class _ConfettiBit extends StatelessWidget {
  const _ConfettiBit({required this.index, required this.t});

  final int index;
  final double t;

  static const _colors = [
    Color(0xFFFFD84A),
    Color(0xFFFF9A2E),
    Color(0xFF4ECF5A),
    Color(0xFFFFF4D6),
    Color(0xFFF0C040),
    Color(0xFF7ED957),
  ];

  @override
  Widget build(BuildContext context) {
    final swing = (index.isEven ? 1 : -1) *
        (18.0 + (index % 5) * 10) *
        math.sin(t * math.pi);
    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: Offset((index * 37 % 320) - 160 + swing, -30 + t * 720),
        child: Transform.rotate(
          angle: t * 6 + index,
          child: Container(
            width: 12 + (index % 4) * 3,
            height: 22 + (index % 5) * 3,
            decoration: BoxDecoration(
              color: _colors[index % _colors.length],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.label,
    required this.fill,
    required this.edge,
    required this.onPressed,
    this.foreground = Colors.white,
  });

  final String label;
  final Color fill;
  final Color edge;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: edge, width: 2),
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(label,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: foreground)),
      ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.text,
    required this.action,
    required this.onPressed,
    this.second,
    this.onSecond,
  });

  final String text;
  final String action;
  final VoidCallback onPressed;
  final String? second;
  final VoidCallback? onSecond;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onPressed, child: Text(action)),
            if (second != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onSecond, child: Text(second!)),
            ],
          ],
        ),
      ),
    );
  }
}
