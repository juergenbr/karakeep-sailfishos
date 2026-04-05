# Changelog

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
