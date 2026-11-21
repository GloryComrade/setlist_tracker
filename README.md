# Setlist Tracker

Marathon training tracker with a music-tour theme. Phase 1: log Shows (Studio Sessions with Tracks, and Live Shows), Song of the Show, the Setlist, plus Gear and Saved Mixes in Backstage.

## Try it

Every merge to `main` publishes the web app to https://glorycomrade.github.io/setlist_tracker/ (works on a phone too).

## Run it locally

Needs Flutter 3.50 or newer (it uses the new `material_ui` package).

```
flutter pub get
flutter run -d chrome          # web
flutter test                   # 20 tests: math, storage, and a full "book a Show" flow
flutter build web              # production web build in build/web
```

Data is saved in the browser (IndexedDB) on web and in a file on iOS. Clearing site data in the browser erases it.

## Where things live

```
lib/
  main.dart                     opens storage, starts the app
  app.dart                      routes (every screen has a URL) and the tab shell
  theme/app_theme.dart          colors, gradients, poster type
  models/                       Show, Track, StudioDetails, LiveDetails, Weather,
                                SongOfTheShow, Gear, SavedMix, enums
  logic/show_math.dart          pace, Track totals, time-weighted incline, time parsing
  data/
    repositories/               abstract storage contracts (no storage code)
    local/                      Sembast versions (IndexedDB on web, file on iOS)
    providers.dart              THE place to swap storage for Supabase/Firebase
  ui/
    setlist/                    home: Setlist grouped by week, filters, ticket cards
    show_form/                  Book a Show (new + edit)
    show_detail/                one Show: poster, numbers, Tracks or venue, song
    backstage/                  Gear, Saved Mixes, dialogs
    widgets/                    shared pieces, including the Track editor
test/
```

## Swapping storage later

Write `SupabaseShowRepository implements ShowRepository` (and the Gear / Saved Mix ones), then change the three providers at the top of `lib/data/providers.dart`. Records already carry UUID ids, `updatedAt`, soft-delete `deletedAt` and `schemaVersion` for syncing.

## Notes

- Studio Session distance and time come from the Tracks by default. Switch "Use Track totals" off to type what the treadmill screen said.
- Song of the Show is picked from a search list with album art (Apple's free iTunes Search, no key needed), or typed in. The Show page has Open in Spotify and Apple Music buttons. A Spotify-powered search needs a server for its API secret, so it waits for Phase 5.
- Saved Mixes are copied into a Show when picked, so editing a Mix never changes past Shows.
- Fonts (Bebas Neue, Inter) load from Google Fonts at runtime for now. Phase 4 bundles them so the app works offline.
