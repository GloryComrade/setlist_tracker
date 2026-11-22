# Setlist Tracker

Marathon training tracker with a music-tour theme. Phase 1: log Shows (Studio Sessions with Tracks, and Live Shows), Song of the Show, the Setlist, plus Gear and Saved Mixes in Backstage. Phase 2: The Tour, a rules-based marathon plan from a setup quiz, with a weekly Tour Schedule, treadmill settings for Studio days and one-tap "Done as planned".

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

## On an iPhone

Step-by-step, from `git pull` to the app on your phone (free Apple ID), then Sign in with Apple and TestFlight once you join the Apple Developer Program: [docs/iphone-setup.md](docs/iphone-setup.md). The app icon and web icons are drawn by `tool/app_icon.py` (`python3 tool/app_icon.py`, needs Pillow).

## Design rules

Every screen follows [DESIGN.md](DESIGN.md): colors, type, shapes, components and the tour vocabulary.

## Where things live

```
lib/
  main.dart                     opens storage, starts the app
  app.dart                      routes (every screen has a URL) and the tab shell
  theme/app_theme.dart          colors, gradients, poster type
  models/                       Show, Track, StudioDetails, LiveDetails, Weather,
                                SongOfTheShow, Gear, SavedMix, enums
                                tour.dart: Tour, TourSetup, TourWeek, PlannedShow
  logic/show_math.dart          pace, Track totals, time-weighted incline, time parsing
  logic/tour_builder.dart       The Tour's plan rules: phases, 10% rule, Rest Stops,
                                Headliner peak, Riegel paces, treadmill Tracks
  logic/tour_logging.dart       "Done as planned": a Planned Show into a logged Show
  data/
    repositories/               abstract storage contracts (no storage code)
    local/                      Sembast versions (IndexedDB on web, file on iOS)
    auth/                       sign-in contract (no Supabase code)
    sync/                       outbox, sync engine, sync controller
    remote/                     Supabase: settings, sign-in, cloud tables
    providers.dart              wires storage, sign-in and sync together
  ui/
    setlist/                    home: Setlist grouped by week, filters, ticket cards
    show_form/                  Book a Show (new + edit)
    show_detail/                one Show: poster, numbers, Tracks or venue, song
    tour/                       The Tour: setup quiz, Tour Schedule, Planned Show page
    backstage/                  Backstage Pass, Gear, Saved Mixes, dialogs
    widgets/                    shared pieces, including the Track editor
test/
```

## Accounts and syncing (Backstage Pass)

Signing in is optional. With Supabase settings passed at build time (`--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_KEY=…`), Backstage offers Google sign-in (and Apple, once switched on) and syncs Shows, Gear, Saved Mixes and Tours. The screens still read the on-device copy, so the app works offline; `lib/data/sync/` copies changes to and from the cloud underneath. Without the settings the app is local-only, as before.

Setup steps: [docs/backstage-pass-setup.md](docs/backstage-pass-setup.md). Database tables and security rules: `supabase/migrations/`.

## Notes

- Studio Session distance and time come from the Tracks by default. Switch "Use Track totals" off to type what the treadmill screen said.
- Song of the Show is picked from a search list with album art (Apple's free iTunes Search, no key needed), or typed in. The Show page has Open in Spotify and Apple Music buttons. A Spotify-powered search needs a server for its API secret, so it waits for Phase 5.
- Saved Mixes are copied into a Show when picked, so editing a Mix never changes past Shows.
- Fonts (Bebas Neue, Inter) are bundled in assets/fonts under the SIL Open Font License, so type works offline and on iOS.

## The Tour's rules

All in `lib/logic/tour_builder.dart`, covered by `test/tour_builder_test.dart`:

- 16 to 20 weeks, ending on Opening Night. More than 20 weeks out, the Tour starts later. Under 16 weeks there's a note; under 12 a warning that suggests a later race or a finish-only goal; under 6 it won't build.
- Phases: Rehearsals (about 30% of the build), On the Road, Headline Leg, then a 3-week Soundcheck (2 weeks on Tours under 18 weeks).
- Weekly miles rise by at most 10% over the last full week. Every 4th week is a Rest Stop at about 75%.
- The Headliner climbs by at most 2 miles a week and peaks at 20 miles (18 for finish goals or bases under 20 mi/week) 3 weeks before race week.
- No quality runs in Rehearsals or Rest Stops. Then one a week: tempo On the Road, 800 m repeats in the Headline Leg, a short tempo early in Soundcheck.
- Paces: Riegel (T2 = T1 × (D2/D1)^1.06) from a recent race, or else the goal time. Easy = marathon pace + 60 to 90 s/mi, tempo = predicted 10-mile pace, intervals = predicted 5K pace. With no race or goal, an optional easy pace sets them; otherwise Shows run by feel.
- Studio Sessions get a Track list at 1% incline, with speeds rounded to 0.1 mph.
