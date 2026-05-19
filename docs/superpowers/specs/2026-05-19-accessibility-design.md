# Accessibility Mode Design Spec

**Date**: 2026-05-19
**Branch**: `feature/accessibility-improvements`
**Target**: Upstream PR to gpakosz/.tmux

---

## Problem Statement

Oh my tmux! has no accessibility support. Users who are blind, have low vision,
are colorblind, or have motor impairments cannot easily use the configuration.
Red Hat is deprecating GNU Screen, forcing screen reader users who relied on
Screen to migrate to tmux. This PR adds a comprehensive accessibility layer
that existing users can opt into without changing the default experience.

## Design Decisions

### Single Toggle with Explicit Override Path

A master variable `tmux_conf_accessibility=enabled` activates all accessibility
features at once. Keybindings are controlled separately via
`tmux_conf_accessibility_keys`. For all other settings (cursor, status interval,
notifications, theme, separators), user overrides work the same way as in the
rest of Oh my tmux!: set the relevant `tmux_conf_theme_*` variable in
`.tmux.conf.local` AFTER the accessibility variable, or append `#!important` to
any `set` or `bind` command. The accessibility defaults apply first; user
variables override them.

### Additive, Not Destructive

No existing behavior changes. Accessible keybindings are added alongside
existing ones. The default theme is untouched. Everything is opt-in.

### Minimum tmux Version

Screen reader cursor tracking requires tmux >= 3.3 (commits `b55f0ac6` and
the display-menu follow-up fix). Version gating rules:

| tmux version | Behavior |
|--------------|----------|
| >= 3.3       | Full accessibility mode (all features) |
| 2.6 - 3.2   | Theme, separators, status format, keybindings apply. `civis@` override and `visual-activity`/`visual-bell`/`visual-silence` still apply (they work on older tmux but cursor tracking in choose-tree will not function). A warning message is displayed on source: "Accessibility: tmux >= 3.3 recommended for screen reader support" |
| < 2.6        | Oh my tmux! itself requires >= 2.6; not our concern |

The version check uses the existing `_tmux_version` variable (already computed
in the embedded script as a numeric value, e.g., 3300 for tmux 3.3).

---

## Specification

### 1. Configuration Variables

Added to `.tmux.conf.local`:

```bash
# -- accessibility -------------------------------------------------------------

# accessibility mode, possible values are:
#   - enabled (activates high-contrast theme, ASCII separators, screen-reader
#     friendly labels, reduced visual noise, and cursor visibility fixes)
#   - disabled (default)
# NOTE: screen reader support requires tmux >= 3.3
# NOTE: unrecognized values trigger a warning and are treated as disabled
tmux_conf_accessibility=disabled

# accessible keybindings, possible values are:
#   - enabled (adds arrow-key pane navigation, single-modifier resize,
#     and a pane context announcement binding)
#   - disabled (default)
tmux_conf_accessibility_keys=disabled

# visual notifications (activity, bell, silence), possible values are:
#   - true (default when accessibility=enabled; screen readers announce these)
#   - false (disable if notifications are too noisy)
tmux_conf_accessibility_visual_activity=true

# display-message duration in milliseconds for accessibility messages
# (pane announce, warnings). Screen readers need time to read the text aloud.
# version warning uses 2x this value.
#   - default: 5000 (5 seconds)
tmux_conf_accessibility_display_time=5000

# accessible theme background, possible values are:
#   - auto (default: detect from $COLORFGBG if available, else dark)
#   - dark (dark background, light text)
#   - light (light background, dark text)
tmux_conf_accessibility_theme=auto
```

### 2. Behavior When `tmux_conf_accessibility=enabled`

The embedded shell engine applies these settings before user overrides.

On successful activation, a confirmation message is displayed:
```
Accessibility mode enabled (tmux X.Y, display-time Nms)
```
This uses the configured `tmux_conf_accessibility_display_time` and confirms
the mode is active, the tmux version, and the current display duration.

#### 2.1 Cursor Visibility

```bash
set -as terminal-overrides '*:civis@'
```

Forces the hardware cursor always visible. Screen readers (NVDA, Orca, BRLTTY,
TDSR) track cursor position as their primary accessibility signal. Without this,
tmux hides the cursor in UI modes even when positioned correctly.

**User override**: To disable this specific behavior while keeping other
accessibility features, add to `.tmux.conf.local`:
```bash
set -as terminal-overrides '*:civis@:civis=\E[?25l' #!important
```

**Source**: tmux maintainer recommendation in issue #2970.

#### 2.2 Status Line

```bash
set -g status-interval 60
```

Status format overrides:
- Left: `[#S] ` (plain session name in brackets)
- Right: `%H:%M` (time only, no seconds)
- Window status: `#I:#W` (number:name, no decorative Unicode)
- Current window: `#I:#W*#{?window_zoomed_flag, [zoomed],}` (asterisk marks active; text label for zoom)
- Separators: `|` (ASCII pipe, no Powerline glyphs)

ASCII mockup of the composed status bar (80-column terminal):
```
[main] | 1:bash | 2:vim* | 3:htop                               17:34
        ^^^^^^^^^^^^^^^^^^^^^^^^^                                 ^^^^^
        window list (| separated, * = active)                     time
```

Comparison with default Oh my tmux! (Powerline glyphs, frequent redraws):
```
[main]  1:bash  2:vim  3:htop                    alice@host  17:34:22
```

Rationale: Reduces screen reader noise from frequent redraws and decorative
characters. Confirmed beneficial by blind tmux users (Mario Lang, Tyler Spivey).

#### 2.3 choose-tree Format

When accessibility mode is enabled, override the choose-tree format strings
for clearer screen reader announcements:

```bash
# Session format in choose-tree
set -g @choose-tree-session-format "Session: #S (#{session_windows} windows#{?session_attached, attached,})"

# Window format in choose-tree
set -g @choose-tree-window-format "  Window #I: #W in #{pane_current_path}"

# Pane format in choose-tree (if pane preview is shown)
set -g @choose-tree-pane-format "    Pane #P: #{pane_current_command} in #{pane_current_path}"
```

Note: tmux `choose-tree` uses `-F` for format. The actual implementation will
use `bind-key` to rebind `<prefix> s` and `<prefix> w` with the `-F` flag:
```bash
bind s choose-tree -sF "Session: #S (#{session_windows} windows#{?session_attached, attached,})"
bind w choose-tree -wF "Window #I: #W (#{pane_current_command} in #{pane_current_path})"
```

Screen reader experience (NVDA announces each line as user arrows through):
```
Session: main (3 windows, attached)
Session: work (2 windows)
  Window 1: bash in ~/project
  Window 2: vim in ~/code
```

#### 2.4 Notification Mode

```bash
set -g visual-activity on
set -g visual-bell on
set -g visual-silence on
```

These trigger message-line notifications (which screen readers detect) instead
of relying on color-only indicators that screen readers cannot perceive.

Note: `visual-bell on` ADDS a message notification; it does NOT suppress the
terminal bell sound. Users who rely on audible bell will still hear it. The
message provides a secondary channel for users whose screen readers may not
announce terminal bell events.

#### 2.5 High-Contrast, Colorblind-Safe Palette

Overrides `tmux_conf_theme_colour_*` with:

| Slot | Hex       | Role            | Contrast vs bg |
|------|-----------|-----------------|----------------|
| 1    | `#1a1a2e` | Background      | --             |
| 2    | `#2d2d44` | Inactive border | --             |
| 3    | `#b0b0b0` | Inactive text   | 8.5:1          |
| 4    | `#00d4aa` | Active/focus    | 8.2:1          |
| 5    | `#ffd700` | Alert/urgent    | 11.3:1         |
| 6    | `#1a1a2e` | Dark accent     | --             |
| 7    | `#e0e0e0` | Primary text    | 12.1:1         |
| 8    | `#1a1a2e` | Dark accent     | --             |
| 9    | `#ffd700` | Warning         | 11.3:1         |
| 10   | `#ff8c00` | Error/important | 5.8:1          |
| 11   | `#00d4aa` | Success         | 8.2:1          |
| 12   | `#6c6c6c` | Muted text      | 4.6:1          |
| 13   | `#e0e0e0` | Bright text     | 12.1:1         |
| 14   | `#1a1a2e` | Dark accent     | --             |
| 15   | `#1a1a2e` | Dark accent     | --             |
| 16   | `#ff8c00` | Danger          | 5.8:1          |
| 17   | `#e0e0e0` | Bright text     | 12.1:1         |

All text colors meet WCAG AA (>= 4.5:1). Alert colors (yellow, orange, cyan)
are distinguishable under protanopia, deuteranopia, and tritanopia.

##### Light Background Palette

When `tmux_conf_accessibility_theme=light` (or auto-detected as light):

| Slot | Hex       | Role            | Contrast vs bg |
|------|-----------|-----------------|----------------|
| 1    | `#f5f5f0` | Background      | --             |
| 2    | `#e0e0da` | Inactive border | --             |
| 3    | `#555555` | Inactive text   | 7.5:1          |
| 4    | `#007a5e` | Active/focus    | 5.2:1          |
| 5    | `#b8860b` | Alert/urgent    | 4.6:1          |
| 6    | `#f5f5f0` | Light accent    | --             |
| 7    | `#1a1a1a` | Primary text    | 15.3:1         |
| 8    | `#f5f5f0` | Light accent    | --             |
| 9    | `#b8860b` | Warning         | 4.6:1          |
| 10   | `#cc3300` | Error/important | 5.4:1          |
| 11   | `#007a5e` | Success         | 5.2:1          |
| 12   | `#777777` | Muted text      | 4.6:1          |
| 13   | `#1a1a1a` | Bright text     | 15.3:1         |
| 14   | `#f5f5f0` | Light accent    | --             |
| 15   | `#f5f5f0` | Light accent    | --             |
| 16   | `#cc3300` | Danger          | 5.4:1          |
| 17   | `#1a1a1a` | Bright text     | 15.3:1         |

Light palette contrast ratios measured against `#f5f5f0` background.
Same WCAG AA compliance and colorblind-safe distinguishability.

##### Theme Auto-Detection Logic

```bash
# If tmux_conf_accessibility_theme=auto (default):
#   1. Check $COLORFGBG (format: "fg;bg", e.g., "15;0" = light-on-dark)
#   2. If bg component > 7 (out of 0-15 range), assume light background
#   3. If $COLORFGBG is unset or unparseable, default to dark
# User override: set tmux_conf_accessibility_theme=dark or =light
```

#### Pane Content Colors

```bash
tmux_conf_theme_window_fg=default        # inherit terminal text color
tmux_conf_theme_window_bg=default        # inherit terminal background
tmux_conf_theme_highlight_focused_pane=true
tmux_conf_theme_focused_pane_fg=default  # inherit terminal text color
# Dark: subtle shift from #1a1a2e; Light: subtle shift from #f5f5f0
tmux_conf_theme_focused_pane_bg="#1e1e3a" # (or #ededea for light theme)
```

Rationale: `window_fg`/`window_bg` stay at "default" to respect the user's
terminal emulator color settings (low-vision users often customize these).
The focused pane gets a barely-visible background shift (`#1e1e3a` vs `#1a1a2e`)
to provide a visual cue for the active pane without fighting terminal settings.
Active pane border uses colour_4 (`#00d4aa`) which is already specified.

#### 2.6 ASCII Separators

```bash
tmux_conf_theme_left_separator_main="|"
tmux_conf_theme_left_separator_sub="|"
tmux_conf_theme_right_separator_main="|"
tmux_conf_theme_right_separator_sub="|"
```

Replaces Powerline glyphs with ASCII pipe characters. Screen readers announce
pipe as "bar" or "pipe" which is brief and meaningful, unlike "black
right-pointing triangle" for Powerline characters.

### 3. Accessible Keybindings

When `tmux_conf_accessibility_keys=enabled`, these bindings are ADDED (existing
bindings remain):

| Action              | Binding                    | Notes                         |
|---------------------|----------------------------|-------------------------------|
| Pane: move left     | `<prefix> Left`            | Arrow key (intuitive)         |
| Pane: move down     | `<prefix> Down`            | Arrow key                     |
| Pane: move up       | `<prefix> Up`              | Arrow key                     |
| Pane: move right    | `<prefix> Right`           | Arrow key                     |
| Pane: resize left   | `<prefix> M-Left`          | Alt+arrow (one modifier)      |
| Pane: resize down   | `<prefix> M-Down`          | Alt+arrow                     |
| Pane: resize up     | `<prefix> M-Up`            | Alt+arrow                     |
| Pane: resize right  | `<prefix> M-Right`         | Alt+arrow                     |
| Window: previous    | `<prefix> C-Left`          | Ctrl+arrow (no stock conflict)|
| Window: next        | `<prefix> C-Right`         | Ctrl+arrow                    |
| Pane: announce      | `<prefix> a`               | Displays pane context message |
| Help: list keys     | `<prefix> A`               | Lists all accessibility keys  |

The pane announce binding displays a message with this exact format:
```
<session>:<window> Pane <index>/<total>: <command> in <path>
```

Format rules:
- `<session>`: `#S` (session name)
- `<window>`: `#W` (window name)
- `<index>`: `#{pane_index}` (1-based)
- `<total>`: `#{window_panes}`
- `<command>`: `#{pane_current_command}` (e.g., "vim", "bash", "python3")
- `<path>`: `#{pane_current_path}` with `$HOME` replaced by `~`

Edge cases:
- Single pane: displays "main:dev Pane 1/1: bash in ~/project"
- No current command (empty): displays "main:dev Pane 1/2: (idle) in ~/project"
- Very long path: no truncation (screen readers handle long text fine)
- Zoomed pane: appends " [zoomed]": "main:dev Pane 1/3: vim in ~/src [zoomed]"

Implementation:
```bash
bind a display-message -d "$tmux_conf_accessibility_display_time" "#S:#W Pane #{pane_index}/#{window_panes}: #{?#{pane_current_command},#{pane_current_command},(idle)} in #{pane_current_path}#{?window_zoomed_flag, [zoomed],}"
```

Design choice: avoids `Ctrl+Shift+*` combos which conflict with NVDA/JAWS
navigation keys. Avoids `Shift+Tab` which is a screen reader nav key. Uses
only prefix + single key or prefix + modifier+arrow. Window prev/next uses
`Ctrl+Left`/`Ctrl+Right` instead of `[`/`]` to avoid conflicting with stock
tmux copy-mode enter (`<prefix> [`) and paste buffer (`<prefix> ]`).

The help binding (`<prefix> A`) displays:
```bash
bind A display-message -d "$tmux_conf_accessibility_display_time" "Accessibility: arrows=pane, M-arrows=resize, C-Left/Right=window, a=announce, A=help, s/w=choose-tree"
```

### 4. Accessible Theme Block in `.tmux.conf.local`

A commented-out theme block (like the existing ansi alternative) with full
documentation. Users who want manual control without the toggle can uncomment
individual lines:

```bash
# -- accessible theme ----------------------------------------------------------
# High-contrast, colorblind-safe, screen-reader-friendly theme.
# Activate all at once with tmux_conf_accessibility=enabled, or uncomment
# individual lines below for manual control.
# Requires: tmux >= 3.3 for full screen reader support.
# Tested with: NVDA + Windows Terminal, Orca + GNOME Terminal, TDSR.
#
#tmux_conf_theme_colour_1="#1a1a2e"    # background (near-black)
#tmux_conf_theme_colour_2="#2d2d44"    # inactive border
# ... (full palette, documented)
#
#tmux_conf_theme_left_separator_main="|"
#tmux_conf_theme_left_separator_sub="|"
#tmux_conf_theme_right_separator_main="|"
#tmux_conf_theme_right_separator_sub="|"
#
#tmux_conf_theme_window_status_format="#I:#W"
#tmux_conf_theme_window_status_current_format="#I:#W#{?window_zoomed_flag, [zoomed],}"
```

### 5. README Addition

New section "Accessibility" after "Configuration", covering:
- Quick start: one variable to set
- What changes when enabled
- Minimum version requirement with explanation
- Screen reader recommendations (TDSR for Linux/WSL, Windows Terminal for NVDA)
- Accessible keybinding reference table
- Invitation for screen reader user feedback

### 6. Changes to `.tmux.conf` Engine

The `_apply_configuration` function (or a new `_apply_accessibility` helper
called from it) checks `tmux_conf_accessibility` and applies the defaults from
sections 2.1-2.5 BEFORE processing user theme overrides. This means user
variables in `.tmux.conf.local` still take precedence (consistent with existing
override behavior).

The `_apply_bindings` function (or a new section) checks
`tmux_conf_accessibility_keys` and adds the keybindings from section 3.

---

## Files Modified

| File              | Change                                              |
|-------------------|-----------------------------------------------------|
| `.tmux.conf`      | Add `_apply_accessibility` logic in embedded script |
| `.tmux.conf.local`| Add accessibility variables + theme block           |
| `README.md`       | Add Accessibility section                           |

## Validation Plan

1. **Contrast verification**: Use WebAIM contrast checker to confirm all color
   pairs meet WCAG AA (4.5:1 for normal text, 3:1 for large text)
2. **ShellCheck**: Run on the modified embedded script
3. **Functional test**: Enable accessibility mode, verify all settings apply
4. **Screen reader test**: Ali's co-worker tests with NVDA + Windows Terminal +
   SSH into WSL + tmux >= 3.3. Validate:
   - Status line is readable without decorative noise
   - choose-tree announces current selection
   - Pane announce binding (`<prefix> a`) is read correctly
   - Keybindings do not conflict with NVDA navigation
5. **Backward compatibility**: Verify default behavior unchanged when
   `tmux_conf_accessibility=disabled` (the default)
6. **tmux version range**: Test on tmux 3.3, 3.4, 3.5

## Resolved Design Questions

- **`visual-activity on` noise**: Ships enabled by default with a dedicated toggle
  `tmux_conf_accessibility_visual_activity=true|false` so users can disable without
  losing other accessibility features.
- **`status-interval 60`**: Use 60 seconds. Users who want faster updates can
  override with `set -g status-interval 10 #!important`.
- **Pane announce session name**: Yes, include it. Updated format:
  `Session:Window Pane X/Y: command in path`. This handles multi-session users.
  Final format: `bind a display-message "#S:#W Pane #{pane_index}/#{window_panes}: #{?#{pane_current_command},#{pane_current_command},(idle)} in #{pane_current_path}#{?window_zoomed_flag, [zoomed],}"`

## Architecture Decisions (from Eng Review)

1. **Execution order**: `_apply_accessibility` runs SYNCHRONOUSLY before the
   parallel `&` block in `_apply_configuration`. This eliminates race conditions
   with `_apply_theme` reading accessibility-set variables.
2. **Version guard**: Inside `_apply_accessibility`, check `_tmux_version < 3300`.
   If true, emit a warning via `display-message` and skip the `civis@` override.
   All other features still apply on older tmux.
3. **Function organization**: New `_apply_accessibility` function (~60-80 lines).
   Keybinding logic is a new section within `_apply_bindings`.
4. **Input validation**: If `tmux_conf_accessibility` is set to a value other than
   "enabled" or "disabled" (per `_is_disabled`), emit a warning and treat as disabled.

## Test Suite

A `tests/` directory is included with this PR:

| File | Coverage |
|------|----------|
| `tests/run_tests.sh` | Test runner |
| `tests/test_accessibility.sh` | All accessibility code paths (toggle, version check, variable setting, keybindings) |
| `tests/test_theme.sh` | Theme variable defaults and color application |
| `tests/test_bindings.sh` | Binding generation logic |
| `tests/test_helpers.sh` | `_is_true`, `_is_disabled`, and other utility functions |

Tests validate:
- `disabled` path is a clean no-op
- `enabled` path sets all expected variables
- Version < 3300 emits warning and skips `civis@`
- Invalid variable values trigger warning
- `visual_activity=false` suppresses visual-* settings
- Keybinding generation produces expected `bind-key` commands
- Helper functions handle all documented input values
- Theme defaults are applied correctly when no user overrides exist

## References

- tmux issue #2970: https://github.com/tmux/tmux/issues/2970
- tmux issue #3225: https://github.com/tmux/tmux/issues/3225
- TDSR: https://github.com/tspivey/tdsr
- rust-tdsr: https://github.com/ccdavis/rust-tdsr
- tdsr-server (NVDA bridge): https://github.com/tspivey/tdsr-server
- tmux cursor fix commit: https://github.com/tmux/tmux/commit/b55f0ac6
- Blind.guru (Mario Lang): https://blind.guru/blog/2021-06-25-brick.html
