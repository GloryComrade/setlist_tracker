---
name: Setlist Tracker
description: Marathon training tracker dressed as a music tour. Every run is a Show, race day is Opening Night.
colors:
  stage-black: "#0B0A12"
  stage-surface: "#16141F"
  stage-surface-high: "#221F2E"
  stage-outline: "#3A3548"
  spotlight-white: "#F5F3FA"
  house-lights-grey: "#A8A3B8"
  neon-magenta: "#FF4D9A"
  marquee-amber: "#FFB020"
  studio-cyan: "#22D3EE"
  blacklight-violet: "#8B5CF6"
  magenta-deep: "#E0157A"
  orange-deep: "#C2410C"
  violet-deep: "#6D28D9"
  teal-deep: "#0E7490"
  gold-light: "#FFE9A8"
  gold-mid: "#F5C451"
  gold-deep: "#B7791F"
  gold-ink: "#1A1206"
  glow-magenta: "#E0157A38"
  glow-violet: "#6D28D940"
  spotify-green: "#1DB954"
typography:
  display:
    fontFamily: "ArchivoCondensed"
    fontSize: "48px"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "0px"
  headline:
    fontFamily: "ArchivoCondensed"
    fontSize: "30px"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "0px"
  title:
    fontFamily: "ArchivoCondensed"
    fontSize: "24px"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "0px"
  body:
    fontFamily: "Archivo"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.43
  label:
    fontFamily: "Archivo"
    fontSize: "11px"
    fontWeight: 800
    letterSpacing: "1.2px"
  numeral:
    fontFamily: "ArchivoCondensed"
    fontSize: "26px"
    fontWeight: 800
    lineHeight: 1.05
    fontFeature: "tnum"
rounded:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  pill: "28px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.magenta-deep}"
    textColor: "{colors.spotlight-white}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
  button-filled:
    backgroundColor: "{colors.magenta-deep}"
    textColor: "{colors.spotlight-white}"
  button-text:
    textColor: "{colors.neon-magenta}"
  button-outlined:
    textColor: "{colors.neon-magenta}"
  card:
    backgroundColor: "{colors.stage-surface}"
    rounded: "{rounded.lg}"
    padding: "16px"
  poster-header:
    textColor: "{colors.spotlight-white}"
    typography: "{typography.display}"
    rounded: "{rounded.xl}"
    padding: "20px"
  input:
    backgroundColor: "{colors.stage-surface-high}"
    textColor: "{colors.spotlight-white}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
  chip:
    backgroundColor: "{colors.stage-surface-high}"
    textColor: "{colors.spotlight-white}"
    rounded: "{rounded.xl}"
  chip-selected:
    backgroundColor: "{colors.magenta-deep}"
    textColor: "{colors.spotlight-white}"
    rounded: "{rounded.xl}"
  venue-badge:
    textColor: "{colors.spotlight-white}"
    typography: "{typography.label}"
    rounded: "{rounded.xl}"
    padding: "4px 10px"
  nav-bar:
    backgroundColor: "{colors.stage-surface}"
    textColor: "{colors.spotlight-white}"
  dialog:
    backgroundColor: "{colors.stage-surface}"
    rounded: "{rounded.xl}"
---

# Design System: Setlist Tracker

This file is the house rules for every screen. The tokens above are the source of truth and mirror `lib/theme/app_theme.dart` (`StageColors`, `StageFonts`, `AppTheme`). When a value changes in code, change it here in the same PR, and the other way round.

## Overview

**Creative North Star: "The Night of the Show"**

The app is a dark concert hall a few minutes before the lights go up. The room is near-black and quiet; the color comes only from stage lights: magenta and orange on the warm side for Live Shows, violet and teal on the cool side for Studio Sessions. Type is a tour poster: tall, condensed, all-caps headlines over a clean, plain body face. Numbers (miles, pace, time) are the headline act and are set big in the poster face.

Density is moderate. It is a training log people open on a phone right after a run, often sweaty and in a hurry, so screens are scannable stacks of cards with large numbers, not dashboards. Expression lives in the gradients, the screen-printed art on top of them, the poster type, and the tour words; everything else (forms, menus, pickers) is plain Material behavior on the stage's own surfaces, so it feels familiar on web and later on iPhone.

Every label speaks the tour language. A run is a Show, history is the Setlist, a treadmill run is a Studio Session, an outdoor run is a Live Show, a treadmill segment is a Track, a preset is a Saved Mix, the plan is The Tour, the long run is the Headliner, race day is Opening Night, PRs are Gold Records, shoes are Gear. Plan phases are Rehearsals, On the Road, Headline Leg and Soundcheck, and a cutback week is a Rest Stop. Units are always miles, mph, min/mi and °F.

**Key Characteristics:**
- Dark mode only: near-black stage (#0B0A12) with slightly lifted card surfaces.
- Color comes from stage-light gradients, not flat brand blocks.
- Archivo Condensed (extra condensed, black) for headlines and big numbers, Archivo at normal width for everything you read.
- Uppercase, tracked-out micro labels above values ("PACE", "WEEK OF NOV 17").
- Warm gradient means Live Show, cool gradient means Studio Session, everywhere.
- Tour vocabulary in every label, title, empty state and button.

## Colors

A near-black, slightly violet stage lit by four bright lights, each with a deeper twin for fills.

### Primary
- **Neon Magenta** (`neon-magenta`): the app's voice on the dark stage. Focused field underline, floating labels, text buttons, outlined buttons, the cursor, selection, slider track, the mic logo on the side rail, and small music-note marks.
- **Magenta Deep** (`magenta-deep`): the fill version of magenta. Filled buttons, the floating Book a Show button, selected chips and segments, switch tracks, the nav indicator (at 35% opacity). White text on it is 4.6:1.

### Secondary
- **Marquee Amber** (`marquee-amber`): pace and highlight numbers (pace on Show cards, weekly totals in the Setlist), the slider thumb, and the active Gear avatar. Black text, never white, when amber is a fill.
- **Orange Deep** (`orange-deep`): the warm end of the Live Show and headline gradients. White text 5.2:1.

### Tertiary
- **Studio Cyan** (`studio-cyan`): cool accents, used sparingly (Track totals in the Studio form).
- **Teal Deep** (`teal-deep`) and **Violet Deep** (`violet-deep`): the two ends of the Studio Session gradient; violet deep also opens the headline gradient. White text 5.4:1 and 7.1:1.
- **Blacklight Violet** (`blacklight-violet`): reserved. It is only 4.3:1 on a card surface, so use it for large marks or decoration, never for body-size text.

### Neutral
- **Stage Black** (`stage-black`): scaffold and app bar background.
- **Stage Surface** (`stage-surface`): cards, nav bar, side rail, dialogs, bottom sheets.
- **Stage Surface High** (`stage-surface-high`): one step up. Input fills, unselected chips, popup menus, snack bars, date picker header.
- **Stage Outline** (`stage-outline`): 1px card and dialog borders, dividers, chip borders, inactive slider track, retired Gear.
- **Spotlight White** (`spotlight-white`): all primary text (17.9:1 on the stage).
- **House Lights Grey** (`house-lights-grey`): secondary text, micro labels, hints, durations next to bright numbers (6.6:1 or better on every surface).

### Gold Foil
Gold Records only, never body text on the dark stage (amber does that job).
- **Gold Light** (`gold-light`, `StageColors.goldLight`) and **Gold Mid** (`gold-mid`, `goldMid`): the bright faces of the foil and the pressed disc.
- **Gold Deep** (`gold-deep`, `goldDeep`): the shadowed fold of the foil and the halftone dots on it.
- **Gold Ink** (`gold-ink`, `goldInk`): the only text color on the foil, a near-black brown (15.4:1 on Gold Light, 11.4:1 on Gold Mid, 5.1:1 on Gold Deep). Also the disc grooves.

### Stage Glow
- **Glow Magenta** (`glow-magenta`, `StageColors.glowMagenta`): Magenta Deep at 22%.
- **Glow Violet** (`glow-violet`, `StageColors.glowViolet`): Violet Deep at 25%.
Both fade to their own deep shade at 0% (`magentaDeep.withValues(alpha: 0)`), never to transparent black, so the falloff stays clean. Used only by `StageGlow`.

### Brand
- **Spotify Green** (`spotify-green`, `StageColors.spotifyGreen`): the one brand color allowed in the app, and only as the fill of the "Open in Spotify" button on the Show page, always with black text (8.1:1). Song picker rows, badges and everything else stay brand-free.

### Gradients
All run top-left to bottom-right, built only from the deep shades:
- **Live gradient:** Magenta Deep → Orange Deep. Live Show badges, ticket stubs, Live posters.
- **Studio gradient:** Violet Deep → Teal Deep. Studio Session badges, stubs, posters.
- **Headline gradient:** Violet Deep → Magenta Deep → Orange Deep. Screen poster headers and the primary Gradient Button.
- **Gold foil** (`goldFoil`): Gold Light → Gold Mid → Gold Deep → Gold Mid (stops 0, 0.35, 0.75, 1). Gold Records only.

### Named Rules
**The Two Twins Rule.** Each light has a bright twin and a deep twin. Bright shades (magenta, amber, cyan) are for text and marks on the dark stage. Deep shades are for fills that carry white text. Never put white text on a bright shade or bright text on a deep fill. Every white-on-fill pairing must stay at 4.5:1 or better.

**The Venue Color Rule.** Warm (magenta/orange) always means Live Show and cool (violet/teal) always means Studio Session. New screens reuse `gradientFor(venue)` rather than picking a gradient by taste.

**The Dark Stage Rule.** There is no light theme. Every Material surface (dialogs, sheets, menus, pickers, snack bars) is themed onto the stage colors with surface tint off; no default warm-grey Material tints may leak through.

## Typography

**Display Font:** Archivo Condensed, a static cut of Archivo's variable font at width 62 and weight 850 (bundled as `Archivo-ExtraCondensedBlack.ttf`, Latin + Latin Extended, SIL OFL), family `ArchivoCondensed`
**Body Font:** Archivo 400 (plus italic) / 600 / 700 / 800 at normal width (bundled, SIL OFL)

**Character:** one family doing two jobs. Squeezed tall and black it is a modern tour poster; at normal width it is a plain, sturdy grotesque that reads well at a glance. Both are bundled so type works offline and on iOS with no web font fetch. `ArchivoCondensed` is declared at weight 800 only; never ask it for a heavier weight, or Flutter fakes a bold.

### Hierarchy
- **Display** (Archivo Condensed, 64 / 48 / 38px, line-height 1.05, no tracking): poster headers ("THE SETLIST") at 48px; the day number on ticket stubs at 38px.
- **Headline** (Archivo Condensed, 34 / 30 / 26px, 1.05): empty-state titles and hero numbers. Miles on a Show card at 30px, pace and time at 26px, stat values at 26px.
- **Title** (Archivo Condensed, 24px, 1.05): app bar titles and Section Card titles.
- **Body** (Archivo 400, Material default 14–16px): notes, descriptions, form text. Song lines use Archivo 600.
- **Label** (Archivo 700–800, 11–12px, +0.8–1.2px tracking, UPPERCASE): micro labels above stats, week headers, venue badges, the workout type line on Show cards, Gradient Button text.

### Named Rules
**The Titles Shout, Names Don't Rule.** Archivo has lowercase, so case is set by the words, not the font. Titles of places in the app (poster headers, app bar titles, Section Card titles, empty-state and sheet headlines) are uppercase: `SectionCard` and `EmptyStage` uppercase their titles, other titles are written in caps. Names of things (songs, artists, Gear, routes, stage names in lists) and values (Headliner, Fine, Road) keep their own case, and units stay lowercase ("15 mi", "9:20 /mi", "6 wks", "48°F").

**The Poster Numbers Rule.** Distances, paces and durations are shown in the display face with tabular figures (`StageFonts.tabular`) so columns line up. Never set a stat in Archivo at body size when it is the point of the card.

**The Shout Sparingly Rule.** Uppercase is for Archivo Condensed titles and tiny tracked labels only. Body copy, buttons other than the Gradient Button (app bar "Save" included), and helper text stay in sentence case.

**The 11 pt Floor Rule.** No text below 11 pt anywhere, including chart labels and stamps.

**The Grow With the Reader Rule.** Every screen must hold at 150% and 200% text (iPhone Dynamic Type). Side-by-side pieces stack when they no longer fit (Tour countdown, Paces header, stat rows), and titles shrink a too-wide word with `WholeWordsText` rather than breaking it mid-word. Two deliberate caps: bottom tab bar labels stay at 100% like iOS tab bars, and chart axis text grows to 120% at most.

**The Say It Like a Runner Rule.** Screen readers hear words, not abbreviations. Any number with a unit gets its spoken form from `lib/logic/spoken.dart` ("15 miles, 9 minutes 20 seconds per mile"), `StatTile` does this by itself, and a tappable card is one button with a spoken summary (the Show card reads "Sunday 22. Headliner, Live Show. 15 miles, … Song: Lose Yourself by Eminem.").

## Imagery

The art is screen printing, never photography. Everything is printed in the stage's own inks: the deep shades and one black overprint ink at 16–40% (the same ink as the halftone, at 20%). It is one screen of one ink, so where strokes cross the ink takes the darker value and never builds past 40%. No photos, stock, bokeh, lens glow, crowds, rendered sheen or real album covers, and nothing a viewer could take for a real record or a real place.

**Venue prints** (`StageArt`, drawn by `tool/sample_art.py`, `assets/images/`):
- `print_live.png`, Live Show: a topographic map with a loop route, mile ticks and a start ring.
- `print_studio.png`, Studio Session: a treadmill side-on, facing left: the console with its readout on a raked upright, the handrail, the motor hood over the front roller and the belt loop running off the right edge.

Each is an 810 × 900 PNG (9:10, `StageArt.printAspect`) of black ink on transparency (about 115 KB and 22 KB), with the subject in its left 60% and a soft left edge. `PosterSurface` paints the venue gradient, then the print, then the halftone, so the venue color always comes from `gradientFor(venue)` and the print never changes it. **The print never sits under type** (`PrintBeside`): it is drawn as tall as the poster, against the right edge, or starting 20pt past the widest line of type and running off the edge. If less than 60% of it would show (long lines, large text sizes) the poster is printed without it; at 150% text the Show poster is plain gradient and halftone. A widget test checks every line of type against the print at 100%, 150% and 200% text. Where they appear: the Show page poster only. Tab Poster Headers, the Tour header, the planned Show poster (its title and stat row run the full width), Crew posters, race-day posters and the Gold Records foil stay plain gradient plus halftone; a repeated picture on every tab reads as a reused stock image, a repeated light does not.

**Song sleeves** (`SongSleeve`, painted in code from the title and artist, so every song gets its own and none repeat on the Record Wall): a ground in one deep shade, a second deep shade printed thin over it (55%) as a split, a disc, three bands or three quarter rings at a hashed angle, and the black 20% halftone growing toward a hashed corner. The pair is always one warm and one cool ink (magenta or orange with violet or teal), so a sleeve never reads as a venue, and the thin second ink keeps the two close so the printed title, not the shape, carries the sleeve. Where the sleeve is the song's only label (Record Wall tiles) the title is set across the foot in Archivo Condensed at one size per sleeve size (14% of its width, 11–22), with the artist in Archivo 600 11px; a single word too long for that size sets that one title smaller. Everywhere the title is already written beside it (the Show page, Book a Show, the record sheet, Crew posts), and in the Backstage door's 2 × 2 mosaic of 20pt cells, the sleeve is the print alone: no title and no letter, since a letter on a colored square reads as a Crew avatar, and a clip's play button can sit on it. Sleeve type is part of the art and stays at 100% text size: the title and artist are always written next to it or in the tile's spoken label. Record Wall tiles darken when hovered or pressed (black 14–20%), never lighten, so the white sleeve type keeps its contrast.

**No art rule.** Real album art when the song has it. A sleeve-sized slot (Show page, Book a Show, Crew post, Record Wall) for a song with no art shows its `SongSleeve`. An inline song line on a Setlist ticket shows the magenta `music_note` mark instead of a 22px tile. While real art loads, or if it fails, the slot is a quiet Stage Surface High tile with a House Lights Grey `album` mark, and real art fades in over it in 150ms (no fade with Reduce Motion). A made-up cover never stands in for a real one. The Backstage Record Wall mosaic shows real covers first, then sleeves; with no songs at all it is the quiet tile.

**Contrast.** Prints and sleeves only use deep shades and black overprint, so every pixel under white type is at least as dark as the deep shade it sits on: 4.6:1 or better, with no scrim. Prints are set beside the type, never under it, and never pass 40% ink (both enforced by tests). There are no scrims or washes anywhere in the system.

**Decode and loading.** Both prints are precached at start (`StageArt.precache` in the app shell), about 2.9 MB each decoded, and fade in over 200ms if one ever arrives late; the gradient is already there underneath. Network album art decodes at the size it is drawn (`cacheWidth` = size × device pixel ratio). All art is excluded from semantics; titles and artists are always text next to it.

**Changing the art.** Edit `tool/sample_art.py` and run `python3 tool/sample_art.py` (Pillow and numpy); `--check` redraws in memory and fails if the committed files differ. The script has no randomness.

## Layout

Single column, mobile first. Content sits inside `MaxWidth` (720px) centered on wide browser windows. At 800px wide and up, the bottom NavigationBar becomes a NavigationRail on the left with the magenta mic as its logo; below that, a bottom bar.

Spacing works on a 4px base: 4, 8, 12, 16, 20, 32. Screen gutters and card padding are 16px; poster headers and week headers use 20px; empty states 32px. Cards in a list are 10px apart. Lists leave 96px at the bottom so the floating Book a Show button never covers the last card.

Every screen has its own URL (go_router), and detail screens provide a back button that still works when opened from a link (`backButtonFor`, `leaveScreen`).

## Elevation & Depth

Flat. Cards, app bars and dialogs have elevation 0. Depth comes from tonal steps (stage black → surface → surface high) plus a 1px outline border, and from the gradients, which read as light rather than shadow. No drop shadows anywhere in the system, including the Gold Records foil.

**Stage Glow.** The four main tabs sit under two soft house lights (`StageGlow` in the tab shell): a Magenta Deep light at 22% from the top-left (`glowMagenta`) and a Violet Deep light at 25% from the top-right (`glowViolet`), each fading to nothing within about 440px. The tab screens keep their own Scaffold transparent so the glow shows through. Detail screens, forms and dialogs stay on plain Stage Black.

**The Lit, Not Lifted Rule.** To make something stand out, light it (a gradient fill or a bright accent) instead of raising it with a shadow.

## Shapes

Soft, generous rounding, never sharp corners. Small art and thumbnails 4–8px; inputs, popup menus and the scrollbar 8–12px; cards 16px; poster headers, dialogs, chips and badges 20px; the Gradient Button is a full pill (28px). Cards and dialogs carry a 1px Stage Outline border; filled fields do not.

## Components

### Buttons
Confident and loud for the one main action, quiet for the rest.
- **Gradient Button (primary):** headline gradient, pill shape (28px), 14px × 24px padding, white Archivo 800 uppercase label tracked +1.2px, optional white leading icon. Disabled is the same button at 50% opacity. One per screen at most.
- **Filled:** Magenta Deep with white Archivo 700 text.
- **Text and Outlined:** Neon Magenta text; outlined adds a Stage Outline border. Labels in sentence case, including app bar actions ("Save", not "SAVE").
- **Open in Spotify:** a filled button in Spotify Green with black text and icon, on the Show page only. The one place a brand color appears.
- **Floating action:** "Book a Show" extended FAB in Magenta Deep with white Archivo 800 text, only on the Setlist tab.

### Chips
- **Style:** Stage Surface High fill, Stage Outline border, 20px radius, Archivo 600 label in Spotlight White.
- **Selected:** Magenta Deep fill with white label. Used for Setlist filters and single choices in forms.
- **Segmented buttons:** same color logic (transparent unselected, Magenta Deep selected, outline border).

### Cards / Containers
- **Corner Style:** 16px.
- **Background:** Stage Surface with a 1px Stage Outline border, elevation 0.
- **Internal Padding:** 16px.
- **Section Card:** a Card with a Archivo Condensed title row (and optional trailing action), 12px gap, then content. Groups parts of forms and detail screens.

### Inputs / Fields
- **Style:** filled with Stage Surface High, 12px radius, no visible border at rest. The label floats inside the fill (an outline border would park it on the field's edge, so don't switch to outlined fields).
- **Focus:** 2px Neon Magenta underline; floating label turns Neon Magenta.
- **Error:** Material error color underline, 1px at rest and 2px focused.
- **Labels and hints:** House Lights Grey. Units go in the label or suffix: mi, mph, %, °F, ft.

### Navigation
- **Bottom bar (narrow) / side rail (800px+):** Stage Surface background; indicator is Magenta Deep at 35% opacity; labels Archivo 600 12px. Each tab has an outlined icon and a filled selected icon (for example `queue_music_outlined` → `queue_music` for the Setlist, `leaderboard_outlined` → `leaderboard` for The Charts, `inventory_2_outlined` → `inventory_2` for Backstage). Charts draw bars and lines in the bright shades (cyan Studio, magenta Live, amber Headliners), since they are marks on the dark stage, and planned values as dashed outlines. New tabs follow the same outlined/filled pair.

### Icons
Material Icons only, no extra icon packs. Venue icons: `graphic_eq` for Studio Session, `landscape` for Live Show (via `iconFor(venue)`). Weather uses outlined icons where they exist (`wb_sunny_outlined`, `cloud_outlined`, `umbrella_outlined`) via `iconForConditions`. Music marks use `music_note` / `album` / `queue_music`. Icons inside gradient fills are white; on the dark stage they use Spotlight White or a bright accent. Badge icons 14px, inline marks 16–18px, nav default 24px.

### Poster Header (signature)
The top of main screens: full-width block in the headline gradient (or a venue gradient on a Show), 20px radius, 20px padding, title in Archivo Condensed Display 48px white, optional white subline or chips below.

Every poster-sized gradient block (Poster Header, the Tour header, the planned Show poster, the Gold Records foil) is a `PosterSurface`: the gradient plus a screen-printed halftone (`HalftonePainter`). Dots sit on a 7px 45° screen in black at 20% (Gold Deep on the gold foil), start at 40% across, and grow toward the bottom-right to about a third of the cell. Text sits on the left where there are no dots, and dark dots only add contrast to white type. The Show page poster also prints its venue art between the gradient and the dots (`venuePrint: StageArt.printFor(venue)`), beside its type and never under it; see Imagery.

### Show Card / Ticket Stub (signature)
A Setlist row styled as a ticket, cut with `TicketBorder`: 7px punched notches top and bottom where the stub meets the ticket, and a perforated tear line of 1.6px Stage Black holes every 7px between them. A 64px-wide venue-gradient stub on the left with the weekday (Archivo 800 12px uppercase), the date number (Archivo Condensed 38px) and the venue icon, all white. To the right: the workout and venue line as a micro label with a 22px Feel Face, then miles (Archivo Condensed 30px, white), pace (Archivo Condensed 26px, amber) and time (Archivo Condensed 26px, grey) with tabular figures on one line (it scales down rather than wrapping on a long Headliner), effort in grey, and the Song of the Show with 22px album art.

### Feel Face
How a Show felt, never as emoji (they draw differently on web, iPhone and Android and look like cartoons next to the posters). A circle in a stage-light gradient with a white rounded Material sentiment face (74% of the circle) on top. The light warms with the feel: Rough night violet → teal, Off key violet → magenta, Fine magenta → violet, Good set the Live gradient, Encore! the headline gradient. 22px on Show cards, 26px beside the label on the Show page, 44px in the Book a Show picker, where unpicked faces sit at 45% opacity and the picked one gets a 2px Spotlight White ring; the label below names the pick. Each picker face is one button with its label and selected state for screen readers.

### Venue Badge (signature)
A small pill (20px radius, 4px × 10px) in the venue gradient with a 14px white icon and "STUDIO SESSION" or "LIVE SHOW" in white Archivo 800 11px, tracked +0.8px. On a poster already lit in a gradient, use `VenueBadge(venue, onPoster: true)`: a black 26% cut-out instead of the gradient, so it doesn't vanish into its own color.

### Stat Tile
Uppercase micro label in House Lights Grey (11px, 700, +1.2px) over a Archivo Condensed 26px value with tabular figures, for example "PACE" over "8:42 /mi".

### Empty States
One component, `EmptyStage`: a centered 56px House Lights Grey icon, a Archivo Condensed headline in caps ("NO SHOWS YET"), then one grey sentence (max 340px wide) that tells you what to do in tour words ("Book your first one and start the Setlist."), then at most one Gradient Button. Leave the button off where the screen already has the action (the Setlist's floating Book a Show). Not in a card. Gold Records is the exception: its empty state is the list of records still to press, which teaches what each one is.

### Backstage Pass (account card)
The first card in Backstage, a Section Card titled "Backstage Pass". Signed out: one plain sentence on what the Pass does, then full-width 48px sign-in buttons: Sign in with Apple in Apple's own white-with-black style (above), Continue with Google as a Magenta Deep filled button. Signed in: an "ALL ACCESS" badge in the headline gradient (venue-badge shape) as the card's trailing action, a 44px Magenta Deep avatar with the initial in Archivo Condensed, name in Archivo 700 and email in House Lights Grey, an overflow menu (Sign out, Delete account), then one sync line: an 18px outlined cloud icon in grey (`cloud_done_outlined`) or amber when offline (`cloud_off_outlined`), grey text ("Synced 5 min ago", "Offline. 2 changes wait on this device."), and a Sync now text button. Sign out and Delete account always confirm in a dialog; the destructive action uses the error color. On the Setlist, a guest with 3 or more Shows sees one dismissible card ("Get your Backstage Pass…") with a magenta `badge_outlined` icon; it never returns once closed. Signed in, pulling down on the Setlist syncs.

### Song Picker
A bottom sheet ("SONG OF THE SHOW") with a search field and a plain list: 52px album art, the title in Archivo 700, artist and album in House Lights Grey. Each row ends with where the result came from, "Spotify" or "Apple Music", as plain Archivo 600 11px House Lights Grey text in sentence case: no logos, no brand colors, never louder than the song. While a picked Spotify song looks up its Apple preview, the sheet's 2px progress bar runs and further taps wait.

### Apple Health import
iPhone only; on web the card is not built at all. A Section Card titled "Apple Health" under the Backstage Pass: one sentence ("Bring in runs from your Apple Watch or iPhone as Shows.") and a full-width 48px Magenta Deep "Import runs" button with a `favorite_border` heart, which shows a small spinner and "Checking Apple Health…" while it reads. Results open in a bottom sheet: a Archivo Condensed "NEW FROM APPLE HEALTH" headline, one grey line with the count and window, then one row per run (checkbox, the day in Archivo 700 with a Venue Badge on the right, miles / pace (amber) / time in Archivo Condensed with tabular figures, and "7:00 AM · Apple Watch" in grey), all checked, and one Gradient Button "Add 3 Shows". Nothing new and no access use the Empty State layout inside the sheet with a grey hint naming Settings > Health > Data Access & Devices > Setlist Tracker, and a Done text button. The result is a snack bar ("3 Shows added to the Setlist.").

### The Crew (friend sharing)
The fourth tab, "The Crew" (`groups_outlined` → `groups`), between The Charts and Backstage. Friends are your Crew; a cheer is an Encore.
- **Guests and local-only builds** get the Empty State: "JOIN THE CREW" with a "Go Backstage" Gradient Button, or "THE CREW IS COMING" with no button.
- **First visit:** a Poster Header "THE CREW", a Section Card "Pick your stage name" (filled field, four avatar swatches, Gradient Button "Join the Crew"), then three plain rows on how it works with magenta 22px icons.
- **Crew Avatar:** a circle in one of the four deep shades (`crewColors`) with the initial in Archivo Condensed, white. 24px on a post, 40px in lists, 48px in the Crew strip, 56–64px on sheets and the invite poster (with a 3px white ring on a gradient).
- **Home:** a headline-gradient `PosterSurface` with "THE CREW", one white line ("3 runners in your Crew. They see every Show you log.", or "They see the Shows you shared." while a runner from before the change hasn't OK'd it) and the Settings button in its corner (see Settings). Below it the "Your Crew" Section Card: a horizontal strip of avatar chips at least 76px wide that grow with text size (name in Archivo 600, days to Opening Night in amber tabular figures), "Enter a code" as the text-button action, and the screen's one Gradient Button, "Invite a friend". Then a "LATEST SHOWS" micro label and the feed. Runners who joined before the Crew showed everything first see a one-time Section Card "Your Crew sees more now" with a filled "Sounds good" and a "Not now" text button.
- **Crew post:** at 150% text the "2 hr ago" moves under the name, which never truncates first; the name is its own 44pt button for screen readers. The Show Card ticket (`TicketBorder`, venue-gradient stub), with a signature row on top (24px avatar, stage name in Archivo 700 or "You", grey "2 hr ago", an overflow menu), the same workout line and Archivo Condensed numbers, the Song of the Show with 36px album art (or its Song Sleeve) and the song note on its own grey line (up to 2 lines), the workout line with a 22px Feel Face, "Effort 7/10 · Good set" in grey, a wrap of 16px-icon facts in Archivo 600 13px (route · surface, climb, weather, Track summary for Studio Sessions, Gear), Gold Records (friend page only) as small Stage Surface High pills with an amber outline and an amber `album` disc, notes in body text (over 4 lines get a More/Less button), and the Encore text button (`celebration_outlined` → `celebration` in Neon Magenta when you cheered, "Encore · 3"). On your own post the Encore line is a grey count instead.
- **Invite sheet:** "INVITE TO THE CREW", one grey sentence, the code in Archivo Condensed Display with wide tracking on a Stage Surface High block, then a filled "Send invite" (system share sheet, falls back to copy) and an outlined "Copy link". Codes are 8 characters shown as "K7Q9 MX4P".
- **Join screen** (`/crew/join/CODE`): a headline-gradient poster with the inviter's avatar and "MAYA INVITES YOU TO THE CREW", what joining means in one white sentence, then the Gradient Button "Join the Crew" and a "Not now" text button. Expired, own and already-joined invites use the Empty State.
- **On a Show:** your Crew sees every Show you log. The Book a Show form ends with a Section Card "The Crew" holding one "Keep off the Crew" switch (signed-in runners with a stage name, or a Show already kept off); the Show page shows a grey `visibility_off_outlined` line "Kept off the Crew. Only you see this Show." under the poster.
- **Friend page** (`/crew/mate/:userId`): a headline-gradient poster (56px avatar with a white ring, stage name in Display, Shows and miles in white), a "The Tour" Section Card (their Tour poster with this week's "2 of 5 Shows · 12.4 mi", then a Magenta Deep filled "Book a Tour featuring Maya" button, or a magenta `groups` line "Co-headlining Spring 2027 Tour" when your Tours share an Opening Night), a "Gold Records" card computed from their Setlist (at most 3 rows, one per Show, week and month records that only repeat the Longest Show dropped, no card under 5 Shows), then their Setlist as Crew posts without the signature avatar. The mate sheet from the Crew strip shows the same Tour card and a "See Maya's Setlist" outlined button.
- **Tour tab:** one Card per co-headlining Crew mate under the Tour header: 40px avatar, a "FEATURING" micro label, the name in Archivo 700 16px, then one line of news (this week's "2 of 5 Shows · 12.4 mi so far", or their latest Show), opening their page.
- **Book The Tour, race question:** "What are you racing?" with four tiles led by the miles (3.1 / 6.2 / 13.1 / 26.2) in Archivo Condensed 26px tabular with a small "MI" label, then the race name and week range. Booking from a friend starts at the goal ("Question 1 of 7") under one summary row ("Half · Sat, Feb 20 · with Maya") and a "Change race" button. Hidden when signed out or nobody matches.
- Remove, Block and Report always confirm; Block and Report use the error color. Bottom sheets open over the nav bar.

### App Bars
Detail screens name the kind of screen ("THE SHOW", "TOUR DATE · WEEK 3", "BOOK A SHOW", "EDIT SAVED MIX"); the poster below carries the content. Screens whose poster already names them (Gold Records, The Record Wall) leave the app bar title empty.

### Settings
`/settings`, a detail screen over the tabs (app bar "SETTINGS", back button). Opened from the top-right corner of every tab's poster: a 48pt button (tooltip "Settings") holding your Crew picture at 34px in a 2px white ring, your Backstage Pass initial when you have no stage name yet, or a white `person_outline` when signed out. The tab shell sets it once (`PosterCornerAction`); `PosterHeader` and the Crew and Tour posters place it after their own actions, top-aligned with the title. On the Crew poster it replaces the old `tune` Crew settings button and sheet.
- One column of Section Cards, in this order: **Your profile** (a 64px avatar beside the stage name in Headline, then "Picture" in Archivo 700, the badge grid, the photo buttons, a divider, and the stage name form with the four color swatches and the screen's one Gradient Button, "Save name and color"); **The Crew** (signed in with a stage name only: a "Keep new Shows off the Crew" switch, the "let them see every Show" opt-in while it's pending, and the blocked runners with Unblock); **The Tour** (Headliner day and Studio or Live as filled dropdowns; "Ask me" leaves the quiz unanswered); **Song of the Show** (a Spotify / Apple Music segmented button); **Apple Health** (iPhone only: an import switch that hides the Backstage card when off); the **Backstage Pass** card itself; **About** (Privacy policy and Support rows with an `open_in_new` mark, the training disclaimer, the version in tabular figures).
- Signed out or local-only, Your profile is one grey sentence pointing at the Backstage Pass below; nothing else changes.
- Switches use the Book a Show form's off state (grey outline and thumb) so "off" reads on a card.
- Preferences stay on the device (`AppSettings` behind `SettingsStore`, Sembast today). With Apple Music picked, the Show page leads with a Magenta Deep "Open in Apple Music" (the song's link, else Apple Music search) and keeps the green Spotify button second.

### Crew pictures
A runner's picture is their photo, else a drawn badge, else their initial, always on their avatar color (`CrewAvatar` picks; the name is always said beside it, so the picture is excluded from semantics).
- **Badges:** 24 tour-art marks (mic, vinyl, guitar pick, running shoe, headphones, drumsticks, lightning, star, ticket, amp, cassette, setlist, laurel, medal, stopwatch, mountain, flame, wave, moon, sun, heart, crown, music note, spotlight), one white mark at 58% of the circle. Most are Material Icons; the seven Material has no shape for are drawn in `avatar_badges.dart` on the same 24-unit grid, filled, never outlined. No stock or brand art.
- **Badge grid:** 44px avatars in a wrap, your initial first, then the badges, each one button with its name ("Crown badge") and selected state; the pick gets the swatches' 2px Spotlight White ring. With a photo up, no badge is ringed, and picking one asks first because the photo comes off.
- **Photo:** "Upload a photo" (outlined, `add_photo_alternate_outlined`) opens the library; the device takes the middle square, makes it 256px JPEG under 64 KB, and shows it in a 120px circle in a "Use this photo?" dialog before it goes up. "Change photo" and a grey "Remove photo" follow. The photo loads under sign-in, so the badge or initial shows until it arrives and stays if it never does. Photos are the one place a picture that isn't screen-printed appears, and only because a runner chose it; they are never used as art.
- **Report photo** sits under Block on a Crew mate's sheet when they have a photo, in the error color, and uses the Show report sheet ("REPORT THIS PHOTO").

## Do's and Don'ts

### Do:
- **Do** take every color from `StageColors` and every font from `StageFonts`; add new tokens there (and here) instead of inline hex values.
- **Do** use the deep shades (#E0157A, #C2410C, #6D28D9, #0E7490) for any fill with white text, and check new pairings reach 4.5:1.
- **Do** use `gradientFor(venue)` and `iconFor(venue)` whenever something belongs to a Studio Session or Live Show.
- **Do** set stats in Archivo Condensed with tabular figures, and label them with an uppercase tracked micro label.
- **Do** use the tour words from the Overview in every title, button, empty state and error message.
- **Do** show miles, mph, min/mi, ft and °F.
- **Do** theme any new Material widget onto the stage surfaces with surface tint off.
- **Do** keep layouts single column inside `MaxWidth` and test at phone width first.

### Don't:
- **Don't** add a light theme or light surfaces.
- **Don't** put white text on the bright shades (#FF4D9A, #FFB020, #22D3EE, #8B5CF6), or use Blacklight Violet for small text.
- **Don't** add drop shadows or raised elevation; use tone and light instead.
- **Don't** swap the warm/cool venue colors or invent new gradients for one screen.
- **Don't** load fonts from a CDN or `google_fonts` at runtime; bundle them in `assets/fonts` so type works offline and on iOS.
- **Don't** switch inputs to outlined borders.
- **Don't** use generic fitness words ("workout log", "run history", "PRs", "shoes") in the UI.
- **Don't** use more than one Gradient Button on a screen.
- **Don't** add photos, stock art, bokeh, crowds or glowing light effects, or a picture that could pass for a real album cover; the art is screen-printed in the stage inks (see Imagery).
- **Don't** use brand colors; Spotify Green on the Open in Spotify button is the only exception.
- **Don't** wrap widgets in hover-only `Tooltip`s; they do nothing on iPhone. Give icon-only buttons a `tooltip:` (it is also their screen reader label) and anything else a `Semantics` label.

## Front page

The page a first-time visitor sees at setlisttracker.com (`web/index.html`, `web/front/`). It is plain HTML and CSS, not Flutter, and it has its own rules. Nothing in this section applies inside the app.

**The idea.** The inner sleeve of the record: stage black with a faint paper grain, a narrow reading column written in the first person, real app screens tipped in as slightly crooked prints, and one amber pen writing notes in the margin.

### Rules

- **Two inks.** Stage Black and Spotlight White, with Marquee Amber as the only accent. No gradients, glows or cards of the page's own; the only gradients are inside the app screenshots. Magenta, violet and cyan do not appear outside the screenshots.
- **Amber at page scale, twice.** The Track listing insert and the closing band ("Doors are open" plus the footer, one piece). Everywhere else amber is the pen, a button or a number.
- **Three faces.** Archivo for reading, Archivo ExtraCondensed Black in capitals for headlines, and Mynerve (OFL, `web/front/fonts/`) for handwriting only: margin notes, the week's setlist, a few asides. Never a paragraph in Mynerve.
- **Loud twice, quiet otherwise.** The opening headline, "The plan is arithmetic." and "Doors are open" run the full width. Other headings stay at or under 3.9rem. Reading text is 18px on a 35rem measure; nothing is smaller than 16px.
- **Imagery is the real app.** Screenshots of the sample data, cropped tight, at slight angles, fixed three ways: tape, photo corners, or laid flat in the column. Every handwritten note points at, or sits under, something that is actually in the picture. Sample data is labelled as sample. No stock photos, icons or emoji.
- **Marks share one hand.** Arrows, rings, underlines and strike-throughs are inline SVG paths, stroke 2.6, round caps, `currentColor`.
- **Depth is paper, not light.** Prints and paper carry an offset, soft, black shadow. This is the one place shadows are allowed, because the page is a physical sleeve; the app's no-shadow rule stands inside the app.
- **Voice.** First person, plain, American spelling, no em-dashes. Every claim has to be true of the shipped app, and the page says what the app does not do. No testimonials until there are real ones. Anything written in Ryan's voice needs his sign-off. Numbers the plan prints are rounded to the half mile, so rules on the page say "about" where the screenshots would show the rounding.
- **Motion.** One authored moment: margin notes are written in as a print scrolls into view. Notes are visible by default; the script only arms prints below the fold, and never under `prefers-reduced-motion`.

### Page-only tokens

| Token | Value | Use |
|---|---|---|
| `--paper` | #ECE7DA | print borders, tape, photo corners, the handwritten setlist |
| `--paper-ink-2` | #4B4536 | secondary text on paper (7.6:1) |
| `--amber-ink-2` | #4A3204 | secondary text on amber (6.6:1) |
| `--amber-deep` | #9A6406 | the bottom edge of the amber button |
| `--pen` | Mynerve | handwriting, 1.32rem, line-height 1.32 |
| `--measure` | 35rem | reading column |

Stage Black, Stage Surface, Stage Outline, Spotlight White, House Lights Grey, Marquee Amber and Gold Ink are used as defined above. Radii are 1 to 3px (paper, not app cards).

### How it shares `/` with the app

`web/index.html` is both the front page and the Flutter shell. A script in `<head>` decides before first paint:

- Straight to the app when the address has an app route (`#/...`, which covers Crew invite links), on the return leg of sign-in (`?login_code=` or `?login_error=`), when installed to a home screen, when `localStorage` has `st.opened`, or when the app's `setlist_tracker` database already exists in IndexedDB.
- Otherwise the front page. If storage cannot be read, the page shows and one tap opens the app.
- `/?front=1` always shows the front page, for returning visitors and for linking to it.
- "Open the app" covers the page (and makes it `inert`), pushes a history entry, and loads `flutter_bootstrap.js`. On Flutter's first frame it sets the flag and removes the page and its stylesheet. The flag waits for that first frame so a failed load never hides the page on the next visit.
- Back from the app's first screen lands on the page's own history entry, which reloads as `/?front=1`.
- If `flutter_bootstrap.js` or `main.dart.js` fails to load, the page comes back with an error line (or, for a returning visitor, the cover says so and offers Try again). After 45 seconds with no first frame the cover offers Try again too.
- A Ctrl, Cmd or Shift click on "Open the app" is left to the browser, so it opens the app in a new tab. Resting a mouse on the button for 150ms prefetches `main.dart.js`; touch, keyboard focus and Save-Data never do.

Every selector in `web/front/front.css` is scoped to `#front` (or `html.st-front`) so nothing leaks into the app. Nothing clips the page sideways except the tilted Track listing sheet (`.sheet-zone`), so content that overflows at large text sizes shows up in testing instead of being cut off. Single-column grids use one `minmax(0,1fr)` track for the same reason. Keep URLs relative: `<base href>` is set per build. In-page links are scrolled by script because of that `<base>`.

