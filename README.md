# KaraKeep for SailfishOS

[![Build & release](https://github.com/juergenbr/karakeep-sailfishos/actions/workflows/build.yml/badge.svg)](https://github.com/juergenbr/karakeep-sailfishos/actions/workflows/build.yml)

A native [SailfishOS](https://sailfishos.org) client for [Karakeep](https://karakeep.app) — the self-hosted bookmark and read-it-later manager.

## Features

- **Browse bookmarks** — paginated list with favicon, title, domain, and tag pills
- **Search** — full-text search via the dedicated `/bookmarks/search` endpoint
- **Filter** — switch between All, Favourites, and Archived views
- **Add** — save a link or write a text note directly from the app or the cover page
- **Detail view** — description, AI summary, note editor, tags, author, publisher, and a one-tap open-in-browser button
- **Manage** — archive/unarchive, favourite/unfavourite, delete with a swipe-to-cancel remorse timer
- **Cover page** — shows total bookmark count, most recent title, and a quick-add action

## Requirements

| Requirement | Version |
|-------------|---------|
| SailfishOS  | 4.x or 5.x |
| Qt          | 5.6 (bundled with SailfishOS) |
| Karakeep server | Any recent release |

## Setup

1. Install the RPM from the [latest GitHub Release](https://github.com/juergenbr/karakeep-sailfishos/releases/latest).
2. Open the app. You will be taken to **Settings** on first launch.
3. Enter your **Server URL** (e.g. `https://karakeep.example.com`) and an **API Key** from your Karakeep web interface (Settings → API Keys).
4. Tap **Test connection** to verify, then navigate back to start browsing.

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | App layers, C++/QML boundary, page navigation |
| [API coverage](docs/api-coverage.md) | Karakeep REST endpoints implemented |
| [CI/CD pipeline](docs/ci-cd.md) | Build, test, and release workflow |

## Building from source

All builds run inside the SailfishOS build engine container. See [CLAUDE.md](CLAUDE.md) for the exact `docker run` commands, deploy instructions, and the test harness setup.

## Contributing

1. Fork the repository and create a branch from `main`.
2. Make your changes. Build and test locally (see [CLAUDE.md](CLAUDE.md)).
3. Open a pull request against `main`. The CI pipeline will build both `i486` and `aarch64` targets automatically.
4. Bump `Version:` in `rpm/harbour-karakeep.spec` and add a section to `CHANGELOG.md` before the PR is merged — the release job reads both.

## License

See [LICENSE](LICENSE).
