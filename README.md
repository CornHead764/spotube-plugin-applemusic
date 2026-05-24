# Spotube Apple Music Plugin

An Apple Music metadata provider for [Spotube](https://github.com/KRTirtho/spotube),
built on the same Hetu plugin architecture as the
[Spotify plugin](https://github.com/sonic-liberation/spotube-plugin-spotify).

It exposes catalog, library, search and browse data from Apple Music's JSON API
through the standard Spotube metadata-provider interface (`auth`, `user`,
`track`, `album`, `artist`, `playlist`, `search`, `browse`, `core`).

## How it works

Apple Music's web stack authenticates with two tokens:

| Token | Role | Where it comes from |
|---|---|---|
| **Developer token** | App-wide JWT, `Authorization: Bearer …` | Scraped from the music.apple.com web-player bundle. Shared by all users, valid for months. |
| **Media-User-Token** | Per-user token, `Media-User-Token: …` | The `media-user-token` cookie set after a user signs in at music.apple.com. |

Plus a **storefront** (e.g. `us`), resolved from `GET /v1/me/storefront`, which is
part of every catalog request path.

All requests go to `https://amp-api.music.apple.com` with an
`Origin: https://music.apple.com` header (the host the web developer token is
scoped to).

### Authentication

- **`auth.authenticate()`** (the flow Spotube invokes) prompts for your
  **Media-User-Token** via a form. From that single value the plugin scrapes the
  shared developer token, resolves the storefront, and persists everything to
  local storage. This works on every platform, including iOS.
  - Get the token by signing in at music.apple.com in a browser and copying the
    `media-user-token` cookie (dev tools → Application → Cookies), or from
    Cider's `GET /api/v2/client/tokens`.
- **`auth.authenticateWithWebview()`** is an alternative that signs in through
  music.apple.com in a webview and harvests the cookie automatically. It works on
  desktop hosts but **not on mobile** — Spotube's in-app webview lacks the
  new-window/popup support Apple's ID sign-in requires (on iOS it doesn't open at
  all), so it isn't wired into Spotube's login button.

Credentials are cached in local storage and the developer token is re-scraped on
a timer (default every 12 h) to self-heal against rotation.

## Project layout

```
plugin.json                     Plugin manifest
Makefile                        compile / archive targets
src/plugin.ht                   Entry point (AppleMusicMetadataProviderPlugin)
src/api/apple_music_api.ht      Thin client over the Apple Music JSON API
src/converter/converter.ht      Apple resources -> Spotube common shapes
src/segments/*.ht               auth, core, track, album, artist, playlist, user, search, browse
example/                        Flutter host app for local testing
```

## Building

Requires the Flutter SDK and the Hetu dev tools:

```bash
dart pub global activate hetu_script_dev_tools
make           # compiles src/plugin.ht -> build/plugin.out (+ copies to example)
make archive   # bundles plugin.json + plugin.out + logo.png -> build/plugin.smplug
```

Install the resulting `build/plugin.smplug` from Spotube's plugin settings.

To run the example host for testing:

```bash
cd example
flutter pub get
flutter run    # use the buttons to exercise each endpoint
```

## Known limitations

Apple Music's public API is narrower than Spotify's private GraphQL API, so a few
endpoints are best-effort:

- **Unsaving** (tracks/albums/artists/playlists) requires mapping a catalog id to
  a *library* id. We scan the most-recently-added library items, which covers the
  common "undo a save" case but won't find items buried deep in a large library.
- **`playlist.removeTracks`** is unsupported by the public API and resolves to
  `false`.
- **`playlist.update`** edits library-playlist attributes best-effort.
- **`track.radio`** has no public song-radio endpoint; it returns the primary
  artist's top songs as an approximation.
- **`album.releases`** uses the albums chart (no public "new releases" endpoint).
- **`user.me`** surfaces the storefront/country, since Apple exposes no public
  user-profile endpoint.
- **`isSaved*`** relies on the catalog `?include=library` relationship.

## Credits

Architecture and plugin contract from
[`hetu_spotube_plugin`](https://github.com/KRTirtho/hetu_spotube_plugin) and the
Spotify reference plugin by CornHead764.
