# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commit messages

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/). CI enforces this on every PR.

```
<type>[(<scope>)][!]: <short description>
```

Common types: `feat` `fix` `docs` `refactor` `perf` `test` `chore` `ci`  
Breaking change: append `!` to the type, e.g. `feat!:` or `fix(api)!:`

Install the local commit-msg hook once per clone so violations are caught before push:

```bash
git config core.hooksPath .githooks
```

## Build system constraints

All compilation happens **inside the SailfishOS build engine container** — you cannot run `qmake` or `make` directly on the host. The build engine is a 32-bit (i486) Docker image.

**Always use `/usr/bin/docker`**, not `docker` (which is aliased to `podman` on this machine).

### Build the app (i486 emulator target)

```bash
chmod -R a+rw .
/usr/bin/docker run --rm \
  -v "$(pwd):/home/mersdk/build" \
  -w /home/mersdk/build \
  --user mersdk \
  ghcr.io/juergenbr/karakeep-build-env:latest \
  mb2 -t SailfishOS-5.0.0.62-i486 -s rpm/harbour-karakeep.spec build
```

Output RPM: `RPMS/harbour-karakeep-0.x.y-1.i486.rpm`

For `aarch64` (device), replace `i486` with `aarch64` in `-t` and the source mount path remains the same.

### Deploy and run on emulator

```bash
sfdk device exec rpm -i /path/to/harbour-karakeep-*.rpm   # first install
sfdk deploy --sdk                                          # subsequent deploys
```

Or push RPM via SSH: the emulator typically listens on `localhost:2223`.

### Build and run the integration tests

Tests require a real Karakeep server (no mocks). Set env vars `KARAKEEP_URL` and `KARAKEEP_API_KEY` before running:

```bash
# 1. Build the test binary (host-native, not cross-compiled)
/usr/bin/docker run --rm \
  -v "$(pwd):/home/mersdk/build" \
  -w /home/mersdk/build \
  --user mersdk \
  ghcr.io/juergenbr/karakeep-build-env:latest \
  bash -c "qmake tests/tests.pro -o tests/Makefile && make -C tests"

# 2. Run (set env vars first)
KARAKEEP_URL=https://... KARAKEEP_API_KEY=... tests/tst_karakeepapi -v2

# Run a single test function
KARAKEEP_URL=... KARAKEEP_API_KEY=... tests/tst_karakeepapi -v2 testWhoAmI
```

Tests create and delete bookmarks tagged `__sailfish_test__` to avoid polluting the server.

## Architecture

### C++ / QML boundary

The app follows the SailfishOS pattern: C++ objects are registered as QML context properties in `src/harbour-karakeep.cpp` and accessed by name in QML.

- `AppSettings` → exposed as `AppSettings` — wraps `QSettings`, stores `serverUrl` and `apiKey`, exposes `configured` (bool) as a derived property
- `KarakeepApi` → exposed as `KarakeepApi` — all network calls are async slots; results come back as signals

QML pages connect to `KarakeepApi` signals via `Connections { target: KarakeepApi }`. The error signal is uniform across all operations:
```
signal requestError(operation: string, httpStatus: int, message: string)
```
`httpStatus == 0` means a network-level failure (no server response).

### Shared backend: `karakeep_backend.pri`

`karakeep_backend.pri` is included by both the main app (`harbour-karakeep.pro`) and the test harness (`tests/tests.pro`). It pulls in `src/api/appsettings.*`, `src/api/karakeepapi.*`, and `src/api/karakeeptypes.h`, plus `QT += network`. Adding a new C++ API class means adding it here.

### Data types: `karakeeptypes.h`

All API response types (`Bookmark`, `BookmarkTag`, `Tag`, `BookmarkList`, `KarakeepUser`) live in `karakeeptypes.h` as plain structs with `fromJson()` and `toVariantMap()`. `toVariantMap()` is what gets passed across the C++/QML boundary via signals. Never pass typed structs directly to QML.

`parseIsoDateTime()` is a Qt 5.6 workaround — Qt 5.6 does not parse ISO 8601 timestamps with milliseconds or timezone offsets. Always use it when reading dates from the API.

### QML structure

```
qml/harbour-karakeep.qml      # ApplicationWindow; holds shared cover state
qml/cover/CoverPage.qml       # Shows bookmark count + last title; quick-add action
qml/pages/MainPage.qml        # Bookmark list, search, filters, pull-down actions
qml/pages/BookmarkDetailPage.qml
qml/pages/AddBookmarkPage.qml
qml/pages/SettingsPage.qml    # Server URL + API key; "Test connection" button
```

The root `ApplicationWindow` holds `totalBookmarkCount`, `lastBookmarkTitle`, and the `addBookmarkRequested()` signal so the cover page and main page can share state without direct page-to-page references.

### Qt 5.6 compatibility

The target runtime is Qt 5.6 (SailfishOS 4/5). Known pitfalls already hit:
- No `String.endsWith()` — use `.charAt(str.length - 1) === "/"` instead
- No ISO 8601 millisecond/timezone parsing — use `parseIsoDateTime()` from `karakeeptypes.h`
- `QVariant(void*)` constructor is deleted — never pass a `QQuickItem*` (or any raw pointer) to `setContextProperty()`; wrap it first or don't pass it at all
- `QNetworkAccessManager::sendCustomRequest` with a body requires a `QIODevice*` — see `sendWithBody()` in `karakeepapi.cpp`

## Versioning and releases

**Do not manually edit version numbers.** Releases are fully automated via `release-please`.

Use [Conventional Commits](https://www.conventionalcommits.org/) for every commit:
- `fix: …` → patch bump (0.2.0 → 0.2.1)
- `feat: …` → minor bump (0.2.0 → 0.3.0)
- `feat!: …` or `BREAKING CHANGE:` footer → major bump

release-please opens a Release PR automatically after each push to main. Merging that PR creates the tag, GitHub Release, and triggers the build/attach pipeline. No manual changelog, spec, or QML edits needed — release-please updates them all.

The two version strings that release-please manages (annotated with `# x-release-please-version`):
1. `rpm/harbour-karakeep.spec` → `Version:`
2. `qml/pages/SettingsPage.qml` → the `DetailItem` value in the About section

## CI pipeline

| Workflow | Trigger | Jobs |
|----------|---------|------|
| `release-please.yml` | Push to main | Creates/updates Release PR; tags and creates GitHub Release on merge |
| `build.yml` | PR to main | `build` (i486 + aarch64) + `test` (if `KARAKEEP_URL` set) |
| `build.yml` | Release published | `build` (i486 + aarch64) → `attach-rpms` (uploads to the release) |

The CI image `ghcr.io/juergenbr/karakeep-build-env:latest` is not built with `docker build`; it is created via `docker run` + `sdk-manage` + `docker commit` (PAM requirement). See `Dockerfile` for the full reproduction procedure.
