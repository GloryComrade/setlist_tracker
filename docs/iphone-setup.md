# Putting Setlist Tracker on your iPhone

This guide goes click by click. Part 1 works with a **free Apple ID** and puts
the app on your own phone. Part 2 is for later, after you join the paid
**Apple Developer Program** ($99 a year), and covers Sign in with Apple and
TestFlight.

What the iPhone app already has: the name "Setlist Tracker" under its icon,
the ticket icon, a black launch screen, portrait only, and the dark status
bar. Its bundle ID (Apple's name for the app) is
`com.glorycomrade.setlisttracker`.

You need:

- Your Mac with Xcode 27 and Flutter 3.50 (`flutter --version` shows it).
- Your iPhone (iOS 16 or newer) and its USB cable.
- The site address, `https://setlisttracker.com` (SITE in
  [cloudflare-setup.md](cloudflare-setup.md)). Without it the app still
  runs, but only on this phone, with no sign-in or Crew.

---

## Part 1: run it on your phone (free Apple ID)

### 1. Get the newest code

1. Open **Terminal** (press Cmd+Space, type `Terminal`, press Return).
2. Type these lines, pressing Return after each:

   ```
   cd ~/Downloads/setlist_tracker
   git pull
   flutter pub get
   ```

   `flutter pub get` downloads the add-ons the app uses. It ends with
   "Got dependencies!" or "Changed N dependencies!".

### 2. Add your Apple ID to Xcode (only once)

1. Open **Xcode**. In the menu bar: **Xcode → Settings… → Accounts**.
2. Click **+** at the bottom left, choose **Apple ID**, and sign in.
3. You now see a team named "Your Name (Personal Team)". Close the window.

### 3. Open the project and pick your team

1. Back in Terminal:

   ```
   open ios/Runner.xcworkspace
   ```

   (Open the `.xcworkspace`, not the `.xcodeproj`.)
2. In Xcode's left sidebar, click the blue **Runner** icon at the very top.
3. In the middle, under **TARGETS**, click **Runner**, then the
   **Signing & Capabilities** tab at the top.
4. Make sure **Automatically manage signing** is ticked.
5. **Team**: choose your team ("Your Name (Personal Team)").

### 4. Remove Sign in with Apple (free Apple IDs only)

A free Apple ID can't use Sign in with Apple, so Xcode shows a red error
("Personal development teams ... do not support the Sign in with Apple
capability"). Until you join the paid program:

1. On the same **Signing & Capabilities** tab, find the **Sign in with
   Apple** box.
2. Hover over it and click the small **trash can** (or **×**) on its right.
   The red error goes away.

This only changes `ios/Runner/Runner.entitlements` on your Mac. Don't commit
that change. Before your next `git pull`, put the file back with:

```
git checkout ios/Runner/Runner.entitlements
```

then remove the capability again after pulling. Leave `APPLE_SIGN_IN` off
(the default), so the app shows only **Continue with Google**.

If Xcode says the bundle ID **is not available**, someone else has already
registered it. Change **Bundle Identifier** (on the **General** tab) to
something like `com.yourname.setlisttracker` and try again. Sign-in still
works, because it returns to the app through a separate link
(`com.glorycomrade.setlisttracker://login-callback`).

You can quit Xcode now (Cmd+Q). It remembers the team.

### 5. Get the phone ready

1. Plug the iPhone into the Mac. Unlock it and tap **Trust** if it asks
   about trusting this computer (type your passcode).
2. Turn on **Developer Mode** (iOS 16 and newer): on the iPhone, open
   **Settings → Privacy & Security**, scroll to the bottom, tap
   **Developer Mode** and switch it on. The phone restarts. After the
   restart, tap **Turn On** and type your passcode.

   If you don't see Developer Mode, open Xcode once with the phone plugged
   in (**Window → Devices and Simulators**), wait for the phone to show up,
   and look again.

### 6. Build and install

In Terminal (still in `~/Downloads/setlist_tracker`), paste this as one
command:

```
flutter run --release \
  --dart-define=API_URL=https://setlisttracker.com \
  --dart-define=APPLE_SIGN_IN=true
```

(Leave out the last line on a free Apple ID: Sign in with Apple needs the
paid team.)

- If Flutter asks which device to use, type the number next to your iPhone.
- The first build takes a few minutes. Your Mac may ask for your login
  password so Xcode can sign the app. Type it and click **Always Allow**.
- `--release` makes the app fast and lets it keep working after you unplug
  the phone.

### 7. Trust yourself as a developer (first install only)

The first time, the app installs but won't open ("Untrusted Developer").
On the iPhone:

1. **Settings → General → VPN & Device Management**.
2. Under **Developer App**, tap your Apple ID, then
   **Trust "Apple Development: …"**, then **Trust**.
3. Open **Setlist Tracker** from the home screen.

Then run the `flutter run` command from step 6 again, or just tap the icon.

### What to expect with a free Apple ID

- The app **stops opening after 7 days**. Plug in and run step 6 again to
  renew it. Your Shows stay on the phone (and in the cloud if you're signed
  in).
- **Continue with Google** opens a secure Safari sheet inside the app. After
  you sign in it closes by itself and you're back in Backstage with your
  Backstage Pass. It uses the same Google setup as the website, so there's
  no separate iOS client ID in Google Cloud.

---

## Part 2: after joining the Apple Developer Program

Join at https://developer.apple.com/programs/ (it can take a day or two to
be approved). Then in Xcode, **Settings → Accounts**, your Apple ID now
shows a team without "(Personal Team)". Pick that team in
**Signing & Capabilities** (Part 1, step 3).

If you removed Sign in with Apple in Part 1, put it back:

```
git checkout ios/Runner/Runner.entitlements
```

(or in **Signing & Capabilities** click **+ Capability** and double-click
**Sign in with Apple**).

### A. Register the app with Apple

1. Go to https://developer.apple.com/account → **Certificates, Identifiers
   & Profiles → Identifiers**.
2. If `com.glorycomrade.setlisttracker` is already listed (Xcode may have
   made it), click it. Otherwise click **+**, choose **App IDs → App →
   Continue**, Description `Setlist Tracker`, **Explicit** Bundle ID
   `com.glorycomrade.setlisttracker`.
3. Under **Capabilities**, tick **Sign In with Apple** (keep "Enable as a
   primary App ID"). Click **Save** (or **Continue → Register**).
4. Note your **Team ID**: it's the 10-character code at the top right of
   the developer site, next to your name.

### B. Services ID, signing key and Cloudflare secrets

Follow [cloudflare-setup.md](cloudflare-setup.md), Part 5, steps 4 to 7.
It makes the Services ID (for Apple sign-in on the website) and the signing
key, and puts the key into Cloudflare. The backend uses the same key for the
iPhone's native sign-in sheet and to revoke Apple sign-in when someone
deletes their account.

### E. Switch the Apple button on

- iPhone builds: add `--dart-define=APPLE_SIGN_IN=true` to the `flutter run`
  and `flutter build ipa` commands.
- Website: in GitHub, **Settings → Secrets and variables → Actions →
  Variables**, add `APPLE_SIGN_IN` with the value `true`, then re-run
  **Deploy to Cloudflare**.

On the iPhone, **Sign in with Apple** now opens Apple's own sheet (Face ID).
On the website it goes through Apple's sign-in page.

Apple's App Store rules say an app that offers Google sign-in must also
offer Sign in with Apple, so turn it on before sending the app for review.

### F. TestFlight (install without a cable, no 7-day limit)

1. **The app in App Store Connect** already exists ("Setlist Tracker",
   SKU `setlisttracker`). If you ever need to make it again: **Apps → + →
   New App**, Platform **iOS**, primary language English (U.S.), Bundle ID
   `com.glorycomrade.setlisttracker`.
2. **Build the upload** in Terminal:

   ```
   cd ~/Downloads/setlist_tracker
   git pull
   flutter pub get
   flutter build ipa --release \
     --dart-define=API_URL=https://setlisttracker.com \
     --dart-define=APPLE_SIGN_IN=true
   ```

   Each upload needs a higher build number. The number after `+` in
   `pubspec.yaml` (`version: 1.0.0+1`) is the build number. Raise it, or add
   `--build-number=2` (then 3, 4, ...) to the command.
3. **Upload**: in Terminal run

   ```
   open build/ios/archive/Runner.xcarchive
   ```

   Xcode's **Organizer** opens with the build selected. Click
   **Distribute App → App Store Connect → Distribute** and accept the
   defaults.

   If you prefer Xcode's own menu: run the `flutter build ipa` command
   first (it saves your `--dart-define` values for Xcode), then in Xcode
   pick **Any iOS Device (arm64)** as the destination and choose
   **Product → Archive**. The Organizer opens when it's done.
4. After 10 to 30 minutes the build shows up in App Store Connect under
   **TestFlight**. The export compliance question is already answered in
   the app (it only uses standard HTTPS).
5. Under **TestFlight → Internal Testing**, click **+**, make a group, add
   yourself, and add the build. Install the **TestFlight** app on your
   iPhone and accept the invitation. TestFlight builds work for 90 days.

### Before sending it to the App Store

Everything Apple asks for is ready, and
[app-store-listing.md](app-store-listing.md) has the text to paste in:

- **Account deletion**: Backstage → Backstage Pass → ⋮ → Delete account.
  It removes the account and everything in it (Shows, Tours, Gear, Saved
  Mixes, The Crew), and revokes Sign in with Apple.
- **Privacy policy URL**: `https://setlisttracker.com/privacy.html`.
  **Support URL**: `https://setlisttracker.com/support.html`.
- **The App Privacy answers** and **review notes** are in the listing file.
- **Blocking and reporting** in The Crew (Apple asks for this in apps where
  people share with each other).

---

## If something goes wrong

- **"No profiles for 'com.glorycomrade.setlisttracker' were found"**: open
  `ios/Runner.xcworkspace` and choose your Team again (Part 1, step 3).
- **Sign-in shows an error and doesn't finish**: check that the build
  passed `--dart-define=API_URL=...` with your site address, and that the
  Google (or Apple) secrets are set in Cloudflare
  ([cloudflare-setup.md](cloudflare-setup.md)).
- **"Sign in with Apple capability" error**: you're on a free team. See Part
  1, step 4.
- **The phone isn't listed by `flutter run`**: unlock it, check the cable,
  and make sure Developer Mode is on. `flutter devices` lists what Flutter
  can see.
- **Build errors after a `git pull`**: run `flutter clean`, then
  `flutter pub get`, and try again.
