# BayHop 🚆

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

**A Generative UI (GenUI) transit copilot for the San Francisco Bay Area.**

Ask in plain language — _"Downtown Berkeley to SFO, leave now"_, _"next trains from Embarcadero"_, _"find coffee and bookstores near me"_ — and BayHop replies with a **live user interface** instead of a wall of text. Trip plans, live departure boards, service alerts, and place cards are described by the model and rendered as real Flutter widgets on a map-backed, iOS-style surface.

BayHop is built on top of the **GenUI Hackathon Starter**: it wires Inception Labs' [Mercury 2](https://docs.inceptionlabs.ai/get-started/get-started) model to Flutter's [`genui`](https://pub.dev/packages/genui) package, then layers on a transit domain — real BART/Muni/Caltrain geography, live departures, geolocation, Google Places, and a hand-built "BayHop" design system.

---

## Table of contents

- [What BayHop does](#what-bayhop-does)
- [What is GenUI, in one minute](#what-is-genui-in-one-minute)
- [How it works](#how-it-works)
- [Getting started](#getting-started)
- [Configuration & API keys](#configuration--api-keys)
- [Live data sources](#live-data-sources)
- [Project layout](#project-layout)
- [The catalogs](#the-catalogs-what-the-model-can-build)
- [Development](#development)
- [Extending BayHop](#extending-bayhop)
- [Credits](#credits)

---

## What BayHop does

BayHop has two tabs, switched from the bottom navigation bar:

### 🚆 Transit
A full-screen OpenStreetMap background with the user's location, fronted by a frosted, draggable bottom sheet. Type a request into the floating search bar and the model streams back one of:

- **Trip plans** — one to three ranked journeys with legs, transfers, fares, crowding, depart/arrive times, and a recommended option.
- **Live departures** — real-time boards from BART and 511-monitored operators when data is available, planned estimates otherwise.
- **Service alerts** — delays and status, always explicit about whether the data is live or a planning estimate.

A "nearby" row finds your closest BART/Muni/Caltrain stop via geolocation and offers it as a one-tap origin. The bottom sheet intentionally hosts the **live GenUI surface** — every card you see is model-generated, not hardcoded.

### 🧭 Explore
A trip/itinerary builder for Bay Area exploration. Ask for day plans, neighborhoods, food crawls, or transit-friendly outings and the model returns branching idea cards and **Google Places-grounded** venue cards you can save into an itinerary. Saved stops are fed back to the model as context so it avoids duplicates.

The two tabs run independent GenUI sessions with their own catalogs and system prompts, but share the same `UserLocationController` and model client.

---

## What is GenUI, in one minute

A normal chat app sends your message to a model and gets text back. GenUI sends your message to a model and gets back a structured description of a UI (in a format called **A2UI**, "agent-to-UI"). The `genui` package turns that description into live Flutter widgets on screen.

The model can only ever describe widgets you've told it about. That list of allowed widgets is the **catalog**. Because the same catalog is fed to the model _and_ used to render, the model can never ask for something the app can't draw.

So the two knobs that shape behavior most are:

- **the catalog** — _what_ the model can build (the widget vocabulary).
- **the system prompt** — _how_ the model should behave (persona, domain rules, geography).

Everything else is plumbing that connects those two things to Mercury 2 and to the screen. New to GenUI? See the [`genui` package on pub.dev](https://pub.dev/packages/genui).

---

## How it works

```
 your request ─▶ GenUiSession ─▶ ModelClient (Mercury 2)  ── streams A2UI JSON ─┐
                     │                                                          │
        location +   │                                                          ▼
        time context │                            A2uiTransportAdapter ──▶ SurfaceController
                     │                                                          │
                     └───────────────── Conversation (state, surfaces) ◀────────┘
                                                   │
                                                   ▼
                                       Surface widget renders live cards
```

The pipeline is owned by a single class, **`GenUiSession`** (`lib/conversation.dart`), which builds and disposes four pieces as one unit:

1. **`ModelClient`** (`lib/model/`) — a model-agnostic interface that owns conversation history and streams raw text chunks. The default is **`InceptionModelClient`** (Mercury 2, via Inception's OpenAI-compatible streaming endpoint). Drop-in alternates for **Gemini** and **Featherless** ship alongside it.
2. **`A2uiTransportAdapter`** — bridges the model's streamed chunks into the GenUI transport, parsing A2UI as it arrives.
3. **`SurfaceController`** — renders surfaces from the catalog and tracks which exist.
4. **`Conversation`** — ties controller and transport together and exposes the combined state (active surfaces, waiting status) that the UI listens to.

On every turn, `GenUiSession` enriches the user's request with the **current time** and a **context provider** (the nearest-stop location snapshot on the Transit tab, the saved itinerary on Explore) before sending it to the model, so the model can resolve "near me" and "leave now" correctly.

The system prompt (`lib/prompt.dart` for Transit, `lib/explore/explore_prompt.dart` for Explore) encodes real Bay Area geography: line ids and fares, station ordering, valid transfer points, BART station abbreviations, and 511 agency ids. The `genui` framework automatically appends the A2UI format instructions and catalog schemas around it.

---

## Getting started

This walkthrough assumes you have **never installed Flutter**. The quickest path is running BayHop as a **native desktop app** — no simulators or devices needed.

### 1. Install Flutter

<details open>
<summary><strong>macOS</strong></summary>

1. Install [Xcode](https://apps.apple.com/us/app/xcode/id497799835) from the App Store (required to build macOS apps). After it installs, open it once so it can finish setting up, then run:
   ```sh
   sudo xcodebuild -runFirstLaunch
   ```
2. Install Flutter. If you have [Homebrew](https://brew.sh):
   ```sh
   brew install --cask flutter
   ```
   Otherwise, follow the manual steps at [docs.flutter.dev/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos).
3. Confirm everything is healthy:
   ```sh
   flutter doctor
   ```
   You want green checkmarks for **Flutter** and **Xcode** at minimum. Android/Chrome warnings are fine; you don't need them for macOS.

</details>

<details>
<summary><strong>Windows</strong></summary>

1. Install [Visual Studio](https://visualstudio.microsoft.com/downloads/) (the IDE, not VS Code) with the **"Desktop development with C++"** workload.
2. Install Flutter. If you have [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/), open PowerShell and run:
   ```powershell
   winget install --id=Google.Flutter -e
   ```
   Otherwise, follow the manual steps at [docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows). Reopen your terminal afterwards so `flutter` is on your `PATH`.
3. Confirm everything is healthy:
   ```powershell
   flutter doctor
   ```
   You want green checkmarks for **Flutter** and **Visual Studio** at minimum.

</details>

<details>
<summary><strong>Linux</strong></summary>

1. Install the desktop build dependencies. On Debian/Ubuntu:
   ```sh
   sudo apt-get update
   sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa \
     clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
   ```
   (Package names differ on Fedora/Arch; see the Flutter docs.)
2. Install Flutter. The simplest cross-distro option is [snap](https://snapcraft.io/):
   ```sh
   sudo snap install flutter --classic
   ```
   Otherwise, follow the manual steps at [docs.flutter.dev/get-started/install/linux](https://docs.flutter.dev/get-started/install/linux).
3. Confirm everything is healthy:
   ```sh
   flutter doctor
   ```
   You want green checkmarks for **Flutter** and **Linux toolchain** at minimum.

</details>

This project targets the Flutter SDK that ships **Dart `^3.12.1`** (see [pubspec.yaml](pubspec.yaml)). If `flutter doctor` reports an older Dart, run `flutter upgrade`.

### 2. Get an Inception API key

BayHop's model is Mercury 2, reached through the Inception API.

1. Go to the [Inception Platform](https://platform.inceptionlabs.ai/) and sign in.
2. Open [API Keys](https://platform.inceptionlabs.ai/dashboard/api-keys) and create a key.
3. Copy it somewhere safe. Keys are passed in at run time and never stored in source control.

This is the only **required** key. Everything else ([Configuration & API keys](#configuration--api-keys)) is optional and degrades gracefully.

### 3. Install dependencies

```sh
flutter pub get
```

### 4. Run the app

Enable desktop support for your platform once (harmless if already enabled):

```sh
flutter config --enable-macos-desktop    # or --enable-windows-desktop / --enable-linux-desktop
```

The most convenient way to supply keys is a **`.env` file** in the project root (it is git-ignored). Create one with the keys you have:

```ini
INCEPTION_API_KEY=your_inception_key
KEY_511=your_511_token
GOOGLE_PLACES_API_KEY=your_google_places_key
```

Then run, pointing Flutter at the file:

```sh
# macOS (use -d windows or -d linux on those platforms)
flutter run -d macos --dart-define-from-file=.env
```

Prefer not to use a file? Pass keys inline with `--dart-define` instead:

```sh
flutter run -d macos \
  --dart-define=INCEPTION_API_KEY=your_inception_key \
  --dart-define=KEY_511=your_511_token \
  --dart-define=GOOGLE_PLACES_API_KEY=your_google_places_key
```

The first build takes a minute or two; later runs are faster.

> **Why `--dart-define`?** Keys are injected as compile-time constants read with `String.fromEnvironment(...)`. This keeps secrets out of the codebase for local desktop runs. **Do not** ship public web/mobile builds with `KEY_511` or `GOOGLE_PLACES_API_KEY` embedded — use a server-side proxy for production access to those APIs.

> **Windows note:** In PowerShell the commands above work as-is. If a key contains special characters, quote the whole flag: `"--dart-define=INCEPTION_API_KEY=your_key_here"`.

> **Tip:** Tired of the long command? In VS Code, add a `launch.json` config with `"args": ["--dart-define-from-file=.env"]`.

---

## Configuration & API keys

All configuration is supplied at build time via `--dart-define` (or `--dart-define-from-file=.env`). Only `INCEPTION_API_KEY` is required; the rest unlock optional features and the app behaves sensibly without them.

| Variable                | Required | Used for                                                                                                                     |
| ----------------------- | :------: | ---------------------------------------------------------------------------------------------------------------------------- |
| `INCEPTION_API_KEY`     |   ✅     | The Mercury 2 model that powers every generated surface (Transit **and** Explore).                                           |
| `KEY_511`               |   ➖     | Live departures from [511 SF Bay Open Data](https://511.org/open-data/token) — Muni, Caltrain, AC Transit, VTA, ferries, and other monitored operators. Without it, the model falls back to planned estimates. |
| `BART_PROXY_BASE_URL`   |   ➖     | Optional base URL for a BART real-time proxy. Falls back to BART's public real-time feed when unset.                         |
| `GOOGLE_PLACES_API_KEY` |   ➖     | Grounds the Explore tab's venue cards with real [Google Places](https://developers.google.com/maps/documentation/places/web-service) data. Explore still works without it, just without live place lookups. |
| `GEMINI_API_KEY`        |   ➖     | Only if you swap the default model for `GeminiModelClient`.                                                                  |
| `FEATHERLESS_API_KEY`   |   ➖     | Only if you swap the default model for `FeatherlessModelClient`.                                                             |

Keys live in `.env` / your editor config, **never** in source control (`.env` and `.env.*` are git-ignored).

---

## Live data sources

BayHop blends model reasoning with real data so plans stay grounded:

- **BART real-time departures** — `lib/transit/bart_departures_client.dart` calls BART's public real-time feed (or a proxy via `BART_PROXY_BASE_URL`). Used when the model emits a `TransitLiveDepartures` board with `source: "bart"` and a known station abbreviation.
- **511 SF Bay Open Data** — the same client fetches live departures for Muni, Caltrain, AC Transit, VTA, SamTrans, Golden Gate, and ferries when `KEY_511` is set and the model supplies a known agency id + stop. Otherwise the model is instructed to show planned estimates and flag them as such.
- **Geolocation** — `lib/location/` uses `geolocator` to find the device's position, then resolves the nearest Bay Area transit stop from a built-in stop list. That snapshot is injected into the prompt so "near me" / "from here" resolve correctly, and surfaces a one-tap "nearby" origin in the UI.
- **Google Places** — `lib/places/google_places_client.dart` powers Explore's `ExplorePlaceSearch` cards with real venue details (name, address, rating, etc.) when `GOOGLE_PLACES_API_KEY` is set.

The model is explicitly prompted to never pretend an estimate is live data.

---

## Project layout

Everything meaningful lives in [`lib/`](lib/). The pieces you're most likely to touch are at the top.

### Shape the behavior (start here)

| File | What it's for |
| --- | --- |
| [`lib/prompt.dart`](lib/prompt.dart) | The **Transit** system prompt: Bay Area geography, line ids, fares, station ordering, transfer rules, BART/511 abbreviations, and which components to emit. |
| [`lib/explore/explore_prompt.dart`](lib/explore/explore_prompt.dart) | The **Explore** system prompt: exploration scope, when to branch ideas vs. fetch real places, Google Places compliance rules. |
| [`lib/transit/transit_catalog.dart`](lib/transit/transit_catalog.dart) | The **Transit catalog** — the widgets the model may render (journeys, departure boards, alerts, notes). |
| [`lib/explore/explore_catalog.dart`](lib/explore/explore_catalog.dart) | The **Explore catalog** — summaries, option cards, place search, notes. |
| [`lib/catalog.dart`](lib/catalog.dart) | Composes `BasicCatalogItems` with the transit catalog into the default vocabulary. |

### The GenUI pipeline

| File | What it's for |
| --- | --- |
| [`lib/conversation.dart`](lib/conversation.dart) | **`GenUiSession`** — the heart of the pipeline. Ties together the `SurfaceController`, transport, `Conversation`, and `ModelClient`, and enriches each turn with time + location/itinerary context. |
| [`lib/model/model_client.dart`](lib/model/model_client.dart) | The model-agnostic `ModelClient` interface (owns history + streamed `latestResponse`). Swap models by subclassing; nothing else changes. |
| [`lib/model/inception_model_client.dart`](lib/model/inception_model_client.dart) | Default client — Mercury 2 over Inception's streaming chat endpoint. |
| [`lib/model/gemini_model_client.dart`](lib/model/gemini_model_client.dart), [`featherless_model_client.dart`](lib/model/featherless_model_client.dart) | Alternate `ModelClient` implementations. |

### The app shell & UI

| File | What it's for |
| --- | --- |
| [`lib/main.dart`](lib/main.dart) · [`lib/app.dart`](lib/app.dart) | Entry point and root `MaterialApp` (BayHop theme, Google Fonts). |
| [`lib/shell_page.dart`](lib/shell_page.dart) | The two-tab shell (`Transit` / `Explore`) and shared location controller. |
| [`lib/home_page.dart`](lib/home_page.dart) | The Transit tab: OSM map background, frosted draggable bottom sheet, search bar, nearby row, and the live GenUI surface. |
| [`lib/explore/`](lib/explore/) | The Explore tab: page, catalog, prompt, custom widgets, and the itinerary model/controller. |
| [`lib/widgets/`](lib/widgets/) | Shared UI bits — message input and the optional A2UI source view. |

### Domain & design

| Directory | What it's for |
| --- | --- |
| [`lib/transit/`](lib/transit/) | Transit domain: line definitions, BART/511 departures client, catalog + rendering widgets, and the **BayHop design system** (`bayhop_tokens.dart` palette/typography, `bayhop_atoms.dart` reusable atoms). |
| [`lib/location/`](lib/location/) | Geolocation, the Bay Area stop list, nearest-stop logic, the location snapshot model, and the OSM map background. |
| [`lib/places/`](lib/places/) | Google Places client and result model used by Explore. |

Platform scaffolding lives in `android/`, `ios/`, `macos/`, and `web/`. Planning notes are under `docs/`.

---

## The catalogs (what the model can build)

The model can only ever request widgets registered in a catalog. BayHop ships two:

**Transit** (`lib/transit/transit_catalog.dart`)

| Component | Renders |
| --- | --- |
| `TransitSummary` | A one-line headline for the answer (trip, departures, or status). |
| `TransitJourney` | A featured route card: from→to, depart/arrive, duration, changes, fare, crowding, and ordered legs (ride / change / walk). |
| `TransitLiveDepartures` | A live departure board backed by BART or 511 data. |
| `TransitDepartures` | A planned departure board (estimates) when live data isn't available. |
| `TransitAlert` | A delay / service-status card. |
| `TransitNote` | A short caveat, warning, or planning-estimate disclaimer. |

**Explore** (`lib/explore/explore_catalog.dart`)

| Component | Renders |
| --- | --- |
| `ExploreSummary` | A headline for an exploration answer. |
| `ExplorerOptionCard` | A branching idea (city, neighborhood, vibe, route) the user can tap to explore further. |
| `ExplorePlaceSearch` | A Google Places-grounded venue lookup card. |
| `ExploreNote` | A constraint, missing-location prompt, or uncertainty note. |

Both build on `BasicCatalogItems` (text, columns, rows, buttons…) so the model can lay cards out freely.

---

## Development

| Command | What it does |
| --- | --- |
| `flutter pub get` | Install dependencies from `pubspec.yaml`. |
| `flutter analyze` | Static analysis with the repo's [`very_good_analysis`](https://pub.dev/packages/very_good_analysis) rules. Keep this **zero-issue**. |
| `dart format .` | Format all Dart files. |
| `flutter test` | Run the unit and widget test suite (`test/`, mirroring `lib/`). |
| `flutter run -d <device> --dart-define-from-file=.env` | Run the app locally. |

The quality bar for changes: `flutter analyze` clean and `flutter test` green. Tests use `flutter_test` for widgets/units and `mocktail` for mocks; transit, location, places, model, and explore logic are all covered without requiring live API calls.

Commit style follows the existing history — short, imperative subjects, occasionally with Conventional Commit prefixes (`feat:`, `fix:`, `docs:`). See [AGENTS.md](AGENTS.md) for the full contributor guide.

---

## Extending BayHop

- **Teach the model a new card.** Add a component to the transit or explore catalog (define its schema + a `fromJson` builder), then mention it in the matching system prompt. Once it's in the catalog, the model can use it.
- **Change the domain or personality.** Edit the system prompt strings — adjust geography, tone, or rules.
- **Add a data source.** Follow the BART/511 client pattern in `lib/transit/` or the Places client in `lib/places/`, then surface the data through a catalog component.
- **Swap the model.** Point `GenUiSession`'s `modelClientBuilder` at `GeminiModelClient`/`FeatherlessModelClient`, or write a new `ModelClient` subclass for any provider.
- **Learn the framework.** See the [`genui` package](https://pub.dev/packages/genui) for the catalog API and the A2UI format.

---

## Credits

BayHop is built on the **GenUI Hackathon Starter**, developed with 💙 by [Very Good Ventures][very_good_ventures_link] 🦄.

Powered by [Inception Labs Mercury 2](https://docs.inceptionlabs.ai/), Flutter's [`genui`](https://pub.dev/packages/genui), OpenStreetMap via [`flutter_map`](https://pub.dev/packages/flutter_map), and [511 SF Bay](https://511.org/open-data) / BART / Google Places data.

Licensed under the [MIT License](LICENSE).

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_ventures_link]: https://verygood.ventures
