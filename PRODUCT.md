# Product

<!-- impeccable:product-schema 1 -->

> How this file was made: written on 2026-11-22 without an interview, from Ryan's
> original project brief, his front page request of the same day, and the code.
> Lines marked **(assumption)** are inferred and not yet confirmed by Ryan.
> Lines with no mark are stated in the brief or provable in the repository.

## Platform

web

The shipped product is a Flutter app served on the web at https://setlisttracker.com.
The same code builds an iPhone app that is not on the App Store yet (TestFlight in
progress, `docs/app-store-listing.md`). When the iPhone app ships, revisit this value
**(assumption: stays `web` until then, because the web app is the only thing a visitor can open today)**.

## Users

- People training for a marathon who log their own runs, on a treadmill and outdoors,
  and who run to music. **(assumption: inferred from the feature set; Ryan has not
  described his users)**
- They use it on a phone, right after a run or while setting up a treadmill, and on a
  laptop when planning. The brief asks for "works well on mobile".
- US units: miles, mph, °F (from the brief).
- A second audience for the front page only: a first-time visitor to setlisttracker.com
  who has never seen the app and needs to understand it, then open it (Ryan's scope
  choice, 2026-11-22).
- Who the first real users are (friends, a running club, strangers) is **undecided**.

## Product Purpose

Setlist Tracker is a marathon training tracker with a music-tour theme. Every training
cycle is a Tour, every run is a Show, and race day is Opening Night (the big show).
It does two jobs: it keeps the log (the Setlist) and it writes the plan (The Tour).

Why it exists, in Ryan's words: none on record. **(assumption: the theme is there to
make a long training block feel like something you are on, not something you are
behind on.)**

Success is **undecided**. No metrics, targets or business model have been stated. The
web app is free to use and the planned App Store price is free.

## Positioning

- The tour vocabulary is the product, not a skin. It names the real objects of
  marathon training (long run = Headliner, taper = Soundcheck, cutback week = Rest
  Stop, treadmill segment = Track) and it is used on every screen.
- The plan is rules you can read, not AI: at most 10% more miles a week, a Rest Stop
  every 4th week, a Headliner that tops out at 18 to 20 miles three weeks before race
  week, paces from Riegel's formula. The rules live in `lib/logic/tour_builder.dart`
  and are listed in the README.
- Treadmill running is a first-class citizen: a Studio Session is logged Track by
  Track (speed in mph and incline), setups are kept as Saved Mixes, and planned
  Studio days arrive with the treadmill settings written out.
- Each run can carry one song, the Song of the Show, with the 15 seconds of it that
  mattered. Over a Tour they add up to The Record Wall.
- No account needed. Sign-in is only for syncing and for The Crew.

## Operating Context

- Opened in a browser at setlisttracker.com; works on a phone. iPhone app on the way.
- Typical loop: finish a run, Book a Show (or tap "Done as planned" on a Tour day),
  pick the Song of the Show, check The Charts.
- At a treadmill: read the planned Tracks, or load a Saved Mix in one tap.
- Once per training cycle: answer the 8-question quiz to Book The Tour.
- With friends: invite them to The Crew with a link or code, share chosen Shows, give
  an Encore.
- On iPhone only: import runs from Apple Health (read only).
- Works offline; with a Backstage Pass, changes sync when the connection is back.
- Hosting: one Cloudflare Worker serves the site and the API. Every merge to `main`
  deploys.

## Capabilities and Constraints

Shipped (proof for each is in the code; a line-by-line list was prepared for the front
page work):

- Log Shows: Studio Sessions (Tracks with start, end, mph, incline) and Live Shows
  (route, surface, elevation gain, weather), with distance, time, worked-out pace,
  effort 1 to 10, feel, notes, Gear.
- Saved Mixes and Gear (shoe miles, retire).
- Song of the Show with album art, search or type-in, and a 15-second "your part" clip.
- The Record Wall, top artists, track list and CSV export.
- The Tour: 8-question quiz, up to 20 weeks (16 to 20 usual; 6 minimum), four phases
  (Rehearsals, On the Road, Headline Leg, Soundcheck), Rest Stops, Headliners, paces,
  treadmill Tracks at 1% incline, "Done as planned", and Tour Manager note cards
  (missed Show, lighter week, faster paces) that change nothing until you tap Apply.
- The Charts: weekly miles, Headliner progression, Studio vs Live, streaks, Opening
  Night countdown.
- Gold Records: eleven personal records worked out from the log.
- The Crew: invite-only, 7-day invite codes, per-Show sharing, Encores, block and report.
- Backstage Pass: optional Google or Apple sign-in, sync, delete account.
- Apple Health import on iPhone.

Constraints:

- Rules-based plan, no AI (brief).
- Not medical advice; a short disclaimer is always shown with the plan (brief).
- miles, mph, °F only (brief). No metric units.
- Marathon only. No other race distances are planned for.
- Dark only.
- It is a log, not a recorder: no GPS, no GPX import, no heart rate.
- Without an account, data lives only in that browser or phone; clearing site data
  erases it.
- No ads, no analytics or tracking tools (`web/privacy.html`).

Terminology (binding, from Ryan's request): Show, Setlist, Studio Session, Live Show,
Track, Saved Mix, Song of the Show, The Tour, Rehearsals, On the Road, Headline Leg,
Soundcheck, Rest Stop, Headliner, Opening Night, Gold Records, The Record Wall, Gear,
The Crew, Backstage. Also in the app: The Charts, Backstage Pass, Encore, Tour Manager,
Book a Show, Book The Tour.

Undecided: App Store release date; whether the front page lives at `/` and where the
app then opens; any pricing beyond "free to use"; a contact route other than GitHub
issues.

## Brand Commitments

- Name: Setlist Tracker. App Store subtitle draft: "Marathon training, on tour".
- The tour vocabulary above, unchanged.
- Concert-poster / tour-merch feel, bold type, dark by default (brief).
- Brand colors and type as recorded in `DESIGN.md`; Archivo and Archivo Condensed were
  chosen by Ryan on 2026-11-22.
- No emoji (Ryan has said he dislikes them). He has also asked to move away from
  gradient washes toward sample images.
- Voice **(assumption, read from the app's own copy)**: plain, short, second person,
  a little wry, never hype. Examples already in the product: "Every run is a Show.",
  "Enjoy the show.", "The wall is bare".
- Writing rules in force for this project: no em-dashes in copy; sentence case for body.
- Made by one person, Ryan, with Claude. Nothing else about the maker is on record,
  and nothing may be invented.

## Evidence on Hand

Real, usable today:

- The running app itself (screenshots can be taken from a local web build).
- The plan rules and their tests: `lib/logic/tour_builder.dart`,
  `test/tour_builder_test.dart`.
- The published privacy and support pages: `web/privacy.html`, `web/support.html`.
- The App Store listing draft: `docs/app-store-listing.md`.
- The app icon and its generator: `web/icons/`, `tool/app_icon.py`.
- Fonts under the SIL Open Font License: `assets/fonts/`.

Absent, and not to be fabricated:

- Testimonials, reviews, ratings, user or download counts, press.
- Photos of people, of Ryan, of races, of treadmills.
- A maker biography or origin story.
- Results or outcomes (finish times, injury rates, qualifiers).
- An App Store listing, badge or link.

## Product Principles

1. The metaphor has to carry real training meaning. A tour word is only used where it
   maps to one thing a runner already knows.
2. Show the rules. The plan earns trust by being readable, with real numbers, not by
   sounding clever.
3. The runner decides. Suggestions wait for Apply; sharing is per Show; sign-in is
   optional; deleting everything is one menu away.
4. Say only what is true of the shipped app. No borrowed proof.
5. The phone in a sweaty hand comes first. **(assumption: follows from "works well on
   mobile" and the logging loop)**

## Accessibility & Inclusion

- Ryan's request sets WCAG AA contrast, visible focus states, readable sizes
  (body 16px or more on the web page), reduced-motion support, and layouts from 360px
  to 1600px and wider.
- The app has already had an accessibility pass (spoken labels for numbers, an 11pt
  floor, layouts that hold at large text sizes: commits 90a369b and 0b76019).
- Color is never the only signal: Studio and Live are always labelled in words.
  **(assumption: stated as a rule here because the app already behaves this way)**
