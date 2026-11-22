# The Cloudflare backend: how the app and the Worker talk

Everything runs as **one Cloudflare Worker** (`backend/`):

- It serves the website (the Flutter web build, as static assets) and the
  API under `/api/*` from the same address, so the website needs no CORS and
  no separate API URL.
- Data lives in one **D1** database (SQLite), binding name `DB`.
- Sign-in (Google, Apple), syncing, The Crew, Spotify search and account
  deletion are all routes in this Worker. There is no Supabase anymore.

This file is the contract between `backend/` and the app (`lib/`). Change
both sides together.

## Configuration

`backend/wrangler.toml` (committed, no secrets):

- `name = "setlist-tracker"`, `main = "src/index.ts"`,
  `compatibility_date = "2026-11-01"`, `compatibility_flags = ["nodejs_compat"]`
- `[assets] directory = "../build/web"`, `binding = "ASSETS"`,
  `run_worker_first = ["/api/*"]`, `not_found_handling = "single-page-application"`
- `[[d1_databases]] binding = "DB"`, `database_name = "setlist-tracker"`,
  `database_id = "REPLACE_WITH_D1_DATABASE_ID"`, `migrations_dir = "migrations"`
  (the deploy workflow swaps the placeholder for the `D1_DATABASE_ID`
  repository variable).
- `[vars]` `APPLE_BUNDLE_ID = "com.glorycomrade.setlisttracker"`,
  `APPLE_SERVICES_ID = "com.glorycomrade.setlisttracker.web"`,
  `NATIVE_REDIRECT = "com.glorycomrade.setlisttracker://login-callback"`

Secrets (`wrangler secret put NAME`, or Cloudflare dashboard → Worker →
Settings → Variables and Secrets). Each feature turns itself off with a
clear error when its secrets are missing:

| Secret | Used for |
| --- | --- |
| `SESSION_SECRET` | signing access tokens (any long random string) |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Continue with Google |
| `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (the .p8 text) | Sign in with Apple, and revoking it on Delete account |
| `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` | song search |

## Conventions

- JSON in and out, `Content-Type: application/json`. Times are ISO 8601 UTC
  strings with milliseconds (`2026-11-22T03:04:05.678Z`).
- Signed-in calls send `Authorization: Bearer <accessToken>`.
- Errors: HTTP status plus `{"error": "<code>", "message": "<words for a runner>"}`.
  Codes: `not_signed_in` (401), `bad_request` (400), `not_found` (404),
  `need_stage_name` (409), `invite_invalid` (404), `own_invite` (409),
  `too_many_tries` (429), `cant_block` (400), `not_configured` (503, a
  secret is missing), `upstream` (502), `server_error` (500, anything
  unexpected).
- CORS: the API answers `OPTIONS` and sets `Access-Control-Allow-Origin` only
  for `http://localhost:*` and `http://127.0.0.1:*` (local Flutter dev
  against `wrangler dev`). The deployed website is same-origin.

## Sign-in

Access tokens are HS256 JWTs signed with `SESSION_SECRET`:
`{"sub": userId, "iat", "exp": iat + 3600}`. Refresh tokens are 32 random
bytes (base64url). Only their SHA-256 is stored. They last 60 days, and each
refresh swaps the old token for a new one.

Every successful sign-in ends with this **session** object:

```json
{"accessToken": "...", "refreshToken": "...", "expiresAt": "2026-...Z",
 "user": {"id": "uuid", "name": "Ryan Cheng" | null, "email": "..." | null}}
```

### Browser flow (Google on web and iPhone, Apple on web)

1. The app opens `GET /api/auth/{google|apple}/start?return=<url>`.
   `return` must be one of:
   - the Worker's own origin (any path),
   - `http://localhost:<port>/...` or `http://127.0.0.1:<port>/...`,
   - exactly `NATIVE_REDIRECT`.

   Anything else gets a 400. The Worker stores
   `{state, PKCE verifier, return, provider}` for 10 minutes and redirects to
   Google (`openid email profile`, with PKCE) or to Apple
   (`response_mode=form_post`, `scope=name email`).
2. Google comes back to `GET /api/auth/google/callback`, and Apple to
   `POST /api/auth/apple/callback` (form). The Worker exchanges the code,
   verifies the ID token (issuer, audience, expiry, signature against the
   provider's JWKS), finds or creates the user, then makes a **one-time login
   code** (random, 60 seconds, single use).
3. It redirects to `return` with `login_code=<code>` added to the query
   (before any `#`). On error it adds `login_error=<code>` instead.
4. The app calls `POST /api/auth/exchange {"code"}` and gets the **session**.
   On the web, the app then strips `login_code` from the address bar.

The iPhone opens step 1 in `ASWebAuthenticationSession` (Flutter package
`flutter_web_auth_2`) with callback scheme `com.glorycomrade.setlisttracker`,
then reads `login_code` from the URL it returns.

### Native Sign in with Apple (iPhone)

`POST /api/auth/apple/native`, with this body:

```json
{"identityToken": "...", "authorizationCode": "...", "rawNonce": "...",
 "givenName": "Ryan" | null, "familyName": "Cheng" | null}
```

The Worker verifies the token against Apple's JWKS (issuer
`https://appleid.apple.com`, audience `APPLE_BUNDLE_ID`, and
`nonce == sha256hex(rawNonce)`). It then exchanges `authorizationCode` with
Apple for a refresh token and stores it, so Delete account can revoke it.
The answer is the **session**.

Apple's client secret is an ES256 JWT that the Worker signs on demand from
`APPLE_PRIVATE_KEY`: `iss` = team ID, `sub` = the bundle ID or the Services
ID, `aud` = `https://appleid.apple.com`, and a lifetime of at most 5 minutes.
Nothing expires every 6 months.

### Session upkeep

- `POST /api/auth/refresh {"refreshToken"}` returns a new **session**, or a
  401 if the token is unknown or expired.
- `POST /api/auth/signout {"refreshToken"}` returns 204.
- `GET /api/me` returns `{"id", "name", "email"}`.
- `DELETE /api/me` returns 204. It revokes the stored Apple tokens (best
  effort) and deletes the user and every row of theirs: synced records,
  sessions, Crew profile, links, blocks, invites, posts, Encores given and
  received, and reports they made or that name them.

Users are matched on `(provider, provider subject)`. A Google account and an
Apple account are separate users, even with the same email.

## Syncing (Backstage Pass)

Tables: `shows`, `gear`, `saved_mixes`, `tours`. Anything else gets a 404.

- `POST /api/sync/{table}` with
  `{"rows": [{"id", "data": {...}, "updatedAt", "deletedAt": null|"..."}]}`
  (at most 500 rows) returns `{"ok": true}`. For each row, the Worker keeps
  the stored copy if it has a later `updatedAt`. Otherwise it writes the row
  and sets `syncedAt` to the server's clock. Rows from one request share one
  `syncedAt`.
- `GET /api/sync/{table}?since=<iso>&offset=<n>&limit=<n>` (limit at most
  500, default 500) returns `{"rows": [{"id", "data", "updatedAt",
  "deletedAt", "syncedAt"}]}`. It lists the rows with `syncedAt > since`
  (all of them when `since` is missing), ordered by `syncedAt` and then `id`.

Every row belongs to the signed-in user. Another user's rows are never
visible. A row id that already belongs to another user can't be written:
the rest of the request is still saved, and the answer is a 409 that lists
the refused ids under `rejected`. The app treats that as done, since a retry
can't succeed.

## The Crew

Being in someone's Crew means you see **all their activity**. Nothing is
shared by hand: the Crew reads the Shows, Gear and Tours the app already
syncs (Backstage Pass, the `records` table). The rules:

- You see your own Shows and profile, plus your Crew's. Anyone you blocked,
  or who blocked you, is never in your Crew.
- A Show is seen by the Crew unless it is deleted (`deleted_at`) or its
  owner marked it "Keep off the Crew" (Show JSON `crewPrivate: true`; a
  missing field means false). Your own private Shows are left out of your
  own feed too.
- A post is one synced Show, named `"<ownerId>:<showId>"`. It carries the
  whole Show JSON (effort, feel, notes, Tracks, song, everything the app
  wrote) and `gearName`, the `name` of the owner's non-deleted Gear whose id
  is the Show's `gearId` (`null` otherwise). `sharedAt` is the Show's
  `updatedAt` as synced.
- A runner's **active Tour** is their non-deleted Tour with the latest
  `setup.raceDate` that is today (UTC) or later; `null` when there is none.
  A missing `setup.raceDistance` means `marathon`.
- Two Tours are **co-headlined** when `setup.raceDate` and
  `setup.raceDistance` match. There is no server table for this: the app
  works it out from both runners' Tours. A Tour booked featuring a friend
  carries `featuring: {userId, stageName}` (informational).
- Joining needs an unexpired 8-character code from the alphabet
  `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, made with crypto randomness. Codes last
  7 days, and the same code is reused while it has more than a day left.
- Ten wrong codes in an hour gets `too_many_tries`. Wrong codes include
  codes from a blocked runner.
- Each block is its own row. Unblocking removes only your own block.
- Encores: only on a Show you can see, and never on your own. Posts return
  how many Encores a Show has and whether one is yours, never who gave them.
- A report copies the Show's data on the server and hides that Show from the
  reporter (feed and mate page).

All Crew routes need sign-in.

| Route | Body | Answer |
| --- | --- | --- |
| `GET /api/crew/profile` | | `{userId, stageName, color, allActivityPending}` or `null` |
| `PUT /api/crew/profile` | `{stageName, color, allActivity?: true}` (other fields, such as the old `alwaysShare`, are ignored) | profile |

`allActivityPending` is true for runners who were in The Crew before it showed every Show (migration 0002). Until they send `allActivity: true`, their Crew sees only the Shows they shared the old way. After that, Shows created before that moment stay hidden unless shared, and everything newer is visible.
| `POST /api/crew/invite` | | `{"code"}` (`need_stage_name` without a profile) |
| `GET /api/crew/invite/{code}` | | `{stageName, color, alreadyCrew, ownInvite}`, or 404 `invite_invalid` (counts a miss) |
| `POST /api/crew/join` | `{code}` | `{"userId"}`, or `invite_invalid` / `own_invite` / `need_stage_name` / `too_many_tries` |
| `GET /api/crew/mates` | | `{"mates": [Mate]}`: your Crew first, then the runners you blocked |
| `GET /api/crew/mates/{userId}` | | `{mate: {userId, stageName, color, since}, tour: <Tour JSON>\|null, shows: [Post]}`, or 404 `not_found` unless they're in your Crew (or it's you) |
| `DELETE /api/crew/mates/{userId}` | | 204 (leave each other's Crew) |
| `POST /api/crew/blocks` | `{userId}` | 204 (also ends the Crew link; `cant_block` for yourself or an unknown id) |
| `DELETE /api/crew/blocks/{userId}` | | 204 |
| `GET /api/crew/feed` | | `{"posts": [Post]}`: newest 60 by Show `date`, from you and your Crew, leaving out Shows you reported |
| `PUT /api/crew/posts/{postId}/encore` | | 204 (404 `not_found` if you can't see that Show) |
| `DELETE /api/crew/posts/{postId}/encore` | | 204 |
| `POST /api/crew/posts/{postId}/report` | `{reason}` (1 to 500 characters) | 204 |
| `GET /api/crew/shared` | | `{"shared": {}}` (old route, kept for older app builds) |
| `PUT /api/crew/shared/{showId}` | anything | 204, does nothing (old route) |
| `DELETE /api/crew/shared/{showId}` | | 204, does nothing (old route) |

`{postId}` is `"<ownerId>:<showId>"`; the colon may be sent as is or as `%3A`.

Profile JSON: `{userId, stageName, color}`. `stageName` is trimmed to 1 to
30 characters, and `color` is 0 to 7.

Post JSON:

```json
{
  "id": "<ownerId>:<showId>",
  "ownerId": "…", "stageName": "Maya", "color": 3,
  "showId": "…",
  "show": { "...": "the whole Show JSON as synced" },
  "gearName": "Pegasus 41",
  "sharedAt": "2026-11-21T08:00:00.000Z",
  "encores": 2, "encoredByMe": true, "mine": false
}
```

Mate JSON (`GET /api/crew/mates`), with the mate's active Tour summarized
(`null` for blocked runners):

```json
{
  "userId": "…", "stageName": "Ryan", "color": 1,
  "since": "2026-11-22T03:04:05.678Z",
  "tour": {
    "id": "…", "name": "Boston Tour", "raceDate": "2027-04-19",
    "raceDistance": "fiveK|tenK|half|marathon",
    "featuring": {"userId": "…", "stageName": "Maya"}
  },
  "blocked": false
}
```

`tour.featuring` is `null` when the Tour wasn't booked featuring anyone.
`GET /api/crew/mates/{userId}` returns the whole active Tour JSON as synced
and up to 500 of their Shows (same shape as feed posts), newest Show `date`
first. For your own id, `since` is when your account was made.

### Tour invites

Ask Crew mates onto your Tour, so they can book their own for the same
Opening Night (migration 0003, `backend/src/tour_invites.ts`).

| Route | Body | Answer |
| --- | --- | --- |
| `POST /api/crew/tour-invites` | `{tourId, to: [userId]}` (1 to 50 ids) | `{"invited": [userId]}`: who is invited now |
| `GET /api/crew/tour-invites` | | `{"invites": [TourInvite]}`, soonest Opening Night first |
| `DELETE /api/crew/tour-invites/{id}` | | 204 ("Not this time"), or 404 `not_found` unless the invite was sent to you |

- The Tour must be your own synced, non-deleted Tour (404 `not_found`
  otherwise, which the app reads as "not synced yet": it syncs and tries
  again), with Opening Night today or later (400). `need_stage_name` without
  a profile.
- Ids in `to` that aren't in your Crew, are blocked either way, or are you
  are skipped without saying why; they're just missing from `invited`.
- The race date, distance and Tour name are copied onto the invite. Sending
  again refreshes the copy; an invite the recipient dismissed stays
  dismissed.
- `GET` lists invites to you that you haven't dismissed, whose sender is
  still in your Crew and whose Tour still exists with Opening Night today or
  later (UTC). The Tour's current name, date and distance win over the copy.
  The app also hides invites for a race your active Tour already
  co-headlines.
- Deleting either account deletes the invite.

TourInvite JSON:

```json
{
  "id": "…",
  "from": {"userId": "…", "stageName": "Ryan", "color": 1},
  "tourId": "…", "tourName": "Spring 2027 Half Tour",
  "raceDate": "2027-02-20",
  "raceDistance": "fiveK|tenK|half|marathon",
  "createdAt": "2026-11-22T03:04:05.678Z"
}
```
### Profile pictures

A runner's picture is their photo, else a drawn badge, else their initial
(the app draws badges and initials). Code: `backend/src/avatars.ts`,
migration `0004_avatars.sql`.

- The profile, every Mate, `mate` on a mate's page and every Post carry
  `avatarBadge` (one of `AVATAR_BADGES`: `mic`, `vinyl`, `guitar-pick`,
  `sneaker`, `headphones`, `drumsticks`, `lightning`, `star`, `ticket`,
  `amp`, `cassette`, `setlist`, `laurel`, `medal`, `stopwatch`, `mountain`,
  `flame`, `wave`, `moon`, `sun`, `heart`, `crown`, `music-note`,
  `spotlight`) and `avatarUrl` (a path such as
  `/api/crew/avatar/{userId}?v=1795400000000`). Both are `null` when unset,
  and both are always `null` on runners you blocked.
- `PUT /api/crew/profile` takes `avatarBadge` too: a badge id, or `null` to
  clear it. Leaving the field out keeps the saved badge (older app builds).
  Anything else is `bad_request`.

| Route | Body | Answer |
|---|---|---|
| `PUT /api/crew/avatar` | the JPEG itself, `Content-Type: image/jpeg`, at most 64 KB, starting `FF D8 FF` | the profile with its new `avatarUrl`; 415 for another type, 413 when too big, 400 when it isn't a JPEG, `need_stage_name` without a profile |
| `DELETE /api/crew/avatar` | | the profile (`avatarUrl: null`) |
| `GET /api/crew/avatar/{userId}?v=…` | | the JPEG (`Cache-Control: private`), for yourself and your Crew only; anyone else, blocked either way included, gets 404 `not_found` |
| `POST /api/crew/report-avatar` | `{userId, reason}` (1 to 500 characters) | 204. Only for a Crew mate's photo; the server copies the photo (base64) into `crew_reports.post_data` with `post_id` `avatar` |

The `?v=` is the photo's save time in milliseconds, so a new photo has a new
address. The app makes the photo on the device: square, 256 px, JPEG.
Deleting the account deletes the photo.

## Spotify search

`GET /api/spotify/search?q=<text>&limit=<1..25>` returns
`{"results": [{title, artist, album, artworkUrl, spotifyUrl, durationMs}]}`.
No sign-in is needed. Without Spotify secrets it returns a 503
`not_configured`, and the app falls back to Apple's catalog.

## The app's side

- `--dart-define=API_URL=...` points the app at the backend:
  - On the web, `same-origin` means the address the page was loaded from.
    The deploy workflow builds with this.
  - iPhone builds pass the full Worker address, for example
    `https://setlist-tracker.<account>.workers.dev`.
  - Without `API_URL`, the app stays local-only, as before.
- Tokens are kept in a Sembast store on the device. The access token is
  refreshed when it's within 2 minutes of expiring, or after a 401, and the
  call is retried once.
