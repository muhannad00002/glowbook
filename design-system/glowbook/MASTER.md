# Glowbook — Design System (Master)

Source of truth for the Flutter theme in `app/lib/core/theme/`. Screens read tokens from
`context.colors`, `context.text`, `context.glow`, `Space`, `Radii`, `Motion` — never raw values.

## Direction

Cute, premium, elegant; feminine without being childish. **Soft UI Evolution** style (clearer
shadows than neumorphism, 4.5:1 text contrast). Pink is an accent, never the room.

> The design-system generator suggested an all-pink palette (#EC4899 / #FDF2F8). Rejected per the
> brief ("avoid making everything pink") in favour of the neutral + rosewood palette below.
> Kept from it: the style and the Playfair Display / Inter pairing.

## Colour

| Token | Light | Dark | Use |
|---|---|---|---|
| background | `#FAF7F4` porcelain | `#151217` | scaffold |
| surface | `#FFFFFF` | `#1E1A21` | cards |
| ink / onSurface | `#2A2330` | `#F3ECEF` | text |
| muted | `#6E6470` | `#B9AEB7` | secondary text (≥4.5:1) |
| primary | `#8E4B61` rosewood | `#E4A9BB` blush | CTAs, selection |
| primaryContainer | `#F4E3E8` | `#5C3042` | chips, pills, highlights |
| secondary | `#8A5E3B` champagne | `#E3BE98` | ratings, money accents |
| tertiary | `#4F7265` sage | `#9CC3B4` | availability, success tints |

Status colours (fg/bg, both themes) live in `GlowColors`: pending amber, confirmed rosewood,
arrived lavender, in-service teal, completed sage-green, cancelled grey, no-show rose.
Status is never colour-only: every chip has an icon + label.

Gradients: `heroGradient` (blush → champagne → sage mist) for headers; `cardGradient` (rosewood)
for the "Next up" card. Soft shadow `#4A2130 @ 10%`, blur 20, y 8.

## Typography

| Role | Latin | Arabic |
|---|---|---|
| Display / headlines | Playfair Display 600 | Noto Naskh Arabic 600 |
| Body / UI | Inter 400–600 | IBM Plex Sans Arabic 400–600 |

Body 14.5–16px, line-height 1.45 (+0.15 for Arabic).

## Space, shape, size

4dp rhythm: 4 · 8 · 12 · 16 · 24 · 32 · 48. Gutters 16 / 24 / 32 / 40 by width.
Radii: 10 · 16 · 22 (cards) · 28 (sheets) · pill (buttons, chips).
Touch targets ≥ 48dp. Buttons 52–54dp tall, stadium.

## Layout

< 700px: floating bottom bar (≤ 5 items, "More" sheet for the rest) · 700–1100: rail · ≥ 1100: sidebar.
Content max width 1240 (reading 720).

## Motion

`Motion.of(context)` → fast 150ms · medium 260ms · slow 420ms · stagger 40ms/item.
Curves: easeOutCubic (standard), easeInOutCubicEmphasized, easeOutBack (pops).
**Reduced motion:** every duration collapses to zero via `MediaQuery.disableAnimations`.

Components: `AnimatedButton` (press-scale → breathing dots → check), `AnimatedSuccess`
(ring + check + petal burst), `AnimatedEmptyState` (floating illustration),
`AnimatedBookingCard`/`StaggeredEntrance`, `AnimatedCalendarTransition` (direction-aware,
RTL-aware), `AnimatedBottomNavigation` (gliding pill), `AnimatedPageTransition`
(fade-through, shared-axis, rise), `AnimatedCounter`, `ShimmerLoading`. No spinners.

## Illustration

`GlowIllustration` — CustomPainter spot art (mirror, calendar, bell, lipstick, brush, sparkles),
theme-coloured, no image assets. Salon covers without photos get a seeded gradient + monogram.
No emoji as icons (emoji only inside message copy).
