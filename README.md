# Walkie

A virtual koala pet for iOS that you keep alive by walking. Your daily step count earns leaves; leaves feed your koala; an unfed koala gets hungry and eventually wanders off to the graveyard.

Built with SwiftUI, SwiftData, HealthKit, WidgetKit, and a hand-drawn koala that lives entirely in SwiftUI shapes — no image assets for the character.

## Features

- **Step-driven feeding loop.** HealthKit step counts roll into a daily leaf ledger (1 leaf per 10% of your goal). Feed the koala to top up its health; skip too many days and it dies and joins the graveyard.
- **Background health updates.** A long-lived `HKObserverQuery` wakes the app when new step data arrives, processes any missed days on a background `ModelContext`, and fires hunger/critical notifications.
- **Daily walk nudges.** Scheduled local notifications between 9am and 6pm with friendly copy.
- **Home screen widget.** Small and medium families showing the koala, today's steps, leaf stock, and health. The app writes a `PetSnapshot` to a shared App Group; the widget reads it on each timeline refresh.
- **Themed app icons.** Picking a koala color also switches the app icon to match.
- **Animated koala.** Idle blinks, tap-to-wiggle, eating animation with sparkle burst on feed.

## Project layout

```
Walkie/
  WalkieApp.swift           App entry, ModelContainer, HealthKit setup
  Models/
    Pet.swift               @Model Pet + GraveyardPet
    PetColor.swift          Palette + Color(hex:) helper
  Services/
    HealthKitService.swift  Step queries, observer, leaf ledger
    PetManager.swift        Foreground refresh + feed actions; writes snapshots
    BackgroundPetUpdater.swift  HK-observer-driven background updates
    NotificationService.swift   Permission, daily reminders, hunger pings
    AppIconManager.swift    Alternate-icon switcher
  Views/
    RootView.swift          Splash → Onboarding/Home routing
    OnboardingView.swift    First-run name + color picker
    HomeView.swift          Tabs: Home, Graveyard, Settings
    KoalaView.swift         The koala (SwiftUI shapes + keyframe animator)
    GraveyardView.swift     Deceased pets list
    SettingsView.swift      Step goal, app icon, daily reminders
    SplashView.swift        Animated splash with koala
  Shared/                   Files shared with the widget target
    AppGroupKeys.swift      App Group ID + UserDefaults wrapper
    PetSnapshot.swift       Codable snapshot for the widget
  Walkie.entitlements       HealthKit + App Group
  Info.plist                Generated from project.yml

WalkieWidget/
  WalkieWidgetBundle.swift  Widget bundle entry
  WalkieWidget.swift        Provider, entry, small + medium views

WalkieWidgetExtension.entitlements   App Group entitlement for the widget
project.yml                          XcodeGen spec (source of truth)
scripts/
  generate_icon.swift / render-icons.sh    Generates app icon variants
  generate_splash.swift / render-splash.sh Generates the launch image
```

## Getting started

Requirements:
- Xcode 16+, iOS 18+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — install via `brew install xcodegen`
- An Apple Developer account (HealthKit requires real device entitlements)

```bash
git clone <this repo>
cd walkie
xcodegen generate
open Walkie.xcodeproj
```

Run on a real device (HealthKit step data is not available in the simulator). On first launch you'll grant Health permission, name your koala, pick a color, and then start walking.

## Working with the project

**`project.yml` is the source of truth.** `Walkie.xcodeproj/` is gitignored. After editing `project.yml`, run `xcodegen generate` to refresh the project. Don't add targets, files, or build settings through Xcode's UI — they'll be wiped on the next regenerate.

**Regenerate the launch image** after changing `scripts/generate_splash.swift`:

```bash
bash scripts/render-splash.sh
```

**Regenerate the app icons** after changing `scripts/generate_icon.swift`:

```bash
bash scripts/render-icons.sh
```

Both scripts compile their generators against the macOS SDK and write PNGs into `Walkie/Assets.xcassets/`.

## How the widget data flow works

The widget can't query HealthKit on its own, so the app pushes a snapshot whenever pet state changes:

1. `PetManager.refresh(pet:)` / `feed(pet:)` and `BackgroundPetUpdater.update(...)` build a `PetSnapshot`.
2. The snapshot is JSON-encoded into the `group.com.jonstuebe.petwalkie` App Group's `UserDefaults`.
3. `WidgetCenter.shared.reloadAllTimelines()` is called to nudge WidgetKit.
4. `PetProvider.getTimeline(...)` reads the snapshot back and emits a single entry, refreshing every 30 minutes as a fallback.

If you ever need to extend the widget to show more fields, add them to `PetSnapshot` and the writers in `PetManager` / `BackgroundPetUpdater`.

## Leaf ledger

Defined in `HealthKitService.swift`:

- 1 leaf unlocks every `goal / 10` steps (so a 10k goal = 1k steps per leaf).
- Leaves are consumed by feeding (each feed = +0.1 health, max 1.0).
- Leaves are "earned − spent" for the day. Excess is unused; there's no carry-over.
- Hitting your goal earns enough leaves (10) to fully refill an empty koala.
