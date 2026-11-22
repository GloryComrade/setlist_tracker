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
typography:
  display:
    fontFamily: "BebasNeue"
    fontSize: "48px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "0.6px"
  headline:
    fontFamily: "BebasNeue"
    fontSize: "30px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "0.6px"
  title:
    fontFamily: "BebasNeue"
    fontSize: "24px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "0.6px"
  body:
    fontFamily: "Inter"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.43
  label:
    fontFamily: "Inter"
    fontSize: "11px"
    fontWeight: 800
    letterSpacing: "1.2px"
  numeral:
    fontFamily: "BebasNeue"
    fontSize: "26px"
    fontWeight: 400
    lineHeight: 1
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

Density is moderate. It is a training log people open on a phone right after a run, often sweaty and in a hurry, so screens are scannable stacks of cards with large numbers, not dashboards. Expression lives in the gradients, the poster type, and the tour words; everything else (forms, menus, pickers) is plain Material behavior on the stage's own surfaces, so it feels familiar on web and later on iPhone.

Every label speaks the tour language. A run is a Show, history is the Setlist, a treadmill run is a Studio Session, an outdoor run is a Live Show, a treadmill segment is a Track, a preset is a Saved Mix, the plan is The Tour, the long run is the Headliner, race day is Opening Night, PRs are Gold Records, shoes are Gear. Plan phases are Rehearsals, On the Road, Headline Leg and Soundcheck, and a cutback week is a Rest Stop. Units are always miles, mph, min/mi and °F.

**Key Characteristics:**
- Dark mode only: near-black stage (#0B0A12) with slightly lifted card surfaces.
- Color comes from stage-light gradients, not flat brand blocks.
- Bebas Neue for headlines and big numbers, Inter for everything you read.
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

### Gradients
All run top-left to bottom-right, built only from the deep shades:
- **Live gradient:** Magenta Deep → Orange Deep. Live Show badges, ticket stubs, Live posters.
- **Studio gradient:** Violet Deep → Teal Deep. Studio Session badges, stubs, posters.
- **Headline gradient:** Violet Deep → Magenta Deep → Orange Deep. Screen poster headers and the primary Gradient Button.

### Named Rules
**The Two Twins Rule.** Each light has a bright twin and a deep twin. Bright shades (magenta, amber, cyan) are for text and marks on the dark stage. Deep shades are for fills that carry white text. Never put white text on a bright shade or bright text on a deep fill. Every white-on-fill pairing must stay at 4.5:1 or better.

**The Venue Color Rule.** Warm (magenta/orange) always means Live Show and cool (violet/teal) always means Studio Session. New screens reuse `gradientFor(venue)` rather than picking a gradient by taste.

**The Dark Stage Rule.** There is no light theme. Every Material surface (dialogs, sheets, menus, pickers, snack bars) is themed onto the stage colors with surface tint off; no default warm-grey Material tints may leak through.

## Typography

**Display Font:** Bebas Neue (bundled, `assets/fonts`, SIL OFL)
**Body Font:** Inter 400 / 600 / 700 / 800 (bundled, SIL OFL)

**Character:** a condensed, all-caps tour-poster face for anything shouted, paired with a neutral, highly legible sans for anything read. Both are bundled so type works offline and on iOS with no web font fetch.

### Hierarchy
- **Display** (Bebas Neue 400, 64 / 48 / 38px, line-height 1.0, +0.6px): poster headers ("THE SETLIST") at 48px; the day number on ticket stubs at 38px.
- **Headline** (Bebas Neue 400, 34 / 30 / 26px, 1.0): empty-state titles and hero numbers. Miles on a Show card at 30px, pace and time at 26px, stat values at 26px.
- **Title** (Bebas Neue 400, 24px, 1.0): app bar titles and Section Card titles.
- **Body** (Inter 400, Material default 14–16px): notes, descriptions, form text. Song lines use Inter 600.
- **Label** (Inter 700–800, 11–12px, +0.8–1.2px tracking, UPPERCASE): micro labels above stats, week headers, venue badges, the workout type line on Show cards, Gradient Button text.

### Named Rules
**The Poster Numbers Rule.** Distances, paces and durations are shown in the display face with tabular figures (`StageFonts.tabular`) so columns line up. Never set a stat in Inter at body size when it is the point of the card.

**The Shout Sparingly Rule.** Uppercase is for Bebas headlines and tiny tracked labels only. Body copy, buttons other than the Gradient Button, and helper text stay in sentence case.

## Layout

Single column, mobile first. Content sits inside `MaxWidth` (720px) centered on wide browser windows. At 800px wide and up, the bottom NavigationBar becomes a NavigationRail on the left with the magenta mic as its logo; below that, a bottom bar.

Spacing works on a 4px base: 4, 8, 12, 16, 20, 32. Screen gutters and card padding are 16px; poster headers and week headers use 20px; empty states 32px. Cards in a list are 10px apart. Lists leave 96px at the bottom so the floating Book a Show button never covers the last card.

Every screen has its own URL (go_router), and detail screens provide a back button that still works when opened from a link (`backButtonFor`, `leaveScreen`).

## Elevation & Depth

Flat. Cards, app bars and dialogs have elevation 0. Depth comes from tonal steps (stage black → surface → surface high) plus a 1px outline border, and from the gradients, which read as light rather than shadow. No drop shadows anywhere in the system.

**The Lit, Not Lifted Rule.** To make something stand out, light it (a gradient fill or a bright accent) instead of raising it with a shadow.

## Shapes

Soft, generous rounding, never sharp corners. Small art and thumbnails 4–8px; inputs, popup menus and the scrollbar 8–12px; cards 16px; poster headers, dialogs, chips and badges 20px; the Gradient Button is a full pill (28px). Cards and dialogs carry a 1px Stage Outline border; filled fields do not.

## Components

### Buttons
Confident and loud for the one main action, quiet for the rest.
- **Gradient Button (primary):** headline gradient, pill shape (28px), 14px × 24px padding, white Inter 800 uppercase label tracked +1.2px, optional white leading icon. Disabled is the same button at 50% opacity. One per screen at most.
- **Filled:** Magenta Deep with white Inter 700 text.
- **Text and Outlined:** Neon Magenta text; outlined adds a Stage Outline border.
- **Floating action:** "Book a Show" extended FAB in Magenta Deep with white Inter 800 text, only on the Setlist tab.

### Chips
- **Style:** Stage Surface High fill, Stage Outline border, 20px radius, Inter 600 label in Spotlight White.
- **Selected:** Magenta Deep fill with white label. Used for Setlist filters and single choices in forms.
- **Segmented buttons:** same color logic (transparent unselected, Magenta Deep selected, outline border).

### Cards / Containers
- **Corner Style:** 16px.
- **Background:** Stage Surface with a 1px Stage Outline border, elevation 0.
- **Internal Padding:** 16px.
- **Section Card:** a Card with a Bebas title row (and optional trailing action), 12px gap, then content. Groups parts of forms and detail screens.

### Inputs / Fields
- **Style:** filled with Stage Surface High, 12px radius, no visible border at rest. The label floats inside the fill (an outline border would park it on the field's edge, so don't switch to outlined fields).
- **Focus:** 2px Neon Magenta underline; floating label turns Neon Magenta.
- **Error:** Material error color underline, 1px at rest and 2px focused.
- **Labels and hints:** House Lights Grey. Units go in the label or suffix: mi, mph, %, °F, ft.

### Navigation
- **Bottom bar (narrow) / side rail (800px+):** Stage Surface background; indicator is Magenta Deep at 35% opacity; labels Inter 600 12px. Each tab has an outlined icon and a filled selected icon (for example `queue_music_outlined` → `queue_music` for the Setlist, `inventory_2_outlined` → `inventory_2` for Backstage). New tabs follow the same outlined/filled pair.

### Icons
Material Icons only, no extra icon packs. Venue icons: `graphic_eq` for Studio Session, `landscape` for Live Show (via `iconFor(venue)`). Weather uses outlined icons where they exist (`wb_sunny_outlined`, `cloud_outlined`, `umbrella_outlined`) via `iconForConditions`. Music marks use `music_note` / `album` / `queue_music`. Icons inside gradient fills are white; on the dark stage they use Spotlight White or a bright accent. Badge icons 14px, inline marks 16–18px, nav default 24px.

### Poster Header (signature)
The top of main screens: full-width block in the headline gradient (or a venue gradient on a Show), 20px radius, 20px padding, title in Bebas Display 48px white, optional white subline or chips below.

### Show Card / Ticket Stub (signature)
A Setlist row styled as a ticket: a 64px-wide venue-gradient stub on the left with the weekday (Inter 800 12px uppercase), the date number (Bebas 38px) and the venue icon, all white. To the right: the workout and venue line as a micro label with the feel emoji, then miles (Bebas 30px, white), pace (Bebas 26px, amber) and time (Bebas 26px, grey) with tabular figures, effort in grey, and the Song of the Show with 22px album art.

### Venue Badge (signature)
A small pill (20px radius, 4px × 10px) in the venue gradient with a 14px white icon and "STUDIO SESSION" or "LIVE SHOW" in white Inter 800 11px, tracked +0.8px.

### Stat Tile
Uppercase micro label in House Lights Grey (11px, 700, +1.2px) over a Bebas 26px value with tabular figures, for example "PACE" over "8:42 /mi".

### Empty States
A centered icon, a Bebas headline in caps ("NO SHOWS YET"), then one grey sentence that tells you what to do in tour words ("Book your first one and start the Setlist.").

## Do's and Don'ts

### Do:
- **Do** take every color from `StageColors` and every font from `StageFonts`; add new tokens there (and here) instead of inline hex values.
- **Do** use the deep shades (#E0157A, #C2410C, #6D28D9, #0E7490) for any fill with white text, and check new pairings reach 4.5:1.
- **Do** use `gradientFor(venue)` and `iconFor(venue)` whenever something belongs to a Studio Session or Live Show.
- **Do** set stats in Bebas with tabular figures, and label them with an uppercase tracked micro label.
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
