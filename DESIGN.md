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
  live-mark: "#FF4D9A"
  studio-mark: "#22D3EE"
  feel-fine: "#4A4458"
  grain: "#FFFFFF0D"
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
    backgroundColor: "{colors.marquee-amber}"
    textColor: "{colors.gold-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
  button-filled:
    backgroundColor: "{colors.stage-surface-high}"
    textColor: "{colors.spotlight-white}"
  button-text:
    textColor: "{colors.marquee-amber}"
  button-outlined:
    textColor: "{colors.marquee-amber}"
  card:
    backgroundColor: "{colors.stage-surface}"
    rounded: "{rounded.lg}"
    padding: "16px"
  poster-header:
    backgroundColor: "{colors.stage-surface}"
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
    backgroundColor: "{colors.marquee-amber}"
    textColor: "{colors.gold-ink}"
    rounded: "{rounded.xl}"
  venue-badge:
    textColor: "{colors.live-mark}"
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

The app is a dark concert hall with the house lights down. The room is near-black, flat and quiet, with a fine film grain like a print of the night; nothing glows and nothing blends. One light is on: Marquee Amber, the one accent, for the main action, selections and the hero number. The venues are marks, not fills: a magenta edge and label for Live Shows, a cyan one for Studio Sessions. Type is a tour poster: tall, condensed, all-caps headlines over a clean, plain body face. Numbers (miles, pace, time) are the headline act and are set big in the poster face.

Density is moderate. It is a training log people open on a phone right after a run, often sweaty and in a hurry, so screens are scannable stacks of cards with large numbers, not dashboards. Expression lives in the poster type, the grain, the venue marks, the one amber accent, the printed venue art and the tour words; everything else (forms, menus, pickers) is plain Material behavior on the stage's own surfaces, so it feels familiar on web and later on iPhone.

Every label speaks the tour language. A run is a Show, history is the Setlist, a treadmill run is a Studio Session, an outdoor run is a Live Show, a treadmill segment is a Track, a preset is a Saved Mix, the plan is The Tour, the long run is the Headliner, race day is Opening Night, PRs are Gold Records, shoes are Gear. Plan phases are Rehearsals, On the Road, Headline Leg and Soundcheck, and a cutback week is a Rest Stop. Units are always miles, mph, min/mi and °F.

**Key Characteristics:**
- Dark mode only: near-black stage (#0B0A12) with slightly lifted card surfaces.
- Flat, high-contrast surfaces with film grain. No gradients, glows or color-filled posters anywhere.
- Amber is the one accent on a neutral stage.
- Archivo Condensed (extra condensed, black) for headlines and big numbers, Archivo at normal width for everything you read.
- Uppercase, tracked-out micro labels above values ("PACE", "WEEK OF NOV 17").
- A magenta mark means Live Show, a cyan mark means Studio Session, everywhere, and only ever as an edge, outline, dot or label.
- Tour vocabulary in every label, title, empty state and button.

## Colors

A near-black, slightly violet stage, flat neutrals, one amber accent and two venue marks.

### The one accent
- **Marquee Amber** (`marquee-amber`, `StageColors.amber`, also `ColorScheme.primary`): the only action and selection color. The Stage Button and the floating Book a Show button (filled, Gold Ink text), selected chips and segments, the nav indicator (amber at 30% with a Spotlight White icon, 9.9:1), switch thumbs and tracks, sliders, checkboxes, progress indicators, focused field underline and floating label, cursor and selection, text and outlined buttons, links, today on the Calendar, the hero number on a poster (the miles on a Show, the days to go on the Tour and Charts), and pace and highlight numbers. 9.9:1 on Stage Surface, 8.8:1 on Stage Surface High, 10.8:1 on Stage Black. When amber is a fill its text and icons are **Gold Ink** (10.1:1), never white.

### Venue marks
- **Live Mark** (`live-mark`, `StageColors.liveMark`, Neon Magenta #FF4D9A) and **Studio Mark** (`studio-mark`, `StageColors.studioMark`, Studio Cyan #22D3EE): `markFor(venue)`. A 5pt left edge on Show posters, ticket stubs and venue tiles (4pt on small tiles), the Venue Badge outline, icon and label, Calendar dots, venue icons, the venue print, and the chart series. As text: magenta 5.9:1 on Stage Surface and 5.2:1 on Stage Surface High, cyan 10.1:1 and 8.9:1. Magenta is no longer an action color anywhere.

### Deep shades
- **Magenta Deep**, **Violet Deep**, **Teal Deep**, **Orange Deep** (`magenta-deep`, `violet-deep`, `teal-deep`, `orange-deep`): small flat fills that carry white text or a white mark: Feel Faces, Crew avatars, song sleeves, the Tour phase bars. White on them is 4.6:1, 7.1:1, 5.4:1 and 5.2:1. Never a poster, header or button fill.
- **Feel Fine** (`feel-fine`, `StageColors.feelFine`): the plain stage grey behind the Fine Feel Face (white 9.3:1).
- **Blacklight Violet** (`blacklight-violet`): reserved. It is only 4.3:1 on a card surface, so use it for large marks (the Rehearsals phase), never for body-size text.

### Neutral
- **Stage Black** (`stage-black`): scaffold and app bar background.
- **Stage Surface** (`stage-surface`): posters, cards, nav bar, side rail, dialogs, bottom sheets.
- **Stage Surface High** (`stage-surface-high`): one step up. Ticket stubs, venue tiles, filled (secondary) buttons, input fills, unselected chips, popup menus, snack bars, date picker header.
- **Grain** (`grain`, `StageColors.grainOpacity`): Spotlight White at 5%, fine specks over the main tabs and every poster (see Elevation & Depth).
- **Stage Outline** (`stage-outline`): 1px card and dialog borders, dividers, chip borders, inactive slider track, retired Gear.
- **Spotlight White** (`spotlight-white`): all primary text (17.9:1 on the stage).
- **House Lights Grey** (`house-lights-grey`): secondary text, micro labels, hints, durations next to bright numbers (6.6:1 or better on every surface).

### Gold Foil
Gold Records only, never body text on the dark stage (amber does that job).
- **Gold Mid** (`gold-mid`, `goldMid`): the flat foil (`PosterSurface.foil`) and the pressed disc. **Gold Light** (`gold-light`) is kept for reference only.
- **Gold Deep** (`gold-deep`, `goldDeep`): the printed halftone dots on the foil (2.2:1 on Gold Mid, texture only), the disc's rim and grooves.
- **Gold Ink** (`gold-ink`, `goldInk`): the only text color on the foil and on amber, a near-black brown (11.4:1 on Gold Mid, 10.1:1 on amber, 5.1:1 on Gold Deep). Also the disc label.

### Brand
- **Spotify Green** (`spotify-green`, `StageColors.spotifyGreen`): the one brand color allowed in the app, and only as the fill of the "Open in Spotify" button on the Show page, always with black text (8.1:1). Song picker rows, badges and everything else stay brand-free.

### Named Rules
**The No Gradients Rule.** There are no gradients in the app: no linear, radial or sweep fills, no glows, no fades. Every surface is one flat color, with grain (or, on the Gold Records foil only, printed halftone) as its texture. `test/flat_stage_test.dart` fails on any `LinearGradient`, `RadialGradient`, `SweepGradient` or `gradient:` under `lib/ui` or `lib/theme`; its allowlist is empty, and a file may only join it with a line here saying why.

**The One Accent Rule.** Amber is the one accent. Everything you can press, pick or focus, and the one number a poster leads with, is amber; everything else is Spotlight White, House Lights Grey or a venue mark on the neutral stage. On an amber fill, type is Gold Ink.

**The Two Twins Rule.** Bright shades (amber, magenta, cyan) are for text and marks on the dark stage. Deep shades are for small fills that carry white. Never put white text on a bright shade or bright text on a deep fill. Every text pairing must stay at 4.5:1 or better (3:1 for a Feel Face and other large marks).

**The Venue Color Rule.** Magenta always means Live Show and cyan always means Studio Session, and a venue color is only ever a mark: a 4–6pt left edge, an outline, a dot, an icon or a label. A venue color never fills a large area (a poster, a stub, a button, a card). New screens use `markFor(venue)` and `iconFor(venue)`, never a color picked by taste.

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
- **Label** (Archivo 700–800, 11–12px, +0.8–1.2px tracking, UPPERCASE): micro labels above stats, week headers, venue badges, the workout type line on Show cards, Stage Button text.

### Named Rules
**The Titles Shout, Names Don't Rule.** Archivo has lowercase, so case is set by the words, not the font. Titles of places in the app (poster headers, app bar titles, Section Card titles, empty-state and sheet headlines) are uppercase: `SectionCard` and `EmptyStage` uppercase their titles, other titles are written in caps. Names of things (songs, artists, Gear, routes, stage names in lists) and values (Headliner, Fine, Road) keep their own case, and units stay lowercase ("15 mi", "9:20 /mi", "6 wks", "48°F").

**The Poster Numbers Rule.** Distances, paces and durations are shown in the display face with tabular figures (`StageFonts.tabular`) so columns line up. Never set a stat in Archivo at body size when it is the point of the card.

**The Shout Sparingly Rule.** Uppercase is for Archivo Condensed titles and tiny tracked labels only. Body copy, buttons other than the Stage Button (app bar "Save" included), and helper text stay in sentence case.

**The 11 pt Floor Rule.** No text below 11 pt anywhere, including chart labels and stamps.

**The Grow With the Reader Rule.** Every screen must hold at 150% and 200% text (iPhone Dynamic Type). Side-by-side pieces stack when they no longer fit (Tour countdown, Paces header, stat rows), and titles shrink a too-wide word with `WholeWordsText` rather than breaking it mid-word. Two deliberate caps: bottom tab bar labels stay at 100% like iOS tab bars, and chart axis text grows to 120% at most.

**The Say It Like a Runner Rule.** Screen readers hear words, not abbreviations. Any number with a unit gets its spoken form from `lib/logic/spoken.dart` ("15 miles, 9 minutes 20 seconds per mile"), `StatTile` does this by itself, and a tappable card is one button with a spoken summary (the Show card reads "Sunday 22. Headliner, Live Show. 15 miles, … Song: Lose Yourself by Eminem.").

## Imagery

The art is screen printing, never photography. Everything is printed in the stage's own inks: the venue marks, the deep shades, and black. A print is one screen of one ink, so where strokes cross the ink takes the darker value and never builds past 40%. No photos, stock, bokeh, lens glow, crowds, rendered sheen or real album covers, and nothing a viewer could take for a real record or a real place.

**Venue prints** (`StageArt`, drawn by `tool/sample_art.py`, `assets/images/`):
- `print_live.png`, Live Show: a topographic map with a loop route, mile ticks and a start ring.
- `print_studio.png`, Studio Session: a treadmill side-on, facing left: the console with its readout on a raked upright, the handrail, the motor hood over the front roller and the belt loop running off the right edge.

Each is an 810 × 900 PNG (9:10, `StageArt.printAspect`) of black ink on transparency (about 115 KB and 22 KB), with the subject in its left 60% and a soft left edge. The PNG's alpha is the screen and the poster supplies the ink: `PosterSurface` prints it in the venue mark at 60% (`PosterSurface.printStrength`, `BlendMode.srcIn`), so the art shows at 10–24% on the dark Stage Surface, magenta for Live, cyan for Studio, and grain goes over it. **The print never sits under type** (`PrintBeside`): it is drawn as tall as the poster, against the right edge, or starting 20pt past the widest line of type and running off the edge. If less than 60% of it would show (long lines, large text sizes) the poster is printed without it; at 150% text the Show poster is plain surface and grain. A widget test checks every line of type against the print at 100%, 150% and 200% text. Where they appear: the Show page poster only. Tab Poster Headers, the Tour header, the planned Show poster (its title and stat row run the full width), Crew posters, race-day posters and the Gold Records foil stay plain; a repeated picture on every tab reads as a reused stock image.

**Song sleeves** (`SongSleeve`, painted in code from the title and artist, so every song gets its own and none repeat on the Record Wall): a ground in one deep shade, a second deep shade printed thin over it (55%) as a split, a disc, three bands or three quarter rings at a hashed angle, and a black film grain at 22% over it (shifted per sleeve). The pair is always one warm and one cool ink (magenta or orange with violet or teal), so a sleeve never reads as a venue, and the thin second ink keeps the two close so the printed title, not the shape, carries the sleeve. Where the sleeve is the song's only label (Record Wall tiles) the title is set across the foot in Archivo Condensed at one size per sleeve size (14% of its width, 11–22), with the artist in Archivo 600 11px; a single word too long for that size sets that one title smaller. Everywhere the title is already written beside it (the Show page, Book a Show, the record sheet, Crew posts), and in the Backstage door's 2 × 2 mosaic of 20pt cells, the sleeve is the print alone: no title and no letter, since a letter on a colored square reads as a Crew avatar, and a clip's play button can sit on it. Sleeve type is part of the art and stays at 100% text size: the title and artist are always written next to it or in the tile's spoken label. Record Wall tiles darken when hovered or pressed (black 14–20%), never lighten, so the white sleeve type keeps its contrast.

**No art rule.** Real album art when the song has it. A sleeve-sized slot (Show page, Book a Show, Crew post, Record Wall) for a song with no art shows its `SongSleeve`. An inline song line on a Setlist ticket shows the magenta `music_note` mark instead of a 22px tile. While real art loads, or if it fails, the slot is a quiet Stage Surface High tile with a House Lights Grey `album` mark, and real art fades in over it in 150ms (no fade with Reduce Motion). A made-up cover never stands in for a real one. The Backstage Record Wall mosaic shows real covers first, then sleeves; with no songs at all it is the quiet tile.

**Contrast.** Sleeves only use deep shades and black grain, so every pixel under white type is at least as dark as the deep shade it sits on: 4.6:1 or better, with no scrim. Prints are set beside the type, never under it, and never pass 40% ink before the mark's 60% (both enforced by tests). There are no scrims or washes anywhere in the system.

**Decode and loading.** Both prints are precached at start (`StageArt.precache` in the app shell), about 2.9 MB each decoded, and fade in over 200ms if one ever arrives late; the flat surface is already there underneath. Network album art decodes at the size it is drawn (`cacheWidth` = size × device pixel ratio). All art is excluded from semantics; titles and artists are always text next to it.

**Changing the art.** Edit `tool/sample_art.py` and run `python3 tool/sample_art.py` (Pillow and numpy); `--check` redraws in memory and fails if the committed files differ. The script has no randomness.

## Layout

Single column, mobile first. Content sits inside `MaxWidth` (720px) centered on wide browser windows. At 800px wide and up, the bottom NavigationBar becomes a NavigationRail on the left with the amber mic as its logo; below that, a bottom bar.

Spacing works on a 4px base: 4, 8, 12, 16, 20, 32. Screen gutters and card padding are 16px; poster headers and week headers use 20px; empty states 32px. Cards in a list are 10px apart. Lists leave 96px at the bottom so the floating Book a Show button never covers the last card.

Every screen has its own URL (go_router), and detail screens provide a back button that still works when opened from a link (`backButtonFor`, `leaveScreen`).

## Elevation & Depth

Flat. Cards, app bars, dialogs and the floating button have elevation 0. Depth comes only from tonal steps (stage black → surface → surface high) plus a 1px Stage Outline border. No drop shadows, glows or gradients anywhere in the system, including the Gold Records foil.

**Stage Grain.** The main tabs sit on a film grain (`StageGrain` in the tab shell, `GrainPainter`): fine Spotlight White specks at 5% with a sparser set at 8%, from one fixed 128pt tile built once from a fixed seed and repeated, so it never shimmers or changes between frames or runs. It is under a `RepaintBoundary`, so it is painted once and scrolling never repaints it. The tab screens keep their own Scaffold transparent so it shows through. Every `PosterSurface` carries the same grain. Detail screens, forms and dialogs stay on plain Stage Black.

**The Marked, Not Lit Rule.** To make something stand out, give it the one accent (amber) or its venue mark as an edge, never a fill, a glow or a shadow.

## Shapes

Soft, generous rounding, never sharp corners. Small art and thumbnails 4–8px; inputs, popup menus and the scrollbar 8–12px; cards 16px; poster headers, dialogs, chips and badges 20px; the Stage Button is a full pill (28px). Cards and dialogs carry a 1px Stage Outline border; filled fields do not.

## Components

### Buttons
Confident and loud for the one main action, quiet for the rest.
- **Stage Button (primary, `StageButton`):** flat Marquee Amber, pill shape (28px), 14px × 24px padding, Gold Ink Archivo 800 uppercase label tracked +1.2px (10.1:1), optional Gold Ink leading icon. Disabled is the same button at 50% opacity. One per screen at most.
- **Filled (secondary):** flat Stage Surface High with a 1px Stage Outline and Spotlight White Archivo 700 text (14.6:1), so amber stays the one main action on a screen.
- **Text and Outlined:** Marquee Amber text; outlined adds a Stage Outline border. Labels in sentence case, including app bar actions ("Save", not "SAVE").
- **Open in Spotify:** a filled button in Spotify Green with black text and icon, on the Show page only. The one place a brand color appears.
- **Floating action:** "Book a Show" extended FAB in flat amber with Gold Ink text, elevation 0, only on the Setlist tab (it is that tab's one amber button).

### Chips
- **Style:** Stage Surface High fill, Stage Outline border, 20px radius, Archivo 600 label in Spotlight White.
- **Selected:** amber fill with Gold Ink label. Used for Setlist filters and single choices in forms.
- **Segmented buttons:** same color logic (transparent unselected, amber with Gold Ink selected, outline border).
- **Choice tiles** (Book The Tour): selected is Stage Surface High with a 2px amber border and amber icon and check; the big number choices fill amber with Gold Ink type.

### Cards / Containers
- **Corner Style:** 16px.
- **Background:** Stage Surface with a 1px Stage Outline border, elevation 0.
- **Internal Padding:** 16px.
- **Section Card:** a Card with a Archivo Condensed title row (and optional trailing action), 12px gap, then content. Groups parts of forms and detail screens.

### Inputs / Fields
- **Style:** filled with Stage Surface High, 12px radius, no visible border at rest. The label floats inside the fill (an outline border would park it on the field's edge, so don't switch to outlined fields).
- **Focus:** 2px amber underline; floating label turns amber.
- **Error:** Material error color underline, 1px at rest and 2px focused.
- **Labels and hints:** House Lights Grey. Units go in the label or suffix: mi, mph, %, °F, ft.

### Navigation
- **Bottom bar (narrow) / side rail (800px+):** Stage Surface background; indicator is amber at 30% with the selected icon in Spotlight White, unselected icons House Lights Grey; labels Archivo 600 12px. Each tab has an outlined icon and a filled selected icon (for example `queue_music_outlined` → `queue_music` for the Setlist, `leaderboard_outlined` → `leaderboard` for The Charts, `inventory_2_outlined` → `inventory_2` for Backstage). Charts draw bars and lines in the venue marks (cyan Studio, magenta Live) and amber where a series needs one highlight (Headliners), flat, with no gradient fills (the Headliner line has a flat 12% amber wash under it), and planned values as dashed outlines. Tour phase bars keep their phase colors. New tabs follow the same outlined/filled pair.

### Icons
Material Icons only, no extra icon packs. Venue icons: `graphic_eq` for Studio Session, `landscape` for Live Show (via `iconFor(venue)`). Weather uses outlined icons where they exist (`wb_sunny_outlined`, `cloud_outlined`, `umbrella_outlined`) via `iconForConditions`. Music marks use `music_note` / `album` / `queue_music`. Icons on amber are Gold Ink; on a deep fill they are white; on the dark stage they use Spotlight White, House Lights Grey, amber, or the venue mark for venue icons. Badge icons 14px, inline marks 16–18px, nav default 24px.

### Poster Header (signature)
The top of main screens: a full-width flat Stage Surface block with a 1px Stage Outline, 20px radius, 20px padding, the grain, and the title in Archivo Condensed Display 48px white, optional white subline or chips below. Posters never fill with color.

Every poster-sized block (Poster Header, the Tour header, the Calendar, Crew, friend-page and invite posters, the Book The Tour preview, the planned Show poster) is a `PosterSurface`: flat Stage Surface, outline, `GrainPainter`. A Show poster adds its venue `mark` as a 5pt left edge (`EdgeMarkPainter`), sets its hero number (the miles) in amber (`titleColor`), and prints its venue art in that mark (`venuePrint: StageArt.printFor(venue)`), beside its type and never under it; see Imagery. The planned Show poster takes the venue mark, or amber on Opening Night. On the Tour and Charts the days to go are the amber hero figure.

**Gold Records foil** (`PosterSurface.foil`): flat Gold Mid, no outline, Gold Ink type, and printed halftone dots (`HalftonePainter`, Gold Deep at 20% on a 7px 45° screen, starting 40% across and growing toward the bottom-right). It is the one halftone left in the app.

### Show Card / Ticket Stub (signature)
A Setlist row styled as a ticket, cut with `TicketBorder`: 7px punched notches top and bottom where the stub meets the ticket, and a perforated tear line of 1.6px Stage Black holes every 7px between them. A 64px-wide `VenueStub` on the left: flat Stage Surface High with the venue mark as a 5pt left edge, the weekday (Archivo 800 12px uppercase) and the date number (Archivo Condensed 38px) in white, and the venue icon in its mark. To the right: the workout and venue line as a micro label with a 22px Feel Face, then miles (Archivo Condensed 30px, white), pace (Archivo Condensed 26px, amber) and time (Archivo Condensed 26px, grey) with tabular figures on one line (it scales down rather than wrapping on a long Headliner), effort in grey, and the Song of the Show with 22px album art (or a grey `music_note` mark).

### Feel Face
How a Show felt, never as emoji (they draw differently on web, iPhone and Android and look like cartoons next to the posters). A circle in one flat fill with a rounded Material sentiment face (74% of the circle) on top (`FeelFace.fills`, `FeelFace.faceOn`). The color warms with the feel: Rough night Teal Deep, Off key Violet Deep, Fine the Feel Fine grey, Good set Magenta Deep (all with a white face: 5.4, 7.1, 9.3 and 4.6:1), Encore! amber with a Gold Ink face (10.1:1). No two-stop blends. 22px on Show cards, 26px beside the label on the Show page, 44px in the Book a Show picker, where unpicked faces sit at 45% opacity and the picked one gets a 2px Spotlight White ring; the label below names the pick. Each picker face is one button with its label and selected state for screen readers.

### Venue Badge (signature)
An outlined pill (20px radius, 4px × 10px, 1.5px border in the venue mark, no fill) with a 14px icon and "STUDIO SESSION" or "LIVE SHOW" in Archivo 800 11px tracked +0.8px, icon and label in the mark (magenta 5.9:1, cyan 10.1:1 on Stage Surface). It reads the same on the stage, on cards and on posters.

### Stat Tile
Uppercase micro label in House Lights Grey (11px, 700, +1.2px) over a Archivo Condensed 26px value with tabular figures, for example "PACE" over "8:42 /mi".

### Empty States
One component, `EmptyStage`: a centered 56px House Lights Grey icon, a Archivo Condensed headline in caps ("NO SHOWS YET"), then one grey sentence (max 340px wide) that tells you what to do in tour words ("Book your first one and start the Setlist."), then at most one Stage Button. Leave the button off where the screen already has the action (the Setlist's floating Book a Show). Not in a card. Gold Records is the exception: its empty state is the list of records still to press, which teaches what each one is.

### Backstage Pass (account card)
The first card in Backstage, a Section Card titled "Backstage Pass". Signed out: one plain sentence on what the Pass does, then full-width 48px sign-in buttons: Sign in with Apple in Apple's own white-with-black style (above), Continue with Google as a filled (secondary) button. Signed in: an "ALL ACCESS" badge outlined in amber with amber text (venue-badge shape) as the card's trailing action, a 44px Magenta Deep avatar with the initial in Archivo Condensed, name in Archivo 700 and email in House Lights Grey, an overflow menu (Sign out, Delete account), then one sync line: an 18px outlined cloud icon in grey (`cloud_done_outlined`) or amber when offline (`cloud_off_outlined`), grey text ("Synced 5 min ago", "Offline. 2 changes wait on this device."), and a Sync now text button. Sign out and Delete account always confirm in a dialog; the destructive action uses the error color. On the Setlist, a guest with 3 or more Shows sees one dismissible card ("Get your Backstage Pass…") with an amber `badge_outlined` icon; it never returns once closed. Signed in, pulling down on the Setlist syncs.

### Song Picker
A bottom sheet ("SONG OF THE SHOW") with a search field and a plain list: 52px album art, the title in Archivo 700, artist and album in House Lights Grey. Each row ends with where the result came from, "Spotify" or "Apple Music", as plain Archivo 600 11px House Lights Grey text in sentence case: no logos, no brand colors, never louder than the song. While a picked Spotify song looks up its Apple preview, the sheet's 2px progress bar runs and further taps wait.

### Apple Health import
iPhone only; on web the card is not built at all. A Section Card titled "Apple Health" under the Backstage Pass: one sentence ("Bring in runs from your Apple Watch or iPhone as Shows.") and a full-width 48px filled "Import runs" button with a `favorite_border` heart, which shows a small spinner and "Checking Apple Health…" while it reads. Results open in a bottom sheet: a Archivo Condensed "NEW FROM APPLE HEALTH" headline, one grey line with the count and window, then one row per run (checkbox, the day in Archivo 700 with a Venue Badge on the right, miles / pace (amber) / time in Archivo Condensed with tabular figures, and "7:00 AM · Apple Watch" in grey), all checked, and one Stage Button "Add 3 Shows". Nothing new and no access use the Empty State layout inside the sheet with a grey hint naming Settings > Health > Data Access & Devices > Setlist Tracker, and a Done text button. The result is a snack bar ("3 Shows added to the Setlist.").

### Go Live and On Stage (GPS recorder)
iPhone only (`locationSourceProvider.available`); the website never shows it. On the Setlist, a quiet **Go Live** extended FAB sits above Book a Show: Stage Surface fill, 1px Stage Outline, Spotlight White label and `my_location` icon, so Book a Show stays the one loud action. While a run is going it turns into a status button with a 2px Neon Magenta outline and magenta label ("Live now", "Paused: back On Stage", "Book your Live Show").
- **On Stage** (`/live`, `lib/ui/live_show/on_stage_screen.dart`): app bar "ON STAGE". A Live-gradient `PosterSurface` with a `VenueBadge(onPoster: true)`, a status label (DOORS OPEN, LIVE NOW, PAUSED, SHOW OVER), the moving time in Archivo Condensed at 88px (scaled down to fit), then MILES, PACE NOW and MPH in white Headline numerals with tabular figures. Below it one quiet GPS line (an 18px icon and a sentence; amber only when it needs you), the route, a "The Numbers" card (average pace, elevation gain) and mile splits, newest first.
- **Controls** pin to the bottom on Stage Black: Go Live (the screen's one Gradient Button); while running, outlined Pause beside a filled End Show (tap asks, long press ends at once); while paused, Resume (Gradient Button) beside End Show; when over, a "Throw away" text button beside Book this Show. Buttons are 56px tall.
- **Route** (`RouteView`, `lib/ui/live_show/route_poster.dart`): no map tiles. Stage Black panel, 12px radius, 1px outline, faint 28px graph-paper grid in Stage Outline at 45%; the line in Neon Magenta 3.5px with round caps, broken at pauses; a 7px Spotlight White start ring; an amber 4px tick at each mile; the end as an amber dot (bigger while live). It echoes the Live venue print. On the Show page it sits in a "The Route" Section Card with MILE SPLITS rows (MILE n in Archivo 800, the split in Headline numerals, the fastest in amber).
- **Heart Rate** (Show page, iPhone, only when Health has readings): a Section Card with a Neon Magenta `favorite_border` mark, AVERAGE and MAX stat tiles in bpm, and one grey line that it stays on the iPhone and the Crew never sees it.

### The Calendar
A month at a time (`/calendar`, `?month=2027-03` opens a given month), opened from a white `calendar_month_outlined` icon button on the Setlist poster (beside the week line) and the Tour header (beside the Tour menu). The app bar says "THE CALENDAR" with a "Today" text button. Logic lives in `lib/logic/calendar.dart`; nothing is stored.
- **Poster:** a flat `PosterSurface` with the month name in Display caps, one white line "2026 · 8 Shows · 42.8 mi", and with a Tour a white ticket line "119 days to Opening Night". White chevron buttons ("Previous month", "Next month") page the months; swiping does too. Months run from the first Show's month to Opening Night's month (today's month without a Tour).
- **Grid:** weeks start on the Tour's week day (Tour weeks end on Opening Night, so a Sunday race gives Monday weeks), Monday without a Tour, so every row is one Tour week. Each row is a Stage Surface block (10px radius) with a 3px phase-light stripe on its left edge (`phaseColor`, half strength on a Rest Stop) and, on the right, the week's miles: done in amber Archivo 800 tabular over "/ 18 mi" in grey, "REST STOP" in amber micro caps under it. A Tour week with nothing logged shows only its plan ("17 mi"). When the squares would get narrower than "00.0" (large text), the totals move to a line under the row.
- **Day square:** the day number (Archivo 700 14px; today on a 24px amber disc in Gold Ink), then the marks: a 9px dot in the venue mark per Show, an open 9px ring per planned run (amber for a Headliner or Opening Night, 40% when skipped or missed), an amber `check_circle` once it's logged (the Tour tab's rule, `tourProgressProvider`), a 12px Gold Disc on a day a standing Gold Record was set, the amber ticket on Opening Night. Under them the miles (amber when run, grey when planned) and the planned run's short name ("Easy", "Tempo") when it fits the square, amber for a Headliner. Days of the neighboring months sit at 35%. A legend under the grid names every mark.
- **Day sheet:** tap a square for a bottom sheet titled with the day ("SUNDAY, NOVEMBER 22"), a grey line ("Today · Week 3 · Rehearsals · Rest Stop"), then the Tour runs (a 40px outlined ring with the workout icon, the title, "11.5 mi planned · Live Show", "Done · ran 11.5 mi" or a struck-through "Skipped") opening `/tour/show/:id`, each with a filled "Done as planned" button while it is today or past and not yet logged, then the Shows (a 40px Stage Surface High tile with a 4pt venue-mark edge and the venue icon in its mark, "Headliner · Live Show", miles · pace · time in amber) opening `/show/:id`.
- **Reading and size:** every square is one button with a spoken label ("Tuesday, March 3: Tempo 6 miles planned, done. Gold Record"), and each week's total is spoken in words ("Week 3, Rehearsals. 12.4 miles of 18 miles planned"). The grid's own text stops growing at 150% so it stays a grid (a deliberate cap like chart axes); the poster, sheet and spoken labels grow without limit.

### The Crew (friend sharing)
The fourth tab, "The Crew" (`groups_outlined` → `groups`), between The Charts and Backstage. Friends are your Crew; a cheer is an Encore.
- **Guests and local-only builds** get the Empty State: "JOIN THE CREW" with a "Go Backstage" Stage Button, or "THE CREW IS COMING" with no button.
- **First visit:** a Poster Header "THE CREW", a Section Card "Pick your stage name" (filled field, four avatar swatches, Stage Button "Join the Crew"), then three plain rows on how it works with amber 22px icons.
- **Crew Avatar:** a circle in one of the four deep shades (`crewColors`) with the initial in Archivo Condensed, white. 24px on a post, 40px in lists, 48px in the Crew strip, 56–64px on sheets and the invite poster (with a 3px white ring on a poster).
- **Home:** a flat `PosterSurface` with "THE CREW", one white line ("3 runners in your Crew. They see every Show you log.", or "They see the Shows you shared." while a runner from before the change hasn't OK'd it) and the Settings button in its corner (see Settings). Below it the "Your Crew" Section Card: a horizontal strip of avatar chips at least 76px wide that grow with text size (name in Archivo 600, days to Opening Night in amber tabular figures), "Enter a code" as the text-button action, and the screen's one Stage Button, "Invite a friend". Then a "LATEST SHOWS" micro label and the feed. Runners who joined before the Crew showed everything first see a one-time Section Card "Your Crew sees more now" with a filled "Sounds good" and a "Not now" text button.
- **Crew post:** at 150% text the "2 hr ago" moves under the name, which never truncates first; the name is its own 44pt button for screen readers. The Show Card ticket (`TicketBorder`, `VenueStub` with the venue-mark edge), with a signature row on top (24px avatar, stage name in Archivo 700 or "You", grey "2 hr ago", an overflow menu), the same workout line and Archivo Condensed numbers, the Song of the Show with 36px album art (or its Song Sleeve) and the song note on its own grey line (up to 2 lines), the workout line with a 22px Feel Face, "Effort 7/10 · Good set" in grey, a wrap of 16px-icon facts in Archivo 600 13px (route · surface, climb, weather, Track summary for Studio Sessions, Gear), Gold Records (friend page only) as small Stage Surface High pills with an amber outline and an amber `album` disc, notes in body text (over 4 lines get a More/Less button), and the Encore text button (`celebration_outlined` → `celebration` in amber when you cheered, with a short flat amber pop, skipped when animations are off), followed by a separate tappable count ("3 Encores", at least 44pt) that opens who gave them. On your own post the Encore line is a grey tappable count instead ("3 Encores", or "No Encores yet").
- **Invite sheet:** "INVITE TO THE CREW", one grey sentence, the code in Archivo Condensed Display with wide tracking on a Stage Surface High block, then a filled "Send invite" (system share sheet, falls back to copy) and an outlined "Copy link". Codes are 8 characters shown as "K7Q9 MX4P".
- **Join screen** (`/crew/join/CODE`): a flat poster with the inviter's avatar and "MAYA INVITES YOU TO THE CREW", what joining means in one white sentence, then the Stage Button "Join the Crew" and a "Not now" text button. Expired, own and already-joined invites use the Empty State.
- **On a Show:** your Crew sees every Show you log. The Book a Show form ends with a Section Card "The Crew" holding one "Keep off the Crew" switch (signed-in runners with a stage name, or a Show already kept off); the Show page shows a grey `visibility_off_outlined` line "Kept off the Crew. Only you see this Show." under the poster.
- **Friend page** (`/crew/mate/:userId`): a flat poster (56px avatar with a white ring, stage name in Display, Shows and miles in white), a "The Tour" Section Card (their Tour poster with this week's "2 of 5 Shows · 12.4 mi", then a filled "Book a Tour featuring Maya" button, or an amber `groups` line "Co-headlining Spring 2027 Tour" when your Tours share an Opening Night), a "Gold Records" card computed from their Setlist (at most 3 rows, one per Show, week and month records that only repeat the Longest Show dropped, no card under 5 Shows), then their Setlist as Crew posts without the signature avatar. The mate sheet from the Crew strip shows the same Tour card and a "See Maya's Setlist" outlined button.
- **Tour tab:** one Card per co-headlining Crew mate under the Tour header: 40px avatar, a "FEATURING" micro label, the name in Archivo 700 16px, then one line of news (this week's "2 of 5 Shows · 12.4 mi so far", or their latest Show), opening their page.
- **Tour invites:** ask Crew mates onto your Tour. Book The Tour's preview has a "Bring your Crew" card under the phase summary (signed-in runners with a stage name only): one grey sentence, then a checkbox row per Crew mate (40px avatar, name in Archivo 600); a mate already racing that Opening Night, or the one it's booked featuring, is a disabled row with a grey "Co-headlining" or "Featuring" line. With no Crew yet it holds an "Invite a friend" text button that opens the invite sheet. Invites go out once the Tour is booked (the app syncs it first), with a snackbar "Invite sent to Maya." after "… booked." The Tour header's options menu adds "Invite to this Tour" (hidden after Opening Night or without a stage name), opening a sheet: "INVITE TO THIS TOUR", the Tour name and "Half Marathon · Sat, Feb 20", the same checkbox rows, and a filled "Send invite" / "Send 2 invites". On The Crew tab, a "TOUR INVITES" micro label and one Card per invite sit above the "Your Crew" card: 40px avatar, "**Ryan** invited you on the **Spring 2027 Half Tour**", the race line in grey, the countdown in amber tabular figures, then a "Not this time" text button and a filled "Join the Tour" (Book The Tour featuring the sender). Invites for a race you already co-headline, or one that has passed, don't show.
- **Book The Tour, race question:** "What are you racing?" with four tiles led by the miles (3.1 / 6.2 / 13.1 / 26.2) in Archivo Condensed 26px tabular with a small "MI" label, then the race name and week range. Booking from a friend starts at the goal ("Question 1 of 7") under one summary row ("Half · Sat, Feb 20 · with Maya") and a "Change race" button. Hidden when signed out or nobody matches.
- Remove, Block and Report always confirm; Block and Report use the error color. Bottom sheets open over the nav bar.

### Seen by, Encores and Shout-outs
Who cheered, who saw it and what they said, kept quiet: these sit under a Crew post's Encore row and never compete with the Show itself.
- **Encores show who.** The Encore toggle stays the toggle. The count beside it ("3 Encores", or a small count next to the toggle on someone else's post) is its own button that opens the audience sheet on the Encores tab: a row per person, 40px Crew Avatar, stage name in Archivo 600, grey relative time ("2 hr ago"). People outside your Crew are never named, only counted: "and 2 more outside your Crew". Tapping a Crew mate opens their page. Turning an Encore on gets one small stage-light pop on the `celebration` icon, skipped when animations are off.
- **Seen by is for the Show's owner only.** On your own posts, under the Encore row, one grey line in body small with a `visibility_outlined` 16px icon: "Seen by Maya, Sam +2" (up to three names, latest first, "+N" for the rest). Hidden when nobody has seen it; never on someone else's post, never a count anywhere else. Tapping it opens the audience sheet on the Seen by tab, where Encore givers carry the amber `celebration` icon. A view is recorded when a Crew mate's card is at least half on screen for about a second, or they open the Show. Settings → The Crew has the switch "Let my Crew know when I've seen their Shows" (on by default; off: "your views aren't recorded, and the ones already kept are forgotten").
- **Shout-outs** are short comments (1 to 280 characters) from the owner and their Crew. Next to the Encore button a text button with `chat_bubble_outline`: "Shout-out", or "3 Shout-outs". It opens a tall bottom sheet, oldest first: 40px avatar, name in Archivo 600 with a grey time, the body in body text. The composer sits at the bottom above the keyboard ("Give a Shout-out…", a counter only near the limit, Send disabled while empty). Long-press or the row menu: Delete (the writer or the Show's owner, confirms first) and Report (anyone but the writer, the Show report sheet, error color). A reported Shout-out leaves your view at once. Empty: "No Shout-outs yet. Be the first."
- **Quiet styling:** grey text and outlined icons, no badges, dots or bold counts; amber only for an Encore you gave. Loading, error and empty states use the Crew voice ("Couldn't reach the Crew.").

### App Bars
Detail screens name the kind of screen ("THE SHOW", "TOUR DATE · WEEK 3", "BOOK A SHOW", "EDIT SAVED MIX"); the poster below carries the content. Screens whose poster already names them (Gold Records, The Record Wall) leave the app bar title empty.

### Settings
`/settings`, a detail screen over the tabs (app bar "SETTINGS", back button). Opened from the top-right corner of every tab's poster: a 48pt button (tooltip "Settings") holding your Crew picture at 34px in a 2px white ring, your Backstage Pass initial when you have no stage name yet, or a white `person_outline` when signed out. The tab shell sets it once (`PosterCornerAction`); `PosterHeader` and the Crew and Tour posters place it after their own actions, top-aligned with the title. On the Crew poster it replaces the old `tune` Crew settings button and sheet.
- One column of Section Cards, in this order: **Your profile** (a 64px avatar beside the stage name in Headline, then "Picture" in Archivo 700, the badge grid, the photo buttons, a divider, and the stage name form with the four color swatches and the screen's one Stage Button, "Save name and color"); **The Crew** (signed in with a stage name only: a "Keep new Shows off the Crew" switch, the "let them see every Show" opt-in while it's pending, the "Let my Crew know when I've seen their Shows" switch, and the blocked runners with Unblock); **The Tour** (Headliner day and Studio or Live as filled dropdowns; "Ask me" leaves the quiz unanswered); **Song of the Show** (a Spotify / Apple Music segmented button); **Apple Health** (iPhone only: an import switch that hides the Backstage card when off); the **Backstage Pass** card itself; **About** (Privacy policy and Support rows with an `open_in_new` mark, the training disclaimer, the version in tabular figures).
- Signed out or local-only, Your profile is one grey sentence pointing at the Backstage Pass below; nothing else changes.
- Switches use the Book a Show form's off state (grey outline and thumb) so "off" reads on a card.
- Preferences stay on the device (`AppSettings` behind `SettingsStore`, Sembast today). With Apple Music picked, the Show page leads with a filled "Open in Apple Music" (the song's link, else Apple Music search) and keeps the green Spotify button second.

### Crew pictures
A runner's picture is their photo, else a drawn badge, else their initial, always on their avatar color (`CrewAvatar` picks; the name is always said beside it, so the picture is excluded from semantics).
- **Badges:** 24 tour-art marks (mic, vinyl, guitar pick, running shoe, headphones, drumsticks, lightning, star, ticket, amp, cassette, setlist, laurel, medal, stopwatch, mountain, flame, wave, moon, sun, heart, crown, music note, spotlight), one white mark at 58% of the circle. Most are Material Icons; the seven Material has no shape for are drawn in `avatar_badges.dart` on the same 24-unit grid, filled, never outlined. No stock or brand art.
- **Badge grid:** 44px avatars in a wrap, your initial first, then the badges, each one button with its name ("Crown badge") and selected state; the pick gets the swatches' 2px Spotlight White ring. With a photo up, no badge is ringed, and picking one asks first because the photo comes off.
- **Photo:** "Upload a photo" (outlined, `add_photo_alternate_outlined`) opens the library; the device takes the middle square, makes it 256px JPEG under 64 KB, and shows it in a 120px circle in a "Use this photo?" dialog before it goes up. "Change photo" and a grey "Remove photo" follow. The photo loads under sign-in, so the badge or initial shows until it arrives and stays if it never does. Photos are the one place a picture that isn't screen-printed appears, and only because a runner chose it; they are never used as art.
- **Report photo** sits under Block on a Crew mate's sheet when they have a photo, in the error color, and uses the Show report sheet ("REPORT THIS PHOTO").

## Do's and Don'ts

### Do:
- **Do** take every color from `StageColors` and every font from `StageFonts`; add new tokens there (and here) instead of inline hex values.
- **Do** keep every surface flat: Stage Black, Stage Surface or Stage Surface High, with grain on tabs and posters.
- **Do** make amber the one accent (with Gold Ink on it), and check every new text pairing reaches 4.5:1.
- **Do** use `markFor(venue)` and `iconFor(venue)` whenever something belongs to a Studio Session or Live Show, as an edge, outline, dot, icon or label.
- **Do** set stats in Archivo Condensed with tabular figures, and label them with an uppercase tracked micro label.
- **Do** use the tour words from the Overview in every title, button, empty state and error message.
- **Do** show miles, mph, min/mi, ft and °F.
- **Do** theme any new Material widget onto the stage surfaces with surface tint off.
- **Do** keep layouts single column inside `MaxWidth` and test at phone width first.

### Don't:
- **Don't** add a light theme or light surfaces.
- **Don't** put white text on the bright shades (#FF4D9A, #FFB020, #22D3EE, #8B5CF6), or use Blacklight Violet for small text.
- **Don't** use a gradient, glow or fade of any kind (linear, radial, sweep, mesh, `withOpacity` halos); a test fails on them.
- **Don't** fill a poster, header, stub, badge or button with a venue color; a venue color is a mark only.
- **Don't** use magenta (or any color but amber) for actions, links, focus, selection or progress.
- **Don't** add halftone anywhere but the Gold Records foil; the texture is grain.
- **Don't** add drop shadows or raised elevation; use tone and the outline instead.
- **Don't** swap the venue marks or invent a new accent for one screen.
- **Don't** load fonts from a CDN or `google_fonts` at runtime; bundle them in `assets/fonts` so type works offline and on iOS.
- **Don't** switch inputs to outlined borders.
- **Don't** use generic fitness words ("workout log", "run history", "PRs", "shoes") in the UI.
- **Don't** use more than one Stage Button (or amber filled button) on a screen.
- **Don't** add photos, stock art, bokeh, crowds or light effects, or a picture that could pass for a real album cover; the art is screen-printed in the stage inks (see Imagery).
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

