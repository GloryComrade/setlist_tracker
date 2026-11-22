# Apple Health import

On iPhone, Backstage has an **Apple Health** card. "Import runs" brings running workouts from Apple Health (recorded by an Apple Watch, the iPhone, or any app that saves runs to Health) into the Setlist as Shows. On web the card is hidden and the Health plugin isn't part of the build.

## What it imports

For each running workout:

| From Apple Health | On the Show |
| --- | --- |
| Start time | Date and time |
| Indoor flag (treadmill) | Studio Session; otherwise a Live Show |
| Distance | Miles (to 2 decimals) |
| Time moving (pauses left out when Health knows them) | Duration |
| Elevation gained | Live Show elevation gain (ft) |
| Weather temperature | Live Show temperature (°F) |

Everything else starts plain so you can fill it in: workout type Easy, effort 5, feel "Fine", no notes, no Gear, no Song of the Show. Edit the Show as usual afterwards.

The first import looks back 30 days. After that it looks from a day before the last import. The sheet lists only runs that aren't on the Setlist yet, all checked; uncheck any you don't want and tap "Add N Shows".

### No doubles

- Each imported Show keeps the Health workout's id (`healthWorkoutId`), so the same run is never offered twice.
- A run is also skipped when a Show you logged by hand is on the same day with a distance within 5% (at least 0.05 mi), since that's almost certainly the same run.
- Runs with no distance (for example an iPhone-only treadmill run) are skipped, because a Show needs miles.

## Privacy

- **Read only.** The app asks for read access to Workouts and nothing else (no heart rate, no location, no routes). It never writes to Apple Health. iOS requires an "update" usage string in Info.plist anyway; ours says the app never writes.
- **Stays yours.** Imported Shows are saved like any other Show: on this iPhone, and, if you have a Backstage Pass, in your own synced account. Nothing is sent anywhere else, and the Health data itself is never uploaded, only the Shows you choose to add.
- The time of the last import is kept on the device only (the `app_prefs` store, key `healthLastImport`).

## Turning access on or off

iOS asks once. To change it later: **Settings > Health > Data Access & Devices > Setlist Tracker**, then turn Workouts on or off. iOS never tells an app that reading was refused (a refusal just looks like no workouts), so when nothing shows up the sheet points to that setting.

## For developers

- `lib/data/health/health_source.dart`: the `HealthSource` interface and `HealthRun`. The real reader (`health_source_apple.dart`, package `health`) is only imported where `dart.library.io` exists and only used when `Platform.isIOS`; web gets `health_source_stub.dart`.
- `lib/logic/health_import.dart`: pure mapping and de-duplication (`showFromHealthRun`, `newHealthRuns`, `healthImportStart`). Tests: `test/health_import_test.dart`.
- `lib/ui/backstage/apple_health_card.dart`: the card and the import sheet. Tests use a fake source through `healthSourceProvider`: `test/apple_health_import_test.dart`.

### iOS setup

- `ios/Runner/Info.plist`: `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` (done).
- HealthKit capability: the Runner target needs the HealthKit entitlement. In `ios/Runner/Runner.entitlements` add:

  ```xml
  <key>com.apple.developer.healthkit</key>
  <true/>
  <key>com.apple.developer.healthkit.access</key>
  <array/>
  ```

  or in Xcode: Runner target > Signing & Capabilities > + Capability > HealthKit (leave "Clinical Health Records" and "Background Delivery" off). The App ID in the Apple Developer account needs HealthKit switched on too (automatic signing does this).
- Needs iOS 15 or later (the `health` plugin's minimum).
