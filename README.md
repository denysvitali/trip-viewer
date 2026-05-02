# Trip Viewer

Trip Viewer is a Flutter app for importing trip references from supported
providers and viewing itinerary details in one place. It includes timeline, map,
expenses, and packing-list views.

Only Wanderlog imports are supported today. Imported trips are stored locally as
provider references. Trip data is cached locally, refreshed manually on pull, and
refreshed in the background when the cache is older than about 7 days.

This project is independent and not affiliated with any supported provider.

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

## Android release signing secrets

If release builds are skipped with `Keystore not configured`, configure GH Actions
secrets with:
- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`

You can generate them and get ready-to-copy export lines in one step. If no keystore
exists at `KEYSTORE_PATH`, it auto-generates one.

```bash
cd /path/to/wanderlog_alt
./android/scripts/setup-gh-release-secrets.sh --create-keystore
```

If you want to control keystore values:

```bash
cd /path/to/wanderlog_alt
export KEYSTORE_KEY_ALIAS=upload
export KEYSTORE_DNAME='CN=TripViewer, OU=CI, O=TripViewer, L=Unknown, ST=Unknown, C=US'
./android/scripts/setup-gh-release-secrets.sh --create-keystore --force
```

Or if you already have a keystore:

```bash
cd /path/to/wanderlog_alt
export KEYSTORE_PATH=upload.jks
export KEYSTORE_STORE_PASSWORD=...
export KEYSTORE_KEY_PASSWORD=...
export KEYSTORE_KEY_ALIAS=...
./android/scripts/setup-gh-release-secrets.sh
```

To also upload to GitHub secrets directly:

```bash
export KEYSTORE_PATH=upload.jks
export KEYSTORE_STORE_PASSWORD=...
export KEYSTORE_KEY_PASSWORD=...
export KEYSTORE_KEY_ALIAS=...
export GITHUB_REPOSITORY=owner/repo
./android/scripts/setup-gh-release-secrets.sh --set-secrets
```

## License

Trip Viewer is licensed under the GNU General Public License v3.0. See
`LICENSE`.
