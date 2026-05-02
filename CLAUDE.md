# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

An alternative Flutter client for viewing trip itineraries. Fetches trip data from `wanderlog.com/api/tripPlans/{tripId}` and displays it with a timeline view, map, expenses, and packing lists. Primary target is Android with web support.

## Build & Dev Commands

```bash
# Install dependencies
flutter pub get

# Code generation (required after model changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Localization generation
flutter gen-l10n

# Run tests
flutter test

# Run a single test file
flutter test test/trip_id_test.dart

# Lint
flutter analyze --no-fatal-infos --no-fatal-warnings

# Debug APK
flutter build apk --debug --target-platform android-arm64

# Release AAB (requires keystore setup)
flutter build appbundle --release

# Web
flutter build web --release --base-href '/'
```

Map functionality uses MapLibre. No access token is required.

## Architecture

**State management**: Pure `StatefulWidget` + `setState()`. No Provider/Riverpod/Bloc.

**Data flow**: Provider import reference → provider fetch client → `TripPlanResponse.fromJson()` (json_serializable) → cached in SharedPreferences via `TripCacheService` with a 7-day TTL → rendered in UI.

**Key directories under `lib/`**:
- `pages/` — Screen-level widgets. `trip.dart` is the main trip timeline (~850 lines) with date-based `PageView`, flight/hotel/transit aggregation by date, and a calendar strip.
- `models/` — `trip_plan.dart` contains the full data model hierarchy. Uses `@JsonSerializable()` with build_runner-generated `.g.dart` files.
- `services/` — `trip_provider_service.dart` (provider parsing/fetching, currently Wanderlog only), `trip_storage_service.dart` (local imported trip references), `trip_cache_service.dart` (local trip data cache).
- `widgets/blocks/` — Per-block-type widgets (`FlightBlock`, `PlaceBlock`, `HotelBlock`, `TransitBlock`, `NoteBlock`, `GenericBlock`).

**Block polymorphism**: `Block.getBlock()` factory deserializes by `type` field into specific subtypes (place, flight, transit, note, hotel).

**Navigation**: Bottom nav bar with `IndexedStack` (Trip, Explore, Settings). No named routes.

## Android Signing

Release builds use an encrypted keystore. The scripts in `android/scripts/` handle decryption (`decrypt-key.sh`) and `key.properties` generation (`setup-keystore.sh`). Required secrets: `DECRYPTION_KEY`, `STORE_PASSWORD`, `KEY_PASSWORD`. Package name: `it.denv.tripviewer`.

## CI/CD

GitHub-hosted Actions runners. Workflows in `.github/workflows/`:
- `ci.yml` — split ubuntu-latest jobs for analyze, test, build-debug, build-release (master → Google Play internal track + GitHub Release), build-web, and deploy to GitHub Pages
- `update-goldens.yml` — manual workflow to regenerate golden test images
