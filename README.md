# Trip Viewer

Trip Viewer is an unofficial Flutter client for viewing trip itineraries from a
saved trip ID or trip URL. It includes timeline, map, expenses, and packing-list
views.

This project is not affiliated with, endorsed by, or sponsored by Wanderlog.
Wanderlog is a trademark of its owner.

## Setup

1. Install `devenv`: `curl -fsSL https://devenv.sh | bash`
2. Enter the shell: `devenv shell`
3. Fetch packages: `devenv shell -- flutter pub get`
4. Run locally: `devenv shell -- flutter run`

## Quality Checks

- Analyze: `devenv shell -- flutter analyze`
- Test: `devenv shell -- flutter test`
- Build Android debug APK: `devenv shell -- flutter build apk --debug`
- Build web bundle: `devenv shell -- flutter build web --release`

## CI

GitHub Actions runs on GitHub-hosted `ubuntu-latest` runners. Analyze, test,
Android debug, Android release, and web build jobs are split so they can run on
separate runners.

## License

Trip Viewer is licensed under the GNU General Public License v3.0. See
`LICENSE`.
