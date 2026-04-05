# Changelog

## [0.3.0](https://github.com/juergenbr/karakeep-sailfishos/compare/v0.2.0...v0.3.0) (2026-04-05)


### ### Added

* add Lists browsing and bookmark list management ([5059855](https://github.com/juergenbr/karakeep-sailfishos/commit/5059855e0a4cde7c12e02183ec7beb753b560b98))
* Lists — browse, view, and manage bookmark lists ([825790b](https://github.com/juergenbr/karakeep-sailfishos/commit/825790b4aabe6416002706dae1d618a5b40e6012))


### ### Fixed

* address PR review comments on Lists feature ([78be43a](https://github.com/juergenbr/karakeep-sailfishos/commit/78be43a797f0e8a887e93def5fe858da82664826))
* rename listBookmarksFetched param to avoid QML name collision ([04b4bbf](https://github.com/juergenbr/karakeep-sailfishos/commit/04b4bbfc17270431e87155c74b0f949615b0062c))
* use PUT /lists/{id}/bookmarks/{bookmarkId} for list membership ([8b2efeb](https://github.com/juergenbr/karakeep-sailfishos/commit/8b2efeb89a83570ddfd53181fa6ae4fba90bc875))


### ### Documentation

* add reliable test build instructions and troubleshooting to CLAUDE.md ([8888bab](https://github.com/juergenbr/karakeep-sailfishos/commit/8888bab852dac26e535313f5b46d295279c5b114))

## [0.2.0] — 2026-04-05

### Added
- Full-text bookmark search via dedicated `/bookmarks/search` endpoint
- Pull-down menu actions: "Add link" and "Add note" to create new bookmarks
- Pull-down filter toggles: "Show favourites" / "Show archived" (toggle back with "All bookmarks")
- Cover page: shows total bookmark count, title of the most recent bookmark, and a quick-add action
- Bookmark detail page: full metadata (description, summary, note, author, publisher, tags, created date), open-in-browser button
- Archive/unarchive and add/remove favourite from the bookmark context menu
- Delete bookmark with remorse timer (swipe-to-cancel) in the context menu
- Pagination with a "Load more" footer button (cursor-based, preserves active filter/search)
- Sailjail `Internet` permission declaration in the `.desktop` file (required for network access on SailfishOS 5)
- Integration test suite (`tst_karakeepapi`) covering: bookmarks list, search, create, update, delete, whoAmI

### Fixed
- Search keyboard dismissed on every keystroke — search now fires only on Enter key or X (clear) button
- X button in search field now reloads the full unfiltered bookmark list
- Search was sending `?q=` to the list endpoint (which ignores it); now correctly routes to `/bookmarks/search`
- Settings page values not persisting on navigation back — now saves per-field via `onEditingFinished`
- Binding loop on `status` property during initial page load — replaced `onStatusChanged` with `Component.onCompleted`
- `String.endsWith()` silent failure on Qt 5.6 V4 engine — replaced with ES5-compatible `.charAt()` check

## [0.1.0] — 2026-04-04

### Added
- Initial release: working SailfishOS app scaffold
- Bookmark list view with favicon, title, domain, tag pills, and status icons
- Settings page: server URL, API key, "Test connection" button
- Basic Karakeep REST API backend (`KarakeepApi` C++ singleton)
