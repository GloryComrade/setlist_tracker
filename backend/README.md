# Setlist Tracker backend

One Cloudflare Worker that serves the Flutter web build (`../build/web`) as
static assets and the API under `/api/*`: sign-in (Google, Apple), Backstage
Pass sync, The Crew, Spotify song search and Delete account. Data lives in
one D1 database. The API contract is [`docs/cloudflare-api.md`](../docs/cloudflare-api.md).

```
src/index.ts      routing, CORS, errors
src/auth.ts       access tokens, refresh tokens, login codes, return URLs
src/oauth.ts      Google and Apple (browser flow, native Apple, revoke)
src/sync.ts       /api/sync/{shows,gear,saved_mixes,tours}
src/crew.ts       /api/crew/*
src/spotify.ts    /api/spotify/search
src/account.ts    DELETE /api/me
migrations/       D1 schema
```

## Tests

```sh
npm ci
npm test          # vitest in the Workers runtime (Miniflare), local D1
npm run typecheck
```

Tests need no Cloudflare account and no web build. Google, Apple and
Spotify are mocked.

## Running locally

```sh
cat > .dev.vars <<'VARS'
SESSION_SECRET=any-long-random-string
# Optional, each turns its feature on:
# GOOGLE_CLIENT_ID=...
# GOOGLE_CLIENT_SECRET=...
# APPLE_TEAM_ID=...
# APPLE_KEY_ID=...
# APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
# SPOTIFY_CLIENT_ID=...
# SPOTIFY_CLIENT_SECRET=...
VARS
(cd .. && flutter build web)                       # wrangler needs ../build/web
npx wrangler d1 migrations apply setlist-tracker --local
npm run dev                                        # http://localhost:8787
```

Running the Flutter app on its own dev server against `wrangler dev` works
too: the API allows CORS from `http://localhost:*` and `http://127.0.0.1:*`.

## Deploying

`npm run deploy` (after `flutter build web`). Before the first deploy:
create the database (`npx wrangler d1 create setlist-tracker`), put its id
in place of `REPLACE_WITH_D1_DATABASE_ID` (the deploy workflow does this
from the `D1_DATABASE_ID` repository variable), apply the migrations with
`--remote`, and set the secrets with `npx wrangler secret put NAME`.

`.npmrc` sets `legacy-peer-deps`: npm 10 crashes resolving vitest's
optional peer dependencies otherwise.
