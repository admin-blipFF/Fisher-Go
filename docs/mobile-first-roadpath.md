# FisherGO Mobile-First Roadpath

## Product Direction

FisherGO should become a native-feeling mobile game first, with Android as the lead target. Web remains valuable for demo, admin, fish encyclopedia preview, leaderboard checks, and quick regression validation, but web should not constrain gameplay.

## Why Android First

- This Windows machine can build Android once the Android SDK is installed, so the feedback loop is faster than iOS.
- Android is better for early field testing around Hong Kong fishing spots without needing Mac/Xcode signing setup.
- It still supports the Pokemon GO-style loop: walk, detect nearby spots, interact, capture, confirm, sync, return later.
- Flutter lets the same feature architecture later support iOS once the mobile game loop is stable.

## Phase 1: Foundation

- Keep `flutter analyze` clean.
- Keep `flutter test` green.
- Keep `flutter build web` green as a preview surface.
- Install/configure Android SDK.
- Keep `flutter build apk --debug` green.
- Audit Android permissions and platform configuration before first real-device build.
- Use Android package/application ID `com.fishergo.app`.
- Preserve offline-first behavior with Hive and Supabase sync.

## Android Setup Checklist

- Install JDK 17 and Android Studio or Android command-line tools.
- Install Android SDK Platform, Build Tools, Platform Tools, and Command-Line Tools through SDK Manager.
- Accept licenses with `flutter doctor --android-licenses`.
- Confirm `flutter doctor -v` has a clean Android toolchain section.
- Build with `flutter build apk --debug`.

## Phase 2: Core Mobile Loop

- GPS spot discovery.
- Distance-gated fishing attempts.
- Fishing minigame result.
- Catch confirmation with species, time, photo, and location.
- Fish collection unlock state.
- Coins, XP, streaks, and daily tasks.

## Phase 3: Map and Spawn Depth

- Spot biomes: pier, rock, reef, beach, boat, island.
- Spawn rules by biome, rarity, time, and event boosts.
- Rare fish appearances and limited-time routes.
- Boat vendor spots as controlled premium convenience, not a GPS bypass exploit.

## Phase 4: AI Recognition

- Restrict recognition to the authorized fish species list.
- Require user confirmation before collection unlock.
- Store confidence, selected species, photo metadata, and location metadata.
- Reject invented species names and low-confidence auto-unlocks.

## Phase 5: Retention and Social

- Daily leaderboard.
- Achievements and badges.
- Crew/friend layer.
- Event announcements.
- Push notification hooks.
- Admin review tools on web.

## Platform Notes

Windows can maintain shared Flutter code, tests, Supabase integration, web builds, and Android builds once the Android SDK is installed. iOS simulator/device builds require macOS with Xcode or a macOS CI runner and are deferred.
