# Push notifications: setting up Apple's side

From build 5 (version 1.1), the iPhone app can send two notifications:

- **A Crew mate logs a Show**: "Maya just played a Show", "Tempo · 6.2 mi".
- **A Shout-out on your Show**: "Sam gave you a Shout-out", then the
  Shout-out itself (cut at 120 characters).

Each one has its own switch in **Settings → The Crew**. There's no web push
and no Firebase: the Worker talks to Apple's push service (APNs) directly.

Until the three secrets below are in Cloudflare, nothing is sent and nothing
breaks. The app still asks for permission and saves the phone's token, so
notifications start working as soon as the secrets go in, with no new build.

You need the paid Apple Developer Program (a free Personal Team can't use
push).

## 1. Make the APNs key (about 5 minutes)

1. Go to https://developer.apple.com/account → **Certificates, Identifiers
   & Profiles → Keys → +**.
2. Name it `Setlist Tracker Push`.
3. Tick **Apple Push Notifications service (APNs)** and click
   **Configure**:
   - **Environment**: **Sandbox & Production**. One key then works for
     builds from Xcode (sandbox) and for TestFlight and the App Store
     (production).
   - **Key restriction**: **Team Scoped (All Topics)**.
   - **Save**.
4. **Continue → Register → Download**. You get a file like
   `AuthKey_ABC123DEFG.p8`. Apple lets you download it **once**, so put it
   in your password manager right away.
5. Note the **Key ID**: the 10 characters in the file name (also shown on
   the key's page).
6. Note your **Team ID**: **Membership details** on the developer site
   (also the 10-character code at the top right, next to your name). It's
   the same Team ID as `APPLE_TEAM_ID` for Sign in with Apple.

This is a separate key from the Sign in with Apple one. Keep both.

## 2. Put the key into Cloudflare

In Terminal, from the repository:

```
cd backend
npx wrangler secret put APNS_KEY < ~/Downloads/AuthKey_ABC123DEFG.p8
npx wrangler secret put APNS_KEY_ID
npx wrangler secret put APNS_TEAM_ID
```

The first command reads the whole `.p8` file, BEGIN and END lines
included. The other two ask you to paste the value.

Or in the dashboard: **Workers & Pages → setlist-tracker → Settings →
Variables and Secrets → Add**, type **Secret**, and paste the `.p8` text
(open it in TextEdit) as `APNS_KEY`.

| Secret | Value |
| --- | --- |
| `APNS_KEY` | the whole text of the `.p8` file |
| `APNS_KEY_ID` | the key's 10-character Key ID |
| `APNS_TEAM_ID` | your 10-character Team ID |

Secrets take effect right away; no redeploy is needed.

## 3. Check the App ID has Push Notifications

1. **Certificates, Identifiers & Profiles → Identifiers →
   com.glorycomrade.setlisttracker**.
2. **Push Notifications** should be ticked. If it isn't, tick it and
   **Save**. (Skip the certificate buttons next to it; the key from step 1
   replaces certificates.)

Usually Xcode does this for you: the app's `Runner.entitlements` now has
`aps-environment`, and automatic signing turns the capability on the first
time you build with your team. If Xcode shows a signing error about Push
Notifications, open **Signing & Capabilities** once and let it fix the
profile.

The entitlement says `development`. Archiving for TestFlight or the App
Store switches it to `production` by itself, so don't change it.

## 4. Try it on a TestFlight build

1. Build and upload build 5 as in [iphone-setup.md](iphone-setup.md),
   part F.
2. On your iPhone, sign in, pick a stage name, and open **The Crew** tab.
   The app asks once whether it may send notifications. Say **Allow**.
3. From a second account in your Crew (another phone, or the website),
   log a Show dated now. Your iPhone should buzz with "<name> just played a
   Show". Tap it and the app opens on The Crew.
4. Give a Shout-out on one of your Shows from the other account. You get
   "<name> gave you a Shout-out".

Things that are on purpose:

- Only a **new** Show dated in the last 12 hours sends a push. Editing a
  Show, logging an old one, or a Show kept off the Crew sends nothing.
- At most one Show notification an hour per Crew mate.
- No push for your own Shout-outs, or from someone you've blocked (or who
  blocked you).
- If the iPhone said **Don't Allow**, Settings → The Crew shows a line
  pointing to iOS Settings, with a button that opens it.

## If nothing arrives

- **Secrets**: all three must be set, with no extra spaces. Check
  **Variables and Secrets** in Cloudflare.
- **Logs**: look for APNs errors in **Workers & Pages → setlist-tracker →
  Logs**. `403 InvalidProviderToken` means the Key ID, Team ID or key text
  is wrong. `400 BadDeviceToken` from an Xcode build means the key isn't
  enabled for Sandbox (step 1.3).
- **The switches**: Settings → The Crew → both on.
- **iOS**: Settings → Notifications → Setlist Tracker → Allow
  Notifications on.
- A phone signed out of the app stops getting notifications; that's on
  purpose too.
