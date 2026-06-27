# BayHop 🚆🧭

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

**BayHop** is a Bay Area transit & exploration app where the assistant answers in _live user interface_ instead of plain text. Ask _"Downtown Berkeley → SFO, leave now"_ or _"Plan a playful Oakland food crawl"_ and a language model streams back real Flutter cards — trip plans, live departure boards, place lists, service alerts — rendered on top of an interactive map.

It's a **Generative UI (GenUI)** app built on Flutter and the [`genui`](https://pub.dev/packages/genui) package, and it started life as the [Very Good Ventures GenUI Hackathon Starter](https://github.com/VGVentures/genui_hackathon_starter). This README covers both: **what BayHop is** and **how to build on the GenUI architecture underneath it**.

<!-- Add screenshots/GIFs of the Transit and Explore tabs here. -->

---

## What's inside

BayHop is a two-tab experience (a bottom `NavigationBar` over an `IndexedStack`, in `lib/shell_page.dart`):

### 🚆 Transit tab (`lib/home_page.dart`)

A full-bleed [OpenStreetMap](https://www.openstreetmap.org/) map with a draggable, frosted bottom sheet that hosts the live generated UI. Ask for a route or departures and the model replies with:

- **Journey cards** — origin → destination trip options with a step-by-step timeline (walk / ride / change legs) and a colored route drawn on the map.
- **Live departure boards** — real-time data from **BART** (`api.bart.gov`) and the **511 SF Bay Open Data** SIRI feed (Muni, Caltrain, AC Transit, ferries, and other monitored operators), with a 60-second cache and 30-second auto-refresh. Falls back to clearly-labeled _Planned_/_Estimated_ rows when a live fetch fails.
- **Service alerts and notes** for delays and disruptions.

### 🧭 Explore tab (`lib/explore/explore_page.dart`)

A "Bay Area Explorer" surface that turns a vibe or neighborhood into a transit-friendly mini-adventure:

- **Exploration branches** the model suggests to drill into ideas.
- **Place cards** grounded in **Google Places (New)** — real venues with ratings, price, hours, and photos.
- A persistent **itinerary** you build by adding places (saved locally via `shared_preferences`), which you can then **hand off to the Transit tab** to be routed in order.

### ⚙️ Under the hood

- **Generative UI core** — every card is described by the model as **A2UI** (agent-to-UI) JSON and rendered live into a `genui` `Surface`. The model can only ever ask for widgets you've registered in a **catalog**, so it can never request something the app can't draw.
- **Pluggable model clients** — ships with **Inception Labs Mercury 2** as the default LLM, plus ready-to-swap Google Gemini and Featherless clients behind one `ModelClient` interface.
- **Real device location** — `geolocator` finds your position and the nearest Bay Area transit stop, which is fed to the model as context.
- **BayHop design system** — a light-mode "generative transit" look: a fixed palette, a blue→purple AI gradient, transit-line bullets, and Space Grotesk / Hanken Grotesk / JetBrains Mono typography (`lib/transit/bayhop_tokens.dart`, `bayhop_atoms.dart`).

---

## What is GenUI, in one minute

A normal chat app sends your message to a model and gets **text** back. A GenUI app sends your message to a model and gets back a structured description of a **user interface** (in a format called **A2UI**). The `genui` package turns that description into live Flutter widgets on screen.

The model can only ever describe widgets you've told it about. That list of allowed widgets is the **catalog**. Because the same catalog is fed to the model _and_ used to render, the model can never ask for something your app can't draw.

So the two knobs you'll touch most are:

- **The catalog** — _what_ the model can build (the widget vocabulary).
- **The prompt** — _how_ the model should behave (persona, tone, domain rules).

BayHop has two of each, one per tab:

| Tab     | Catalog                                                   | System prompt                     |
| ------- | --------------------------------------------------------- | --------------------------------- |
| Transit | `lib/catalog.dart` (+ `lib/transit/transit_catalog.dart`) | `lib/prompt.dart`                 |
| Explore | `lib/explore/explore_catalog.dart`                        | `lib/explore/explore_prompt.dart` |

Everything else is plumbing that connects those to a model and to the screen.

---

## How BayHop works

```
your message
   │
   ▼
GenUiSession (lib/conversation.dart)
   │   combines catalog + system prompt via PromptBuilder.chat(...)
   │   adds per-turn context (time, location, itinerary)
   ▼
ModelClient (default: InceptionModelClient → Mercury 2)
   │   streams A2UI JSON chunks
   ▼
A2uiTransportAdapter → SurfaceController
   │
   ▼
live Flutter widgets in a genui Surface
```

`GenUiSession` (`lib/conversation.dart`) is the heart of the pipeline. It ties together the four pieces from the `genui` package — the `SurfaceController` (renders), the transport (carries A2UI chunks), the `Conversation` (tracks state), and the `ModelClient` (talks to the LLM) — and owns their lifecycle as a single unit. Each tab builds its own session with its own catalog and prompt.

### Model clients

All providers sit behind one abstraction, `ModelClient` (`lib/model/model_client.dart`). It owns the conversation history and exposes the streaming response; a concrete client only implements `generateResponse()`. Swap providers by passing a different `modelClientBuilder` to `GenUiSession` — nothing else changes.

| Client                   | File                                      | Default model               | API key env var     | Status                 |
| ------------------------ | ----------------------------------------- | --------------------------- | ------------------- | ---------------------- |
| `InceptionModelClient`   | `lib/model/inception_model_client.dart`   | `mercury-2`                 | `INCEPTION_API_KEY` | **Default (wired in)** |
| `GeminiModelClient`      | `lib/model/gemini_model_client.dart`      | `gemini-3.5-flash`          | `GEMINI_API_KEY`    | Available — opt in     |
| `FeatherlessModelClient` | `lib/model/featherless_model_client.dart` | `Qwen/Qwen2.5-72B-Instruct` | `FEATHERLESS_API_KEY` | Available — opt in   |

To switch models, supply the matching key and pass the builder, e.g. `GenUiSession(modelClientBuilder: GeminiModelClient.new, ...)`. To add a new provider, write a `ModelClient` subclass.

---

## Getting started

### 1. Install Flutter

BayHop targets the Flutter SDK that ships **Dart `^3.12.1`** (see [`pubspec.yaml`](pubspec.yaml)). If you've never installed Flutter, follow the official guide for your OS at [docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install), then confirm your toolchain:

```sh
flutter doctor
```

You want green checkmarks for **Flutter** plus at least one run target (Xcode for macOS/iOS, the Android toolchain for Android, or Chrome for web). The quickest path on a Mac with no devices is the native **macOS** app; **Chrome** works on any OS.

> Supported platforms in this repo: **macOS, iOS, Android, and web**. (There are no `windows/` or `linux/` desktop folders; run `flutter create .` if you want to add them.)

### 2. Get your API keys

| Key                                  | Needed for                                                         | Where to get it                                                                                                              |
| ------------------------------------ | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Inception** (`INCEPTION_API_KEY`)  | **Required** — the default model that powers both tabs            | [platform.inceptionlabs.ai](https://platform.inceptionlabs.ai/dashboard/api-keys)                                          |
| **Google Places** (`GOOGLE_PLACES_API_KEY`) | Optional — real place cards in Explore (and Transit place search) | [Google Cloud Console](https://developers.google.com/maps/documentation/places/web-service/get-api-key) → enable **Places API (New)** |
| **511** (`KEY_511`)                  | Optional — live departures beyond BART (Muni, Caltrain, AC, ferries…) | [511.org Open Data token](https://511.org/open-data/token)                                                              |

**BART real-time departures work out of the box** using BART's public demo key — no setup required. Supply your own with `BART_API_KEY` if you have one.

### 3. Configure your keys

Keys are injected at **build time** as compile-time constants (`String.fromEnvironment`), so they never live in source control. Copy the template and fill in the keys you have:

```sh
cp .env.example .env
# then edit .env and paste your values
```

`.env` is gitignored. At minimum set `INCEPTION_API_KEY`; the other entries can stay blank and those features simply stay off.

> **Compile-time, not runtime.** Because keys are baked in via `--dart-define`, editing `.env` requires a **restart** (not just hot reload). A plain shell `export INCEPTION_API_KEY=...` is **not** picked up — it must go through `--dart-define`/`--dart-define-from-file`.

### 4. Install dependencies and run

```sh
flutter pub get
```

Then run on your platform of choice, passing the env file:

```sh
# macOS desktop (quickest on a Mac)
flutter run -d macos --dart-define-from-file=.env

# Web (Chrome) — works on any OS
flutter run -d chrome --dart-define-from-file=.env

# iOS / Android (device or simulator/emulator running)
flutter run -d ios      --dart-define-from-file=.env
flutter run -d <device> --dart-define-from-file=.env
```

The first build takes a minute or two; later runs are faster. Once it's up, pick **Transit** or **Explore**, tap a suggestion, or type a request like _"Next trains from Embarcadero"_.

> **Web note:** browsers may block direct calls to `api.bart.gov` (CORS). Route BART through a small proxy by setting `BART_PROXY_BASE_URL`. Geolocation also prompts differently on web.

> **Tip:** Tired of typing the flag? In VS Code add a `launch.json` config with `"args": ["--dart-define-from-file=.env"]`.

---

## Configuration reference

Every setting is a `--dart-define` (or a line in `.env`):

| Variable                | Required?                    | Enables                                                  | Default if unset                       |
| ----------------------- | ---------------------------- | -------------------------------------------------------- | -------------------------------------- |
| `INCEPTION_API_KEY`     | **Yes** (default model)      | The Mercury 2 LLM powering both tabs                     | _Model calls fail with a clear error_  |
| `GOOGLE_PLACES_API_KEY` | For place search             | Explore place cards & Transit place search               | _Place cards show a warning note_      |
| `KEY_511`               | For non-BART live departures | 511 SF Bay live boards (Muni, Caltrain, AC, ferries…)    | _BART still works; 511 boards error_   |
| `BART_API_KEY`          | Optional                     | Use your own BART API key                                | Public BART demo key (rate-limited)    |
| `BART_PROXY_BASE_URL`   | Optional                     | Route BART requests through a proxy (e.g. web CORS)      | Direct calls to `api.bart.gov`         |
| `GEMINI_API_KEY`        | Only if you swap to Gemini   | `GeminiModelClient`                                      | —                                      |
| `FEATHERLESS_API_KEY`   | Only if you swap to Featherless | `FeatherlessModelClient`                              | —                                      |

Missing optional keys degrade **per feature** — the app still launches; only the feature that needs the key is affected.

---

## Project layout

```
lib/
├── main.dart                 # entry point → runApp(MainApp)
├── app.dart                  # MaterialApp "BayHop": theme + BayHop design tokens
├── shell_page.dart           # two-tab shell; owns shared location & itinerary state
│
├── conversation.dart         # GenUiSession — the GenUI pipeline (the heart)
├── catalog.dart              # default (Transit) catalog = Basic widgets + transit items
├── prompt.dart               # default (Transit) system prompt — Bay Area transit rules
│
├── model/                    # pluggable LLM clients behind one ModelClient interface
│   ├── model_client.dart     #   the abstraction + the swap point
│   ├── inception_model_client.dart   # ← default (Mercury 2)
│   ├── gemini_model_client.dart      # alternate (opt in)
│   └── featherless_model_client.dart # alternate (opt in)
│
├── home_page.dart            # Transit tab: OSM map + bottom sheet hosting the Surface
├── transit/                  # transit GenUI cards, live departures (BART + 511),
│   │                         #   line palette, route geometry, BayHop design system
│   ├── transit_catalog.dart  #   8 transit components the model can emit
│   ├── transit_widgets.dart  #   the card widgets + journey/leg/departure models
│   ├── bart_departures_client.dart   # BART real-time + 511 Open Data client
│   ├── transit_lines.dart    #   line colors, BART aliases, public demo key
│   ├── transit_route_geometry.dart   # journey → map route overlay
│   ├── bayhop_tokens.dart    #   palette, AI gradient, typography
│   └── bayhop_atoms.dart     #   shared primitives (bullets, journey strip, frosted surface…)
│
├── explore/                  # Explore tab
│   ├── explore_page.dart     #   composer + generated content + itinerary panel
│   ├── explore_catalog.dart  #   7 explore components (hero, summary, mosaic, plan, option, place search, note)
│   ├── explore_prompt.dart   #   Explore system prompt
│   ├── explore_widgets.dart  #   explore card widgets (incl. live Places search)
│   ├── itinerary.dart        #   ItineraryStop model + controller (add/reorder/dedupe)
│   ├── itinerary_store.dart  #   shared_preferences persistence
│   └── *_handoff_controller.dart     # cross-tab handoff (Transit ⇄ Explore)
│
├── location/                 # geolocation + map
│   ├── user_location_controller.dart # geolocator-backed location state
│   ├── osm_map_background.dart        # flutter_map OpenStreetMap background + route overlay
│   ├── bay_area_transit_stops.dart    # hardcoded stop dataset + nearest-stop lookup
│   └── ...
│
└── places/                   # Google Places (New) v1 client + result models
```

Start by editing the catalogs and prompts — you can reshape a lot of the experience without touching the plumbing.

---

## Testing & quality

The project lints with [`very_good_analysis`](https://pub.dev/packages/very_good_analysis) and aims for a **zero-issue** analyze and a **green** test run.

```sh
flutter analyze        # static analysis (very_good_analysis rules)
flutter test           # unit + widget tests (flutter_test + mocktail)
dart format .          # format
```

Tests live in `test/`, mirroring the `lib/` structure. For GenUI behavior, cover prompt/catalog assumptions and model-client error paths without requiring a live API call.

---

## Where to go next

- **Teach the model new tricks.** Add a `CatalogItem` to `lib/catalog.dart` or one of the per-tab catalogs. Once it's registered, the model can use it.
- **Change the personality or domain rules.** Edit `lib/prompt.dart` or `lib/explore/explore_prompt.dart`.
- **Try a different model.** Supply the relevant key and pass `GeminiModelClient.new` / `FeatherlessModelClient.new` (or write your own `ModelClient`) to `GenUiSession`.
- **Learn the framework.** See the [`genui` package on pub.dev](https://pub.dev/packages/genui) for the full catalog API and A2UI format.

---

## Notes & limitations

- The bundled BART key (`MW9S-E7SL-26DU-VV8V`) is BART's well-known **public demo key** — fine for local development, not for production traffic.
- Map route geometry is **approximate** (built from hardcoded anchor points and station sequences), not from a routing API.
- The map uses the public OpenStreetMap tile server; for anything beyond local development, review the [OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/) and set a proper user agent.
- Don't ship public web/mobile builds with secrets embedded via `--dart-define`. Use a server-side proxy for production access to keyed APIs (511, Places).

## Data & credits

- Transit data: **BART API** and **511 SF Bay Open Data**.
- Map tiles: **© OpenStreetMap contributors**.
- Places: **Google Places API (New)**.

---

Built on the GenUI Hackathon Starter, developed with 💙 by [Very Good Ventures][very_good_ventures_link] 🦄

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_ventures_link]: https://verygood.ventures
