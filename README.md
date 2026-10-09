# Farm Match

Portrait triple-match tile game for iOS and Android. Players clear a stacked farm table into a 7-slot tray. Progress, tools, and the guest nickname stay on the device. There is no login and no cloud save.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Debug Android package:

```bash
flutter build apk --debug
```

iOS builds need Xcode on macOS (`flutter build ios --debug` or an Xcode archive). This repo includes the iOS project and locks the app to portrait.

## Docs

Product and architecture notes live in this repo:

- [Game features and Param IDs](docs/GAME_FEATURES.md)
- [Flutter module design](docs/MODULE_DESIGN.md)
- [Store technical architecture](docs/TECH_ARCHITECTURE.md)

The playable HTML prototype (algorithm reference, not a WebView) is [janetsun1229-cell/farmMatch](https://github.com/janetsun1229-cell/farmMatch).

## Layout

```
lib/
  app/            router, Riverpod providers, app shell
  core/           theme, scroll behavior, sound
  features/
    identity/     guest id + editable nickname
    progress/     cleared level, mute, hint flags
    inventory/    Move / Undo / Shuffle bank
    entitlements/ remove ads, Barn Bundle, Harvest Bundle
    iap/          StoreClient + verify client
    config/       bundled default JSON, optional remote refresh
    game/         deal, cover, tray, powers
    home/         home-first entry
    store_ui/     Farm Stand
    settings/     nickname, mute, Restore Purchases
  shared/
```

Each feature is split into `presentation`, `application`, `domain`, and `data`. Navigation uses `go_router`. State uses Riverpod.

## Rules that are locked in

- 50 levels. L1–20 are free. Barn Bundle opens 21–35. Harvest Bundle opens 36–50.
- Tray holds 7. Hold holds 6. Move / Undo / Shuffle unlock at levels 5 / 8 / 12.
- Cards stay at 85% of the level-1 size (`card_scale_vs_l1`). Rotation is 0.
- Veil opacity follows cover depth: 25%, 35%, 45%, 55%.
- Unlocked powers start each level with 3 uses. Bought kits add a local bank on top (`power_charge_mode`: `per_level_plus_bank`).
- Restore Purchases restores only `remove_ads`, `barn_bundle`, and `harvest_bundle`.

Deals use the HTML prototype’s seeded layout (level id is the seed). `flutter test` checks all 50 deals against `test/fixtures/deals.json` and clears each level by its known solution order.

## Config and purchases

`assets/config/default_config.json` is the bundled default and matches the Param ID tables. On launch the app tries `GET /v1/config` when a base URL is set, and keeps the last good response. With no URL it stays on the bundled file.

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

Purchases go through `StoreClient`. The default build uses `FakeStoreClient` so tests and local play do not need a store account. Non-consumables are remembered on device so **Restore Purchases** can put them back. Tool packs are not restored.

```bash
flutter run --dart-define=USE_FAKE_STORE=false
```

That flag selects `BillingStoreClient`, which is wired to the `in_app_purchase` plugin (StoreKit 2 / Play Billing). Receipts are posted to `POST /v1/iap/verify`. An empty API base URL uses an offline stub that accepts a non-empty receipt for local play. Point the app at the real verifier before release. The stub is not a trusted check.

SKUs: `pack_small`, `pack_medium`, `pack_large`, `remove_ads`, `barn_bundle`, `harvest_bundle`.

## Artwork

PNG files under `assets/images/` are copied from the Farm Match HTML prototype repository, [janetsun1229-cell/farmMatch](https://github.com/janetsun1229-cell/farmMatch) (`home-title.png`, `home-farmer.png`, `items-out/*.png`, `ui-upgrade/*.png`). They are project-original assets for this game. No separate third-party license was published with those files. Do not reuse them outside this product without the owner’s permission.

Item ids follow the prototype: `fork` is the pitchfork and `can` is the watering can.

Short UI sounds in `assets/audio/` were generated for this app (tap, pop, cheer, regret) and are not copied from the prototype.
