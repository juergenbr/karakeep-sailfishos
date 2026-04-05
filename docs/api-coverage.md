# Karakeep API Coverage

Base URL: `{serverUrl}/api/v1`

Authentication: `Authorization: Bearer {apiKey}` on every request.

## Bookmarks

| Method | Endpoint | `KarakeepApi` slot | Notes |
|--------|----------|--------------------|-------|
| GET | `/bookmarks` | `fetchBookmarks(cursor, limit, archived, favourited, search)` | Switches to `/bookmarks/search` automatically when `search` is non-empty |
| GET | `/bookmarks/search` | _(called internally by `fetchBookmarks`)_ | Supports `q`, `archived`, `favourited`, `cursor`, `limit` |
| GET | `/bookmarks/{id}` | `fetchBookmark(id)` | |
| POST | `/bookmarks` | `createLinkBookmark(url, title, tagNames)` | `type: "link"`, `source: "mobile"` |
| POST | `/bookmarks` | `createTextBookmark(text, title, tagNames)` | `type: "text"`, `source: "mobile"` |
| PATCH | `/bookmarks/{id}` | `updateBookmark(id, fields)` | `fields` is a `QVariantMap`; any subset of bookmark fields |
| DELETE | `/bookmarks/{id}` | `deleteBookmark(id)` | |

### Pagination

`fetchBookmarks` uses cursor-based pagination. Pass `nextCursor` from the previous response as `cursor` in the next call. `MainPage` exposes a "Load more" button when `nextCursor` is non-empty.

### Tag operations on bookmarks

| Method | Endpoint | `KarakeepApi` slot |
|--------|----------|--------------------|
| POST | `/bookmarks/{id}/tags` | `attachTags(bookmarkId, tagNames)` |
| DELETE | `/bookmarks/{id}/tags` | `detachTags(bookmarkId, tagNames)` |

When creating a bookmark with tags (`createLinkBookmark` / `createTextBookmark` with a non-empty `tagNames` list), the API performs a two-step sequence internally:

1. `POST /bookmarks` → create bookmark
2. `POST /bookmarks/{id}/tags` → attach tags
3. `GET /bookmarks/{id}` → re-fetch so the emitted `bookmarkCreated` signal includes the tags

## Tags

| Method | Endpoint | `KarakeepApi` slot | Notes |
|--------|----------|--------------------|-------|
| GET | `/tags` | `fetchTags(nameContains, limit)` | Sorted by name; default limit 100 |

## Lists

| Method | Endpoint | `KarakeepApi` slot |
|--------|----------|--------------------|
| GET | `/lists` | `fetchLists()` |
| GET | `/lists/{id}/bookmarks` | `fetchListBookmarks(listId, cursor, limit)` |

> **Note:** Lists and tags are fetched by the C++ layer but are not yet wired to any UI page. The slots and signals exist for future use.

## User

| Method | Endpoint | `KarakeepApi` slot | Used for |
|--------|----------|--------------------|----------|
| GET | `/users/me` | `whoAmI()` | "Test connection" on Settings page |

## Signals reference

| Signal | Emitted by | Payload |
|--------|-----------|---------|
| `whoAmIFetched(user)` | `whoAmI` | `QVariantMap` with `id`, `name`, `email`, `role` |
| `bookmarksFetched(bookmarks, nextCursor)` | `fetchBookmarks` | `QVariantList` of bookmark maps, `QString` cursor |
| `bookmarkFetched(bookmark)` | `fetchBookmark` | `QVariantMap` |
| `bookmarkCreated(bookmark)` | `create*Bookmark` | `QVariantMap` (includes tags if any were attached) |
| `bookmarkUpdated(bookmark)` | `updateBookmark` | `QVariantMap` |
| `bookmarkDeleted(id)` | `deleteBookmark` | `QString` id |
| `tagsAttached(bookmarkId)` | `attachTags` | `QString` bookmarkId |
| `tagsDetached(bookmarkId)` | `detachTags` | `QString` bookmarkId |
| `listsFetched(lists)` | `fetchLists` | `QVariantList` of list maps |
| `listBookmarksFetched(listId, bookmarks, nextCursor)` | `fetchListBookmarks` | |
| `tagsFetched(tags)` | `fetchTags` | `QVariantList` of tag maps |
| `requestError(operation, httpStatus, message)` | any | `httpStatus == 0` = network error |
| `busyChanged()` | any | Emitted when pending request count crosses zero |
