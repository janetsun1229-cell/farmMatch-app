import 'package:flutter/material.dart';

import '../../../core/theme/farm_theme.dart';
import '../domain/auth_provider_kind.dart';
import '../domain/bind_prompt.dart';

enum BindSheetResult { skipped, linked }

class BindOfferSheet extends StatefulWidget {
  const BindOfferSheet({
    super.key,
    required this.kind,
    required this.onSkip,
    required this.onBind,
  });

  final BindPromptKind kind;
  final VoidCallback onSkip;
  final Future<String?> Function(AuthProviderKind provider) onBind;

  @override
  State<BindOfferSheet> createState() => _BindOfferSheetState();
}

class _BindOfferSheetState extends State<BindOfferSheet> {
  String? _error;
  var _busy = false;

  Future<void> _bind(AuthProviderKind provider) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onBind(provider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.kind == BindPromptKind.inviteFriends;
    final body = invite ? BindCopy.inviteBody : BindCopy.cloudSaveBody;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          key: const Key('bind-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7C4A4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              invite ? 'Friends & a safe save' : 'Save your progress',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: FarmColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              key: const Key('bind-copy'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FarmColors.warn,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _LinkButton(
              key: const Key('bind-x'),
              label: _busy ? 'Linking...' : 'Link X',
              onPressed: _busy ? null : () => _bind(AuthProviderKind.x),
            ),
            const SizedBox(height: 8),
            _LinkButton(
              key: const Key('bind-facebook'),
              label: _busy ? 'Linking...' : 'Link Facebook',
              fill: const Color(0xFF1877F2),
              onPressed: _busy ? null : () => _bind(AuthProviderKind.facebook),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const Key('bind-skip'),
              onPressed: _busy ? null : widget.onSkip,
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fill = const Color(0xFF111111),
  });

  final String label;
  final VoidCallback? onPressed;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        child: Text(label),
      ),
    );
  }
}
