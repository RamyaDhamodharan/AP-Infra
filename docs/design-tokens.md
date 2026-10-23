# Genworx AP Design Tokens

Source of truth: `AP-Frontend/src/styles/modern.css`. Keep colors, type, spacing, shape, and motion values in that token block.

## Color

| Token | Value | Use |
| --- | --- | --- |
| Navy | `#243A5E` | Primary text, links, icons, and navigation |
| Navy Dark | `#1F2A37` | Sidebar hover |
| Orange | `#FF6F3C` | Primary fills, focus accents, active bars, and progress |
| Orange Hover | `#E95E00` | Primary hover fill |
| Warm White | `#F9F9F7` | Flat page background and input fill |
| Soft Peach | `#FFD6C2` | Brand tint |
| Peach Light | `#FFF4EF` | Selected and hover surfaces; warning tint |
| Muted Blue | `#4F79A7` | Information status |
| Success | `#2BB673` | Healthy status |
| Warning | `#F5A623` | Attention status |
| Error | `#E5484D` | Blocked status |
| Border | `#DDDDDD` | Borders and chart gridlines |

Chart sequence: `#243A5E`, `#FF6F3C`, `#2BB673`, `#4F79A7`, `#CCA45E`, `#DDDDDD`.
Status text uses the specified darker semantic values. Status backgrounds are small tints derived from their status color; warning uses Peach Light.

Secondary text uses Navy at 72% opacity to meet WCAG AA on Warm White. The requested 65% Navy opacity composites to approximately 4.1:1 on Warm White, below the 4.5:1 body-text requirement, so the rendered token uses the darker AA-safe value.

## Type

- Poppins 400/500/600/700 for headings, controls, navigation, and labels.
- Lato 400/700 for body copy and table cells.
- Page title 32/38 600; section title 24/30 600; body 15/24 400; body-large 18/29 400; caption 12/16 600.
- Amounts, dates, and counts use tabular numerals.
- Login brand panel: H1 60/62 700 and H2 44/50 600.

## Shape, spacing, and motion

- Square corners throughout. Only status pills and badges, and the top-bar primary CTA, use a 999px radius.
- 1px `#DDDDDD` borders. No shadows, gradients, or blur.
- Spacing scale: 4, 8, 12, 16, 24, 32, 48, 64px.
- Motion: 150ms ease, 250ms ease-out, and 650ms `cubic-bezier(.16,1,.3,1)`. Respect reduced-motion preferences.
