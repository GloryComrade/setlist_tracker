# Putting Setlist Tracker on Cloudflare

This guide covers the steps only you can do, because they happen in your
own accounts. After that, every merge to `main` publishes the website and
the backend (sign-in, syncing, The Crew, song search) to Cloudflare by
itself.

Plan on about 45 minutes. Everything here is free except the Apple
Developer Program ($99 a year), which only Part 5 needs.

**Never paste a secret** (API token, client secret, `.p8` key) into a chat,
an issue or the code. Each one goes straight into the box named below.

**Done (Nov 21, 2026):** Parts 1, 2, 5 and 6. SITE is
`https://setlisttracker.com` (the workers.dev address,
`https://setlist-tracker.ryanchengpictures.workers.dev`, works too).
Not done yet: Part 3 (Spotify), so song search uses Apple's catalog, and
Part 7 (push notifications, for build 5).

You'll fill in the address of your site as you go. It looks like
`https://setlist-tracker.YOUR-SUBDOMAIN.workers.dev`. Below, it's written
as **SITE**.

---

## Part 1: Cloudflare (about 10 minutes)

### 1. Make the account

1. Sign up at https://dash.cloudflare.com/sign-up (free plan).
2. In the left menu, open **Compute (Workers) → Workers & Pages**. The first
   time, Cloudflare asks you to pick a **workers.dev subdomain**, for example
   `ryan`. Your SITE is then `https://setlist-tracker.ryan.workers.dev`.
3. On the right side of **Workers & Pages** (or in the account home URL),
   copy your **Account ID**.

### 2. Make the database

1. **Storage & Databases → D1 SQL Database → Create**.
2. Name it `setlist-tracker` and click **Create**.
3. Copy its **Database ID** (a long id with dashes).

The deploy creates the tables itself. You never need to type SQL.

### 3. Make a deploy token

1. Click your profile icon (top right) → **Profile → API Tokens → Create
   Token**.
2. Next to **Edit Cloudflare Workers**, click **Use template**.
3. Under **Permissions**, click **+ Add more**: **Account → D1 → Edit**.
4. Under **Account Resources**, choose your account. Click **Continue to
   summary → Create Token**.
5. Copy the token. Cloudflare shows it only once.

### 4. Give GitHub the three values

Open the repository on GitHub, then **Settings → Secrets and variables →
Actions**.

- **Secrets** tab → **New repository secret**, twice:

  | Name | Value |
  | --- | --- |
  | `CLOUDFLARE_API_TOKEN` | the token from step 3 |
  | `CLOUDFLARE_ACCOUNT_ID` | the Account ID from step 1 |

- **Variables** tab → **New repository variable**:

  | Name | Value |
  | --- | --- |
  | `D1_DATABASE_ID` | the Database ID from step 2 |

### 5. First deploy

**Actions → Deploy to Cloudflare → Run workflow**. It takes about 5
minutes. When it's green, open SITE: the app is there, local-only for now.
(The old GitHub Pages copy stops updating on its own; you can turn it off
under **Settings → Pages**.)

### 6. The session secret

The backend signs your sign-ins with a secret string of your own.

1. On your Mac, open Terminal and run `openssl rand -base64 48`. Copy the
   result.
2. In Cloudflare: **Workers & Pages → setlist-tracker → Settings → Variables
   and Secrets → + Add**. Type **Secret**, name `SESSION_SECRET`, paste the
   value, and click **Deploy**.

Each secret you add this way stays through future deploys.

---

## Part 2: Continue with Google (about 15 minutes)

1. Go to https://console.cloud.google.com and create a project called
   `Setlist Tracker`.
2. **APIs & Services → OAuth consent screen** (also called **Google Auth
   Platform**). Click **Get started**:
   - App name `Setlist Tracker`, with your email as the support email.
   - Audience **External**, and your email as the contact.
   - Under **Branding**, add:
     - App home page: SITE
     - Privacy policy: `SITE/privacy.html`
     - Terms of service: you can leave this empty.
     - Authorized domain: `YOUR-SUBDOMAIN.workers.dev` (for example
       `ryan.workers.dev`), or your own domain if you added one (Part 6).
       If Google won't accept it, skip this field: basic sign-in still
       works.
3. **Clients → Create client → Web application**:
   - Name: `Setlist Tracker web`.
   - **Authorized redirect URIs → + Add URI**: `SITE/api/auth/google/callback`
   - **Create**, then copy the **Client ID** and **Client secret**.
4. In Cloudflare (Part 1, step 6, same place), add two **Secrets**:
   `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.
5. Back in Google, under **Audience**, click **Publish app**. Basic sign-in
   (name and email) doesn't need Google's review. Until you publish, only
   the accounts listed under **Test users** can sign in.

Try it: open SITE → **Backstage → Continue with Google**. You come back to
the app signed in, with the **ALL ACCESS** badge.

The iPhone uses this same Google client. There's nothing extra to set up for
it.

---

## Part 3: Song search with Spotify (about 5 minutes)

1. Go to https://developer.spotify.com/dashboard, log in, and click **Create
   app**:
   - Name `Setlist Tracker`, with a short description.
   - Redirect URI: SITE (it isn't used, but Spotify asks for one).
   - Tick **Web API**, agree to the terms, and click **Save**.
2. Open **Settings** and copy the **Client ID**. Click **View client
   secret** and copy that too.
3. In Cloudflare, add the two **Secrets** `SPOTIFY_CLIENT_ID` and
   `SPOTIFY_CLIENT_SECRET`.

Without these, song search still works with Apple's catalog.

---

## Part 4: The iPhone app talks to Cloudflare

iPhone builds need SITE passed in. Use the commands in
[iphone-setup.md](iphone-setup.md), with:

```
--dart-define=API_URL=SITE
```

For example `--dart-define=API_URL=https://setlist-tracker.ryan.workers.dev`.

---

## Part 5: Sign in with Apple (after joining the Apple Developer Program)

Apple requires Sign in with Apple in any App Store app that offers Google
sign-in, so do this before sending the app for review.

1. Join at https://developer.apple.com/programs/. Approval can take a day or
   two.
2. Go to https://developer.apple.com/account → **Certificates, Identifiers &
   Profiles**.
3. **Identifiers → +** → **App IDs → App**:
   - Description `Setlist Tracker`.
   - Explicit Bundle ID `com.glorycomrade.setlisttracker`.
   - Tick **Sign In with Apple** and **HealthKit**.
   - **Continue → Register**.
4. **Identifiers → +** → **Services IDs**:
   - Description `Setlist Tracker Web`.
   - Identifier `com.glorycomrade.setlisttracker.web`.
   - Register it, then open it.
   - Tick **Sign In with Apple → Configure**:
     - Primary App ID: the one from step 3.
     - Domains: your SITE host without `https://` (for example
       `setlist-tracker.ryan.workers.dev`).
     - Return URL: `SITE/api/auth/apple/callback`
   - **Next → Done → Continue → Save**.
5. **Keys → +**:
   - Name `Setlist Tracker Sign in with Apple`.
   - Tick **Sign in with Apple → Configure**, pick the App ID, and save.
   - **Continue → Register → Download**. You get a file like
     `AuthKey_ABC123DEFG.p8`. Keep it in your password manager; Apple
     won't let you download it again.
6. In Cloudflare, add three **Secrets**:

   | Name | Value |
   | --- | --- |
   | `APPLE_TEAM_ID` | the 10-character Team ID (top right of the developer site) |
   | `APPLE_KEY_ID` | the 10 characters in the key's file name |
   | `APPLE_PRIVATE_KEY` | the whole text of the `.p8` file (open it in TextEdit), including the BEGIN and END lines |

   The backend makes Apple's short-lived "client secret" from this key
   whenever it needs one, so nothing expires every 6 months.
7. GitHub → **Settings → Secrets and variables → Actions → Variables**: add
   `APPLE_SIGN_IN` with the value `true`. Then run **Deploy to Cloudflare**
   again. The website now shows **Sign in with Apple**.
8. iPhone builds: add `--dart-define=APPLE_SIGN_IN=true`.

When someone deletes their account, the backend also revokes their Sign in
with Apple, which App Review checks.

---

## Part 6 (optional): your own domain

If you buy a domain (Cloudflare → **Domain Registration**, about $10 to $15
a year):

1. **Workers & Pages → setlist-tracker → Settings → Domains & Routes →
   Add → Custom domain**, for example `setlisttracker.app`.
2. Update the places that name SITE:
   - Google's redirect URI and authorized domain (Part 2).
   - Apple's Services ID domain and return URL (Part 5).
   - `API_URL` in iPhone builds (Part 4).

The workers.dev address keeps working too.

---

## Part 7 (optional): push notifications on iPhone (about 10 minutes)

From build 5, the iPhone app can notify runners when a Crew mate logs a
Show or someone gives a Shout-out on their Show. It needs an APNs key from
Apple and three more **Secrets** in Cloudflare:

| Name | Value |
| --- | --- |
| `APNS_KEY` | the whole text of the push key's `.p8` file, including the BEGIN and END lines |
| `APNS_KEY_ID` | the 10-character Key ID of that key |
| `APNS_TEAM_ID` | your 10-character Team ID (the same as `APPLE_TEAM_ID`) |

The step-by-step (making the key, checking the App ID, testing on
TestFlight) is in [push-setup.md](push-setup.md). Without these secrets
nothing is sent and nothing else changes.

---

## Looking after it

- **Reports from The Crew:** Cloudflare → **D1 → setlist-tracker →
  Console**:

  ```sql
  select created_at, reason, post_data from crew_reports order by created_at desc;
  ```

- **Removing someone:** they can delete their own account in the app. To
  remove one yourself, find their id in `users` and ask me (Claude) for the
  cleanup query.
- **Logs:** **Workers & Pages → setlist-tracker → Logs**.
- **Costs:** the free plan covers 100,000 requests a day and 5 GB of D1.
  That's far more than a running app with friends needs.

## If something goes wrong

- **The deploy fails at "Update the database tables"**: check that the
  token has **D1 → Edit** and that `D1_DATABASE_ID` is right.
- **Google says "redirect_uri_mismatch"**: the redirect URI in Google must
  be exactly `SITE/api/auth/google/callback`, with no trailing slash.
- **Sign-in comes back with an error banner**: the matching secrets aren't
  set in Cloudflare yet. Check **Variables and Secrets**.
- **Song search only shows Apple Music**: the Spotify secrets are missing
  (Part 3).
- **No push notifications arrive**: see "If nothing arrives" in
  [push-setup.md](push-setup.md).
