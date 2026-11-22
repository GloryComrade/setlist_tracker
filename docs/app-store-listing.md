# App Store listing: what to paste into App Store Connect

Everything here is ready to copy into **App Store Connect → Apps → Setlist
Tracker**. Character limits are in brackets. The site is
`https://setlisttracker.com`.

**Status (Nov 21, 2026):** App Information, Pricing, Age Rating and the App
Privacy answers are filled in. Still to do: **Publish** on App Privacy, the
version page below, screenshots, review notes, and a TestFlight build.

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
> • Import runs from Apple Health
>
> SONG OF THE SHOW
> • Pick the song that carried each run, with album art, from Spotify or
>   Apple Music
> • Save the exact moment of the song that hit, like "mile 9 second wind"
> • See every song on The Record Wall, with your top artists, and export
>   them as a playlist
>
> BOOK YOUR TOUR
> • Answer a few questions and get a 16 to 20 week marathon plan: Rehearsals,
>   On the Road, the Headline Leg and Soundcheck
> • Paces from your recent race time, Rest Stop weeks, and Headliners that
>   build to 20 miles
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
> • Share the Shows you choose and cheer theirs with an Encore
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
**Marketing URL** (optional): `https://setlisttracker.com`

**Copyright**: `2026 Ryan Cheng`

## Screenshots

Upload the 6.9-inch iPhone set (1320 × 2868) from
`/mnt/project-files/phase6/app-store/` in the project files, in the numbered
order. App Store Connect scales them down for smaller iPhones.

## Age Rating questionnaire

Answer **None** or **No** to every content question (violence, sexual
content, gambling, alcohol, medical treatment and so on), except these:

- **User-generated content**: Yes. Friends share run summaries with each
  other, invite-only, with block and report.
- **Messaging and chat**: No. There's no free-text chat; shared notes
  appear only on a friend's own Show.
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
| Health & Fitness | Health | runs imported from Apple Health, stored as Shows |
| User Content | Other User Content | stage name, Shows you share with your Crew, reports |
| Identifiers | User ID | account id |

Not collected: location, contacts, browsing or search history (song
searches aren't stored), usage data, diagnostics, purchases.

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
> makes a code. To see a shared Show from another runner, use invite code
> DEMO-CODE (from our test account "Review Crew"), via The Crew → Enter a
> code. Every shared Show has ⋯ → Report this Show / Block. Reports go to
> the developer, who reviews them within 24 hours.
>
> Apple Health: Backstage → Apple Health → Import runs. The app reads
> running workouts only, on request, and never writes to Health.

Before submitting, sign in on https://setlisttracker.com with a second account, pick the
stage name "Review Crew", share a Show or two, make an invite (The Crew →
Invite a friend), and put its code in place of `DEMO-CODE`. Invites last 7
days, so make a fresh one right before you submit.
