# App Store listing: what to paste into App Store Connect

Everything here is ready to copy into **App Store Connect → Apps → Setlist
Tracker**. Character limits are in brackets. The site is
`https://setlisttracker.com`.

**Status (Nov 21, 2026):** App Information, Pricing, Age Rating and the App
Privacy answers are filled in. Still to do: **Publish** on App Privacy, the
version page below, screenshots, review notes, and a TestFlight build.
Shout-outs and Seen by changed two answers since then: add **Usage Data →
Product Interaction** on App Privacy, and switch **Messaging and chat** to
Yes on Age Rating.
Push notifications (build 5, version 1.0) change no App Privacy answer and
no Age Rating answer; the review notes below mention them.

## App Information

- **Name** [30]: `Setlist Tracker`
- **Subtitle** [30]: `Marathon training, on tour`
- **Category**: Health & Fitness (secondary: Music)
- **Privacy Policy URL**: `https://setlisttracker.com/privacy.html`
- **Content rights**: choose **Yes, it contains, shows, or accesses
  third-party content**, and tick that you have the rights. The app shows
  song titles and album art from Apple's and Spotify's catalogs through
  their public search APIs, as their terms allow, and links back to them.
  (This was set to "No" at first. Change it before you submit.)

## Pricing and Availability

Free, in all countries.

## Version page

**Promotional text** [170]:

> Every run is a Show and race day is Opening Night. Build your Tour, log your
> Setlist, press Gold Records, and cheer your Crew all the way to the start line.

**Description** [4000]:

> Setlist Tracker turns marathon training into a music tour.
>
> Every run is a Show. Treadmill runs are Studio Sessions, outdoor runs are
> Live Shows, and race day is Opening Night.
>
> LOG EVERY SHOW
> • Distance, time and pace (worked out for you), effort and how it felt
> • Studio Sessions: build your treadmill Tracks (speed in mph, incline) and
>   save favorite setups as Saved Mixes you can load in one tap
> • Live Shows: route, surface, elevation and weather
> • Track the miles on every pair of shoes (your Gear)
> • Go Live: record outdoor runs with GPS, route, splits and pace in mph
> • Import runs from Apple Health, save Shows back to it, see heart rate
>
> SONG OF THE SHOW
> • Pick the song that carried each run, with album art and a preview,
>   from Apple Music
> • Save the exact moment of the song that hit, like "mile 9 second wind"
> • See every song on The Record Wall, with your top artists, and export
>   them as a playlist
>
> BOOK YOUR TOUR
> • Answer a few questions and get a plan for a 5K, 10K, half or full
>   marathon: Rehearsals, On the Road, the Headline Leg and Soundcheck
> • Paces from your recent race time, Rest Stop weeks, and Headliners that
>   build week by week
> • See every Show and Tour day on The Calendar
> • Studio Session days come with ready-made treadmill settings
> • Missed a Show? It's rescheduled across the week, not piled onto
>   tomorrow
>
> THE CHARTS AND GOLD RECORDS
> • Weekly mileage, Headliner progression, streaks and the countdown to
>   Opening Night
> • Gold Records for your longest Show, fastest 5K, 10K, half and more
>
> THE CREW
> • Invite running friends with a link or code. Nobody can find you unless
>   you invite them.
> • Your Crew sees the Shows you log and your Tour. Cheer theirs with an
>   Encore or a Shout-out, and keep any Show to yourself with "Keep off
>   the Crew"
> • See who gave your Shows an Encore, and which Crew mates saw them
> • Training for the same race? Book a Tour featuring a friend
> • Block and report are always one tap away
>
> BACKSTAGE PASS
> • Sign in with Apple or Google to sync your Setlist across iPhone and the
>   web. Or skip it: everything works on your phone without an account.
>
> Setlist Tracker gives general training guidance, not medical advice. If
> you're injured or unsure, check with a doctor or coach.

**Keywords** [100, comma separated, no spaces needed]:

```
marathon,running,training plan,run log,treadmill,half marathon,playlist,music,race,pace,10k,5k
```

**Support URL**: `https://setlisttracker.com/support.html`

**License Agreement** (App Information): keep Apple's standard EULA. The
app's own terms and Crew rules are at `https://setlisttracker.com/terms.html`
and point to it.
**Marketing URL** (optional): `https://setlisttracker.com`

**Copyright**: `2026 Ryan Cheng`

## Screenshots

Upload the 6.9-inch iPhone set (1320 × 2868), in the numbered order. App
Store Connect scales them down for smaller iPhones. The app is iPhone only
(no iPad screenshots needed).

The build 3 set is in the project files at `build3/app-store/`
(`01-setlist` to `08-go-live`), shot from the flat-colors app on main so it
matches the app (Guideline 2.3.3). Retake it if the screens change again.
Tooling: `build2/tooling/` (440 × 956 at 3x).

## Age Rating questionnaire

Answer **None** or **No** to every content question (violence, sexual
content, gambling, alcohol, medical treatment and so on), except these:

- **User-generated content**: Yes. Friends share run summaries, stage
  names and profile photos with each other, invite-only, with block and
  report. Joining a Crew means agreeing to the Crew rules
  (`https://setlisttracker.com/terms.html`).
- **Messaging and chat**: Yes. Shout-outs are short free-text comments
  (up to 280 characters) on a Show, seen only by the Show's owner and their
  Crew. There's no private messaging. Every Shout-out can be reported, the
  writer and the Show's owner can delete it, and blocking someone hides
  their Shout-outs both ways.
- **Health or wellness topics**: Yes (fitness training), with no medical
  treatment advice.
- **Unrestricted web access**: No.

Use the rating App Store Connect works out from these answers.

## App Privacy ("nutrition label")

**Do you or your third-party partners collect data from this app?** Yes.

For every type below:

- Linked to the user: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality** only

| Category | Data type | Why |
| --- | --- | --- |
| Contact Info | Name | Backstage Pass (from Google or Apple sign-in) |
| Contact Info | Email Address | Backstage Pass |
| Health & Fitness | Fitness | Shows, Tours and Gear you log and sync |
| Health & Fitness | Health | runs imported from Apple Health, stored as Shows (heart rate is read on the phone only and not collected) |
| Location | Precise Location | the GPS route of a Show recorded with Go Live, synced with the Show |
| User Content | Other User Content | stage name, Shows and Tour your Crew sees, Shout-outs (comments on a Show, seen by its owner's Crew), reports |
| User Content | Photos or Videos | profile photo, if you upload one (only your Crew sees it) |
| Usage Data | Product Interaction | Seen by: which Crew mates' Shows you've seen, shown only to each Show's owner (Settings → The Crew turns it off and forgets past views) |
| Identifiers | User ID | account id |

Not collected: coarse location, location outside a Go Live run, contacts, browsing or search history (song
searches aren't stored), other usage data (no analytics), diagnostics, purchases.

Push notifications add no data type. The app keeps the APNs device token iOS
gives it, linked to the account, only to send Crew notifications; Apple's
list of data types has no entry for it (it isn't a User ID or Device ID in
Apple's sense, and it isn't used for tracking). `PrivacyInfo.xcprivacy`
stays as it is.

## App Review notes

Paste this into **App Review Information → Notes**, and tick **Sign-in
required: No**. Everything except syncing and The Crew works without an
account.

> Setlist Tracker is a marathon training log with a music-tour theme: a run
> is a "Show", the training plan is "The Tour", friends are "The Crew".
>
> Sign-in is optional. To test the account features, tap Backstage (last
> tab) → Sign in with Apple (any Apple ID works) or Continue with Google.
>
> Account deletion: Backstage → Backstage Pass → ⋮ → Delete account. This
> deletes all data on our server and revokes Sign in with Apple.
>
> The Crew (friend sharing) is invite-only: The Crew tab → Invite a friend
> makes a code. To see another runner's Shows, sign in, pick a stage
> name, then The Crew → Enter a code → TRYCREW2. That joins our demo
> runner "Review Crew", which has three Shows and a Shout-out. The code
> doesn't expire. Every shared Show has ⋯ → Report this Show / Block, and a friend's
> profile photo has Report photo. Joining The Crew means agreeing to the
> Crew rules (https://setlisttracker.com/terms.html), which have zero
> tolerance for objectionable content. Each report alerts the developer,
> who reviews it within 24 hours and removes the content and the account.
>
> Shout-outs are short comments (up to 280 characters) on a Show, seen
> only by the Show's owner and their Crew. The server filters slurs and
> profanity out of Shout-outs and stage names before anyone sees them. Tap Shout-out under a Show to
> open them, and long-press one for Report or Delete. Each report alerts
> the developer, who reviews it within 24 hours, and the reported
> Shout-out leaves the reporter's view right away. The writer or the
> Show's owner can delete a Shout-out, and blocking someone (offered in
> the report sheet, or from their Crew card) hides their Shout-outs both
> ways. "Seen by" on your own Shows lists Crew mates who saw them; only
> the Show's owner sees it, and Settings → The Crew → "Let my Crew know
> when I've seen their Shows" turns it off.
>
> Apple Health: Backstage → Apple Health → Import runs reads running
> workouts on request. Shows you book are saved to Health as running
> workouts (with the GPS route for Go Live runs); Settings → Apple Health
> turns this off. A Show's page reads heart rate for that run; it stays on
> the device and is never sent to our server or shown to friends.
>
> Background location: the Setlist tab → Go Live records an outdoor run
> with GPS. Location is used only between Go Live and End Show, and keeps
> running with the screen locked so the route and distance are complete
> (the app asks for "While Using" only; iOS shows the blue location
> indicator). There is no location use outside a run you started.
>
> Notifications (opt-in): the app asks for permission the first time you
> open The Crew tab, never at launch. It notifies you when a Crew mate logs
> a new Show and when someone gives a Shout-out on your Show; Settings →
> The Crew has a switch for each. There are no marketing or promotional
> notifications.

`TRYCREW2` is a permanent invite to the demo runner "Review Crew", seeded
by backend migration 0006 (three Shows and a Shout-out; nobody can sign in
as it). Joining links you to Review Crew only, not to other people who
used the code.
