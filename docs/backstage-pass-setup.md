# Setting up the Backstage Pass (accounts and syncing)

The app works without any of this: with no backend settings it stays
local-only and Backstage says sign-in isn't set up. These steps turn on
Google sign-in and syncing. Allow about 20 minutes. Everything here is free.

You'll copy two values that are **safe to share**: the Project URL and the
Publishable key (it starts with `sb_publishable_`, or is the older "anon"
key). Never paste the **secret** or **service_role** key anywhere, including
chats.

## 1. Create the Supabase project

1. Sign in at https://supabase.com and click **New project**.
2. Name it `setlist-tracker`, pick a region near you (for example West US),
   set a database password (save it in your password manager), and create it.

## 2. Create the tables

1. In the project, open **SQL Editor**, then **New query**.
2. Paste all of
   [`supabase/migrations/20261122000000_backstage_pass.sql`](../supabase/migrations/20261122000000_backstage_pass.sql)
   and click **Run**. It creates the `shows`, `gear`, `saved_mixes` and
   `tours` tables, the rules that let each runner see only their own rows,
   and the "Delete account" function. Running it again is harmless.
3. **New query** again, paste all of
   [`supabase/migrations/20261123000000_the_crew.sql`](../supabase/migrations/20261123000000_the_crew.sql)
   and click **Run**. It sets up The Crew (sharing Shows with friends):
   stage names, invite codes, shared Shows, Encores, blocks and reports.
   Running it again is harmless.

Reports about shared Shows land in **Table Editor → crew_reports**. Look
there now and then; the reported Show is copied into `post_data`. To remove
someone, delete them under **Authentication → Users** (everything of theirs
goes with them).

## 3. Copy the URL and key

**Project Settings → API Keys** (or the **Connect** button at the top): copy
the **Project URL** (`https://xxxx.supabase.co`) and the **Publishable key**.

## 4. Tell Supabase where sign-in may return to

**Authentication → URL Configuration**:

- **Site URL:** `https://glorycomrade.github.io/setlist_tracker/`
- **Redirect URLs**, add all three:
  - `https://glorycomrade.github.io/setlist_tracker/`
  - `http://localhost:3000/`
  - `com.glorycomrade.setlisttracker://login-callback` (the iPhone app)

## 5. Turn on Google sign-in

1. Go to https://console.cloud.google.com, create a project called
   `Setlist Tracker`.
2. **APIs & Services → OAuth consent screen** (also called Google Auth
   Platform): choose **External**, app name `Setlist Tracker`, your email as
   support and developer contact. Save.
3. **Credentials → Create credentials → OAuth client ID → Web application**:
   - Authorized JavaScript origins: `https://glorycomrade.github.io` and
     `http://localhost:3000`
   - Authorized redirect URI: `https://YOUR-PROJECT.supabase.co/auth/v1/callback`
     (Supabase shows this exact address on its Google provider page)
4. Copy the **Client ID** and **Client secret**.
5. In Supabase, **Authentication → Sign In / Providers → Google**: turn it on,
   paste both, save. (The client secret goes only here.)

While the consent screen is in "Testing", only Google accounts you add under
**Test users** can sign in. Add yourself, or click **Publish app** when ready.

## 6. Give the test site the URL and key

GitHub → the repository → **Settings → Secrets and variables → Actions →
Variables** tab → **New repository variable**, twice:

| Name | Value |
| --- | --- |
| `SUPABASE_URL` | the Project URL |
| `SUPABASE_KEY` | the Publishable key |

Then **Actions → Deploy web app → Run workflow** (or merge anything to
`main`). The test link now shows the sign-in buttons in Backstage.

## 7. Run it on your Mac (optional)

```
flutter run -d chrome --web-port 3000 \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_KEY=sb_publishable_...
```

## Sign in with Apple (later)

Apple sign-in needs the paid Apple Developer Program ($99/yr), even on the
website. Once joined, the [iPhone guide](iphone-setup.md) (Part 2) covers it, and the button is
switched on with `--dart-define=APPLE_SIGN_IN=true` (and an `APPLE_SIGN_IN`
repository variable set to `true` for the test site).

## How syncing works

- The device keeps its own copy, so everything works offline. Each save also
  lands in a small outbox on the device.
- A sync uploads the outbox, then downloads rows changed since the last
  sync. If two devices edited the same Show, the later edit wins, on the
  device and on the server.
- It runs on sign-in, a few seconds after each change, when the app comes
  back to the foreground, with **Sync now** in Backstage, and when you pull
  down on the Setlist.
- The first sign-in uploads everything already on the device.
- Signing out uploads what's left, then clears this device. If something
  couldn't upload (offline), the app asks before signing out.
