import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/farm_theme.dart';
import '../../inventory/presentation/tool_bank_line.dart';
import '../application/build_catalog.dart';
import '../data/catalog_mapper.dart';
import '../domain/store_copy.dart';

class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key, this.focusSku});

  final String? focusSku;

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  String? _busyId;

  Future<void> _buy(StoreListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(listing.sku.title),
        content: Text('${listing.blurb}\n\n${listing.sku.priceLabel}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(StoreCopy.notNow),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(StoreCopy.buy),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = listing.sku.id);
    final outcome = await ref.read(purchaseProductProvider).call(listing.sku);
    if (!mounted) return;
    if (outcome.ok) {
      await ref.read(localRevisionProvider).touch();
      ref.read(inventoryProvider.notifier).reload();
      ref.read(entitlementsProvider.notifier).reload();
      await ref.read(authStateProvider.notifier).syncFromCloud();
    }
    setState(() => _busyId = null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.ok
              ? 'Added to this device.'
              : (outcome.message ?? 'Purchase failed.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listings = const CatalogMapper().map(
      ref.watch(configProvider),
      ref.watch(entitlementsProvider),
    );
    final inventory = ref.watch(inventoryProvider);
    return SkyBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: FarmColors.ink,
          title: const Text(
            StoreCopy.title,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Text(
                StoreCopy.lead,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                StoreCopy.yourTools,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              ToolBankLine(inventory: inventory),
              const SizedBox(height: 16),
              for (final section in [
                StoreCopy.room,
                StoreCopy.tools,
                StoreCopy.quiet,
              ]) ...[
                Text(
                  section,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (final listing in listings.where(
                  (item) => item.section == section,
                ))
                  _SkuCard(
                    listing: listing,
                    focused: listing.sku.id == widget.focusSku,
                    busy: _busyId == listing.sku.id,
                    onBuy: () => _buy(listing),
                  ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Restore purchases in Settings.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkuCard extends StatelessWidget {
  const _SkuCard({
    required this.listing,
    required this.focused,
    required this.busy,
    required this.onBuy,
  });

  final StoreListing listing;
  final bool focused;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final owned = listing.owned;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FarmColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused ? FarmColors.leaf : const Color(0xFF8A6340),
          width: focused ? 3 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.sku.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.blurb,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: owned || busy ? null : onBuy,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(owned ? StoreCopy.owned : listing.sku.priceLabel),
          ),
        ],
      ),
    );
  }
}
