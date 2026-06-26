# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter/Dart GenUI starter app. Main application code lives in `lib/`. The common customization points are `lib/catalog.dart` for model-renderable widgets and `lib/prompt.dart` for assistant behavior. App shell and UI flow are in `lib/main.dart`, `lib/app.dart`, `lib/home_page.dart`, and `lib/widgets/`. Model integration code is isolated under `lib/model/`, including the shared `ModelClient` interface and provider-specific clients.

Platform scaffolding is kept in `android/`, `ios/`, `macos/`, and `web/`. Planning notes live in `docs/brainstorm/` and `docs/plan/`. There is currently no top-level `test/` directory; add Dart tests there as coverage grows.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart and Flutter dependencies from `pubspec.yaml`.
- `flutter analyze`: run static analysis with the repository's `very_good_analysis` rules.
- `dart format .`: format Dart files using the standard formatter.
- `flutter test`: run Flutter unit and widget tests.
- `flutter run -d macos --dart-define=FEATHERLESS_API_KEY=your_key_here`: run the desktop app locally on macOS. Use `windows` or `linux` on those platforms.

Run `flutter doctor` when setting up a new machine or debugging toolchain issues.

## Coding Style & Naming Conventions

Follow idiomatic Dart with two-space indentation and trailing commas where they improve formatting. Keep widgets, model clients, and session logic separated by responsibility. Use `UpperCamelCase` for types, `lowerCamelCase` for members and local variables, and `snake_case.dart` for file names.

The repository includes `package:very_good_analysis` and disables mandatory public API docs. Prefer readable, direct code. Keep the primary logic path obvious; move secondary details into local private helpers only when that makes the caller easier to understand.

## Testing Guidelines

Use `flutter_test` for widget and unit tests, and `mocktail` for mocks. Place tests in `test/` and name files with the `*_test.dart` suffix, mirroring the source path where practical, such as `test/model/featherless_model_client_test.dart`. For GenUI behavior, cover prompt/catalog assumptions and model-client error paths without requiring a live API call.

## Commit & Pull Request Guidelines

Recent history uses short, imperative subjects, sometimes with Conventional Commit prefixes such as `feat:` and `docs:`. Keep that style: `feat: add custom catalog item`, `fix system prompt`, or `docs: update setup steps`.

Pull requests should include a clear summary, relevant issue links, test results (`flutter analyze`, `flutter test`), and screenshots or screen recordings for visible UI changes. Do not commit API keys; pass `FEATHERLESS_API_KEY` via `--dart-define` or local editor configuration.
