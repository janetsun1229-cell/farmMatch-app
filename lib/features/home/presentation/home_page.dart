import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/theme/farm_theme.dart';
import '../../deeplink/presentation/growth_toast.dart';
import '../../gift_remind/presentation/gift_dot.dart';
import '../../progress/presentation/mute_button.dart';
import '../application/load_home.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = const LoadHome().call(
      user: ref.watch(identityProvider),
      progress: ref.watch(progressProvider),
      entitlements: ref.watch(entitlementsProvider),
      config: ref.watch(configProvider),
    );
    final locked = !snapshot.access.allowed;
    final invited = ref.watch(inviteBannerProvider);
    final giftDot = ref.watch(giftRemindProvider).showDot;
    final width = MediaQuery.sizeOf(context).width;
    return GrowthToastListener(
      child: SkyBackdrop(
        scene: 'assets/images/level-bg.jpg',
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                const Positioned(left: 0, bottom: 0, child: _Farmer()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: const Key('open-settings'),
                            tooltip: 'Settings',
                            onPressed: () => context.push('/settings'),
                            icon: const Icon(Icons.settings,
                                color: FarmColors.ink, size: 32),
                          ),
                          IconButton(
                            key: const Key('open-friends-home'),
                            tooltip: 'Friends',
                            onPressed: () => context.push('/friends'),
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.people,
                                    color: FarmColors.ink, size: 32),
                                if (giftDot)
                                  const Positioned(
                                    right: -2,
                                    top: -2,
                                    child: GiftDot(),
                                  ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          MuteButton(
                            muted: snapshot.progress.muted,
                            onPressed: () => ref
                                .read(progressProvider.notifier)
                                .setMuted(!snapshot.progress.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Image.asset(
                        'assets/images/home-title.png',
                        width: math.min(420, width - 32),
                        fit: BoxFit.contain,
                        semanticLabel: 'Farm Match',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hello, ${snapshot.user.nickname}',
                        key: const Key('home-nickname'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: FarmColors.ink),
                      ),
                      if (snapshot.progress.clearedAll)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Image.asset(
                            'assets/images/ui/cleared-badge.png',
                            width: 180,
                            semanticLabel: 'Cleared',
                          ),
                        ),
                      const Spacer(),
                      if (invited) ...[
                        const Text(
                          'Invite saved. Clear level 1 — you both get free boosts.',
                          key: Key('invite-banner'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            color: FarmColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _PlayButton(
                        level: snapshot.level,
                        locked: locked,
                        onPressed: () {
                          if (!snapshot.access.allowed) {
                            final sku = snapshot.access.sku ?? 'barn_bundle';
                            context.push('/store?focus=$sku');
                            return;
                          }
                          context.push('/play/${snapshot.level}');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton(
      {required this.level, required this.locked, required this.onPressed});

  final int level;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: locked ? 'Level $level locked' : 'Play level $level',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = math.min(560.0, constraints.maxWidth);
          final barHeight = barWidth * 120 / 560;
          return GestureDetector(
            key: const Key('home-play'),
            onTap: onPressed,
            child: Container(
              width: barWidth,
              height: barHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2FBE45),
                borderRadius: BorderRadius.circular(barHeight * 0.28),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF0A6A20), offset: Offset(0, 6)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$level',
                    style: TextStyle(
                      fontSize: barHeight * 0.42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  if (locked)
                    const Positioned(
                      right: 18,
                      child: Image(
                          image: AssetImage('assets/images/ui/power-lock.png'),
                          width: 28,
                          height: 28),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Farmer extends StatefulWidget {
  const _Farmer();

  @override
  State<_Farmer> createState() => _FarmerState();
}

class _FarmerState extends State<_Farmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.42, 200.0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final angle = -0.042 + (0.049 + 0.042) * t;
        return Transform.translate(
          offset: Offset(4 * t, 0),
          child: Transform.rotate(
              angle: angle, alignment: Alignment.bottomCenter, child: child),
        );
      },
      child: Image.asset(
        'assets/images/home-farmer.png',
        key: const Key('home-farmer'),
        width: width,
        height: width * 640 / 647,
        fit: BoxFit.contain,
      ),
    );
  }
}
