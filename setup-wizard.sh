#!/bin/sh
# Oh my tmux! Setup Wizard
# POSIX sh compatible
set -e

SR_MODE=0
WIZARD_VERSION="1.0"

_path_dir() {
  case "$1" in
    */*) printf '%s\n' "${1%/*}" ;;
    *) printf '.\n' ;;
  esac
}

_make_temp_file() {
  _target_path="$1"
  _target_dir="$(_path_dir "$_target_path")"
  _target_name="${_target_path##*/}"
  _counter=0

  [ -d "$_target_dir" ] || mkdir -p "$_target_dir"

  while [ "$_counter" -lt 100 ]; do
    _candidate="$_target_dir/.${_target_name}.wizard.$$.$_counter.tmp"
    if (set -C; : > "$_candidate") 2>/dev/null; then
      printf '%s\n' "$_candidate"
      return 0
    fi
    _counter=$((_counter + 1))
  done

  return 1
}

# --- Path Detection ---
_detect_paths() {
  if [ -n "${WIZARD_TOML_PATH:-}" ]; then
    _toml_path="$WIZARD_TOML_PATH"
  elif [ -n "${TMUX_CONF:-}" ]; then
    _toml_path="$(_path_dir "$TMUX_CONF")/tmux.toml"
  else
    _toml_path="$HOME/.tmux/tmux.toml"
  fi
  TMUX_CONF="${TMUX_CONF:-$HOME/.tmux.conf}"
  TMUX_CONF_LOCAL="${TMUX_CONF_LOCAL:-$(_path_dir "$TMUX_CONF")/.tmux.conf.local}"
}

# --- Defaults ---
_load_defaults() {
  # Core settings
  cfg_preserve_stock_bindings=false
  cfg_new_session_prompt=false
  cfg_new_session_retain_current_path=false
  cfg_new_window_retain_current_path=false
  cfg_new_window_reconnect_ssh=false
  cfg_new_pane_retain_current_path=true
  cfg_new_pane_reconnect_ssh=false
  cfg_24b_colour=auto
  cfg_theme=enabled
  cfg_copy_to_os_clipboard=false
  cfg_accessibility=disabled
  cfg_accessibility_keys=disabled
  cfg_accessibility_visual_activity=true
  cfg_accessibility_display_time=5000
  cfg_accessibility_theme=auto
  cfg_update_plugins_on_launch=true
  cfg_update_plugins_on_reload=true
  cfg_uninstall_plugins_on_reload=true
  cfg_urlscan_options="--compact --dedupe"

  # Theme colours (default dark)
  cfg_colour_1="#080808"
  cfg_colour_2="#303030"
  cfg_colour_3="#8a8a8a"
  cfg_colour_4="#00afff"
  cfg_colour_5="#ffff00"
  cfg_colour_6="#080808"
  cfg_colour_7="#e4e4e4"
  cfg_colour_8="#080808"
  cfg_colour_9="#ffff00"
  cfg_colour_10="#ff00af"
  cfg_colour_11="#5fff00"
  cfg_colour_12="#8a8a8a"
  cfg_colour_13="#e4e4e4"
  cfg_colour_14="#080808"
  cfg_colour_15="#080808"
  cfg_colour_16="#d70000"
  cfg_colour_17="#e4e4e4"

  # Window/pane styles
  cfg_window_fg=default
  cfg_window_bg=default
  cfg_highlight_focused_pane=false
  cfg_focused_pane_bg='$tmux_conf_theme_colour_2'
  cfg_pane_border_style=thin
  cfg_pane_border='$tmux_conf_theme_colour_2'
  cfg_pane_active_border='$tmux_conf_theme_colour_4'
  cfg_pane_indicator='$tmux_conf_theme_colour_4'
  cfg_pane_active_indicator='$tmux_conf_theme_colour_4'

  # Status style
  cfg_status_fg='$tmux_conf_theme_colour_3'
  cfg_status_bg='$tmux_conf_theme_colour_1'
  cfg_status_attr=none
  cfg_terminal_title='#h - #S - #I #W'
  cfg_message_fg='$tmux_conf_theme_colour_1'
  cfg_message_bg='$tmux_conf_theme_colour_5'
  cfg_message_attr=bold
  cfg_message_command_fg='$tmux_conf_theme_colour_5'
  cfg_message_command_bg='$tmux_conf_theme_colour_1'
  cfg_message_command_attr=bold
  cfg_mode_fg='$tmux_conf_theme_colour_1'
  cfg_mode_bg='$tmux_conf_theme_colour_5'
  cfg_mode_attr=bold

  # Status bar content
  cfg_status_left=' #S | up#{?uptime_y, #{uptime_y}y,}#{?uptime_d, #{uptime_d}d,}#{?uptime_h, #{uptime_h}h,}#{?uptime_m, #{uptime_m}m,} '
  cfg_status_right=' #{prefix}#{mouse}#{pairing}#{synchronized}#{?battery_status,#{battery_status},}#{?battery_bar, #{battery_bar},}#{?battery_percentage, #{battery_percentage},} , %R , %d %b | #{username}#{root} | #{hostname} '
  cfg_status_left_fg='$tmux_conf_theme_colour_6,$tmux_conf_theme_colour_7,$tmux_conf_theme_colour_8'
  cfg_status_left_bg='$tmux_conf_theme_colour_9,$tmux_conf_theme_colour_10,$tmux_conf_theme_colour_11'
  cfg_status_left_attr='bold,none,none'
  cfg_status_right_fg='$tmux_conf_theme_colour_12,$tmux_conf_theme_colour_13,$tmux_conf_theme_colour_14'
  cfg_status_right_bg='$tmux_conf_theme_colour_15,$tmux_conf_theme_colour_16,$tmux_conf_theme_colour_17'
  cfg_status_right_attr='none,none,bold'

  # Window status
  cfg_window_status_format='#I #W#{?#{||:#{window_bell_flag},#{window_zoomed_flag}}, ,}#{?window_bell_flag,!,}#{?window_zoomed_flag,Z,}'
  cfg_window_status_current_format='#I #W#{?#{||:#{window_bell_flag},#{window_zoomed_flag}}, ,}#{?window_bell_flag,!,}#{?window_zoomed_flag,Z,}'
  cfg_window_status_separator=""
  cfg_window_status_fg='$tmux_conf_theme_colour_3'
  cfg_window_status_bg='$tmux_conf_theme_colour_1'
  cfg_window_status_attr=none
  cfg_window_status_current_fg='$tmux_conf_theme_colour_1'
  cfg_window_status_current_bg='$tmux_conf_theme_colour_4'
  cfg_window_status_current_attr=bold
  cfg_window_status_activity_fg=default
  cfg_window_status_activity_bg=default
  cfg_window_status_activity_attr=underscore
  cfg_window_status_bell_fg='$tmux_conf_theme_colour_5'
  cfg_window_status_bell_bg=default
  cfg_window_status_bell_attr='blink,bold'
  cfg_window_status_last_fg='$tmux_conf_theme_colour_4'
  cfg_window_status_last_bg='$tmux_conf_theme_colour_2'
  cfg_window_status_last_attr=none
  cfg_clock_colour='$tmux_conf_theme_colour_4'
  cfg_clock_style=24

  # Indicators
  cfg_pairing="[pair]"
  cfg_pairing_fg=none
  cfg_pairing_bg=none
  cfg_pairing_attr=none
  cfg_prefix="[pfx]"
  cfg_prefix_fg=none
  cfg_prefix_bg=none
  cfg_prefix_attr=none
  cfg_mouse_indicator="[M]"
  cfg_mouse_indicator_fg=none
  cfg_mouse_indicator_bg=none
  cfg_mouse_indicator_attr=none
  cfg_root="!"
  cfg_root_fg=none
  cfg_root_bg=none
  cfg_root_attr='bold,blink'
  cfg_synchronized="[sync]"
  cfg_synchronized_fg=none
  cfg_synchronized_bg=none
  cfg_synchronized_attr=none

  # Separators
  cfg_left_separator_main=""
  cfg_left_separator_sub="|"
  cfg_right_separator_main=""
  cfg_right_separator_sub="|"

  # Battery
  cfg_battery_bar_symbol_full="="
  cfg_battery_bar_symbol_empty="-"
  cfg_battery_bar_length=auto
  cfg_battery_bar_palette=gradient
  cfg_battery_hbar_palette=gradient
  cfg_battery_vbar_palette=gradient
  cfg_battery_status_charging="+"
  cfg_battery_status_discharging="-"

  # Wizard-specific state
  cfg_prefix_key="C-b"
  cfg_mouse=false
}

_load_existing() {
  # If tmux.toml exists, parse it and override cfg_* with found values
  [ -f "$_toml_path" ] || return 0

  # We need _parse_toml. Extract from .tmux.conf if available.
  if [ -f "$TMUX_CONF" ]; then
    _ptcode="$(awk '
      /^# _parse_toml\(\)/ { found=1; depth=0 }
      found {
        s = substr($0, 3)
        for (i=1; i<=length(s); i++) {
          c = substr(s, i, 1)
          if (c == "{") depth++
          if (c == "}") depth--
        }
        print s
        if (found && depth == 0 && s ~ /}/) exit
      }
    ' "$TMUX_CONF")"
    if [ -n "$_ptcode" ]; then
      eval "$_ptcode"
      _existing="$(_parse_toml < "$_toml_path" 2>/dev/null)" || true
      # Map parsed output back to cfg_* variables
      if [ -n "$_existing" ]; then
        while IFS='=' read -r _var _val; do
          case "$_val" in
            \"*\") _val="${_val#\"}"; _val="${_val%\"}" ;;
          esac
          case "$_var" in
            tmux_conf_new_pane_retain_current_path) cfg_new_pane_retain_current_path="$_val" ;;
            tmux_conf_new_pane_reconnect_ssh) cfg_new_pane_reconnect_ssh="$_val" ;;
            tmux_conf_new_window_retain_current_path) cfg_new_window_retain_current_path="$_val" ;;
            tmux_conf_new_window_reconnect_ssh) cfg_new_window_reconnect_ssh="$_val" ;;
            tmux_conf_new_session_prompt) cfg_new_session_prompt="$_val" ;;
            tmux_conf_new_session_retain_current_path) cfg_new_session_retain_current_path="$_val" ;;
            tmux_conf_preserve_stock_bindings) cfg_preserve_stock_bindings="$_val" ;;
            tmux_conf_24b_colour) cfg_24b_colour="$_val" ;;
            tmux_conf_theme) cfg_theme="$_val" ;;
            tmux_conf_copy_to_os_clipboard) cfg_copy_to_os_clipboard="$_val" ;;
            tmux_conf_accessibility) cfg_accessibility="$_val" ;;
            tmux_conf_accessibility_keys) cfg_accessibility_keys="$_val" ;;
            tmux_conf_accessibility_display_time) cfg_accessibility_display_time="$_val" ;;
            tmux_conf_accessibility_theme) cfg_accessibility_theme="$_val" ;;
            tmux_conf_update_plugins_on_launch) cfg_update_plugins_on_launch="$_val" ;;
            tmux_conf_update_plugins_on_reload) cfg_update_plugins_on_reload="$_val" ;;
            tmux_conf_uninstall_plugins_on_reload) cfg_uninstall_plugins_on_reload="$_val" ;;
          esac
        done <<EOF
$_existing
EOF
      fi
    fi
  fi
}

# --- UI Helpers ---
_die() {
  printf '%s\n' "$1" >&2
  exit 1
}

_prompt() {
  if [ "$SR_MODE" = 1 ]; then
    printf '%s\n' "$1"
  else
    printf '%s' "$1"
  fi
}

_choose() {
  _label="$1"
  shift
  _num_choices=$#
  _n=1

  if [ "$SR_MODE" = 1 ]; then
    printf 'Question: %s\n' "$_label"
    for _opt in "$@"; do
      printf '  Option %d: %s\n' "$_n" "$_opt"
      _n=$((_n + 1))
    done
    printf 'Enter a number (1 to %d): ' "$_num_choices"
  else
    printf '%s\n' "$_label"
    for _opt in "$@"; do
      printf '  %d) %s\n' "$_n" "$_opt"
      _n=$((_n + 1))
    done
    printf '> '
  fi

  if ! read -r _answer; then
    _die "Input closed. No changes written."
  fi
  # Validate
  case "$_answer" in
    *[!0-9]*) _answer=1 ;;
  esac
  [ -z "$_answer" ] && _answer=1
  [ "$_answer" -lt 1 ] 2>/dev/null && _answer=1
  [ "$_answer" -gt "$_num_choices" ] 2>/dev/null && _answer="$_num_choices"

  if [ "$SR_MODE" = 1 ]; then
    # Read-back the selection
    _n=1
    for _opt in "$@"; do
      if [ "$_n" -eq "$_answer" ]; then
        printf 'Selected: %s\n' "$_opt"
        break
      fi
      _n=$((_n + 1))
    done
  fi
}

_confirm() {
  _msg="$1"
  if [ "$SR_MODE" = 1 ]; then
    printf 'Question: %s (y or n, default y): ' "$_msg"
  else
    printf '%s [Y/n] ' "$_msg"
  fi
  if ! read -r _yn; then
    _die "Input closed. No changes written."
  fi
  case "$_yn" in
    [Nn]*) return 1 ;;
    *) return 0 ;;
  esac
}

_announce() {
  [ "$SR_MODE" = 1 ] && printf '%s\n' "$1"
}

_progress() {
  if [ "$SR_MODE" = 1 ]; then
    printf 'Question %d of %d:\n' "$1" "$2"
  else
    printf '[%d/%d] ' "$1" "$2"
  fi
}

# --- Presets ---
_preset_minimal() {
  cfg_preserve_stock_bindings=true
  cfg_mouse=false
  cfg_copy_to_os_clipboard=false
  cfg_update_plugins_on_launch=false
  cfg_update_plugins_on_reload=false
  cfg_accessibility=disabled
  cfg_prefix_key="C-b"
}

_preset_power_user() {
  cfg_mouse=true
  cfg_copy_to_os_clipboard=true
  cfg_24b_colour=auto
  cfg_update_plugins_on_launch=true
  cfg_update_plugins_on_reload=true
  cfg_prefix_key="C-a"
}

_preset_accessible() {
  cfg_accessibility=enabled
  cfg_accessibility_keys=enabled
  cfg_accessibility_display_time=5000
  cfg_accessibility_theme=auto
  cfg_accessibility_visual_activity=true
  cfg_mouse=false
  cfg_prefix_key="C-b"
  # High-contrast colours
  cfg_colour_1="#1a1a2e"
  cfg_colour_2="#2d2d44"
  cfg_colour_3="#b0b0b0"
  cfg_colour_4="#00d4aa"
  cfg_colour_5="#ffd700"
  cfg_colour_6="#1a1a2e"
  cfg_colour_7="#e0e0e0"
  cfg_colour_8="#1a1a2e"
  cfg_colour_9="#ffd700"
  cfg_colour_10="#ff8c00"
  cfg_colour_11="#00d4aa"
  cfg_colour_12="#6c6c6c"
  cfg_colour_13="#e0e0e0"
  cfg_colour_14="#1a1a2e"
  cfg_colour_15="#1a1a2e"
  cfg_colour_16="#ff8c00"
  cfg_colour_17="#e0e0e0"
  # Also set tmux_conf_theme_colour_* for preview
  tmux_conf_theme_colour_1="#1a1a2e"
  tmux_conf_theme_colour_4="#00d4aa"
  tmux_conf_theme_colour_5="#ffd700"
  tmux_conf_theme_colour_7="#e0e0e0"
  # ASCII separators
  cfg_left_separator_main="|"
  cfg_left_separator_sub="|"
  cfg_right_separator_main="|"
  cfg_right_separator_sub="|"
}

# --- Question Flows ---
_ask_quick() {
  _progress 1 8
  _choose "Prefix key" "C-b (default)" "C-a (screen-like)"
  case $_answer in
    1) cfg_prefix_key="C-b" ;;
    2) cfg_prefix_key="C-a" ;;
  esac

  if [ "$SR_MODE" = 1 ]; then
    _announce "Note: Mouse ON lets you click panes and scroll with the mouse wheel, but it intercepts your terminal native text selection. Mouse OFF means you use keyboard commands for everything."
  fi
  _progress 2 8
  _choose "Mouse support" "On (click and scroll)" "Off (keyboard only)"
  case $_answer in
    1) cfg_mouse=true ;;
    2) cfg_mouse=false ;;
  esac

  _progress 3 8
  _choose "Theme" "Dark (default)" "Light" "High contrast (accessible)"
  case $_answer in
    1) ;;
    2)
      cfg_colour_1="#f5f5f0"
      cfg_colour_2="#e0e0da"
      cfg_colour_3="#555555"
      cfg_colour_4="#007a5e"
      cfg_colour_5="#b8860b"
      cfg_colour_6="#f5f5f0"
      cfg_colour_7="#1a1a1a"
      cfg_colour_8="#f5f5f0"
      cfg_colour_9="#b8860b"
      cfg_colour_10="#cc3300"
      cfg_colour_11="#007a5e"
      cfg_colour_12="#777777"
      cfg_colour_13="#1a1a1a"
      cfg_colour_14="#f5f5f0"
      cfg_colour_15="#f5f5f0"
      cfg_colour_16="#cc3300"
      cfg_colour_17="#1a1a1a"
      ;;
    3)
      cfg_colour_1="#1a1a2e"
      cfg_colour_2="#2d2d44"
      cfg_colour_3="#b0b0b0"
      cfg_colour_4="#00d4aa"
      cfg_colour_5="#ffd700"
      cfg_colour_6="#1a1a2e"
      cfg_colour_7="#e0e0e0"
      cfg_colour_8="#1a1a2e"
      cfg_colour_9="#ffd700"
      cfg_colour_10="#ff8c00"
      cfg_colour_11="#00d4aa"
      cfg_colour_12="#6c6c6c"
      cfg_colour_13="#e0e0e0"
      cfg_colour_14="#1a1a2e"
      cfg_colour_15="#1a1a2e"
      cfg_colour_16="#ff8c00"
      cfg_colour_17="#e0e0e0"
      ;;
  esac

  if [ "$SR_MODE" != 1 ] && [ "$(_detect_colour_support)" != "basic" ]; then
    printf '\n  Preview of selected theme:\n'
    _preview_colour "${cfg_colour_1}" "Background:"
    _preview_colour "${cfg_colour_4}" "Accent:    "
    _preview_colour "${cfg_colour_7}" "Foreground:"
    _preview_colour "${cfg_colour_5}" "Highlight: "
    printf '  (Actual tmux appearance may vary)\n\n'
  fi

  _progress 4 8
  _choose "Clipboard integration" "On (copy to OS clipboard)" "Off"
  case $_answer in
    1) cfg_copy_to_os_clipboard=true ;;
    2) cfg_copy_to_os_clipboard=false ;;
  esac

  _progress 5 8
  _choose "Accessibility mode" "Enabled" "Disabled (default)"
  case $_answer in
    1) cfg_accessibility=enabled; cfg_accessibility_keys=enabled ;;
    2) cfg_accessibility=disabled ;;
  esac

  _progress 6 8
  _choose "24-bit colour" "Auto-detect (recommended)" "Force on" "Force off"
  case $_answer in
    1) cfg_24b_colour=auto ;;
    2) cfg_24b_colour=true ;;
    3) cfg_24b_colour=false ;;
  esac

  _progress 7 8
  _choose "New panes keep current path" "Yes (default)" "No"
  case $_answer in
    1) cfg_new_pane_retain_current_path=true ;;
    2) cfg_new_pane_retain_current_path=false ;;
  esac

  _progress 8 8
  _choose "Auto-update plugins on launch" "Yes (default)" "No"
  case $_answer in
    1) cfg_update_plugins_on_launch=true ;;
    2) cfg_update_plugins_on_launch=false ;;
  esac
}

# --- Output Builders ---
_build_toml() {
  # Output complete TOML to stdout
  cat <<TOML_EOF
# Oh my tmux! configuration
# Generated by setup-wizard.sh v${WIZARD_VERSION}

[general]
preserve_stock_bindings = ${cfg_preserve_stock_bindings}
new_session_prompt = ${cfg_new_session_prompt}
new_session_retain_current_path = ${cfg_new_session_retain_current_path}
new_window_retain_current_path = ${cfg_new_window_retain_current_path}
new_window_reconnect_ssh = ${cfg_new_window_reconnect_ssh}
new_pane_retain_current_path = ${cfg_new_pane_retain_current_path}
new_pane_reconnect_ssh = ${cfg_new_pane_reconnect_ssh}

[display]
colour_24b = ${cfg_24b_colour}

[theme]
enabled = "${cfg_theme}"
colour_1 = "${cfg_colour_1}"
colour_2 = "${cfg_colour_2}"
colour_3 = "${cfg_colour_3}"
colour_4 = "${cfg_colour_4}"
colour_5 = "${cfg_colour_5}"
colour_6 = "${cfg_colour_6}"
colour_7 = "${cfg_colour_7}"
colour_8 = "${cfg_colour_8}"
colour_9 = "${cfg_colour_9}"
colour_10 = "${cfg_colour_10}"
colour_11 = "${cfg_colour_11}"
colour_12 = "${cfg_colour_12}"
colour_13 = "${cfg_colour_13}"
colour_14 = "${cfg_colour_14}"
colour_15 = "${cfg_colour_15}"
colour_16 = "${cfg_colour_16}"
colour_17 = "${cfg_colour_17}"
window_fg = "${cfg_window_fg}"
window_bg = "${cfg_window_bg}"
highlight_focused_pane = ${cfg_highlight_focused_pane}
focused_pane_bg = "${cfg_focused_pane_bg}"
pane_border_style = "${cfg_pane_border_style}"
pane_border = "${cfg_pane_border}"
pane_active_border = "${cfg_pane_active_border}"
pane_indicator = "${cfg_pane_indicator}"
pane_active_indicator = "${cfg_pane_active_indicator}"
status_fg = "${cfg_status_fg}"
status_bg = "${cfg_status_bg}"
status_attr = "${cfg_status_attr}"
terminal_title = "${cfg_terminal_title}"
message_fg = "${cfg_message_fg}"
message_bg = "${cfg_message_bg}"
message_attr = "${cfg_message_attr}"
message_command_fg = "${cfg_message_command_fg}"
message_command_bg = "${cfg_message_command_bg}"
message_command_attr = "${cfg_message_command_attr}"
mode_fg = "${cfg_mode_fg}"
mode_bg = "${cfg_mode_bg}"
mode_attr = "${cfg_mode_attr}"

[status_bar]
left = "${cfg_status_left}"
right = "${cfg_status_right}"
left_fg = "${cfg_status_left_fg}"
left_bg = "${cfg_status_left_bg}"
left_attr = "${cfg_status_left_attr}"
right_fg = "${cfg_status_right_fg}"
right_bg = "${cfg_status_right_bg}"
right_attr = "${cfg_status_right_attr}"
window_status_format = "${cfg_window_status_format}"
window_status_current_format = "${cfg_window_status_current_format}"
window_status_separator = "${cfg_window_status_separator}"
window_status_fg = "${cfg_window_status_fg}"
window_status_bg = "${cfg_window_status_bg}"
window_status_attr = "${cfg_window_status_attr}"
window_status_current_fg = "${cfg_window_status_current_fg}"
window_status_current_bg = "${cfg_window_status_current_bg}"
window_status_current_attr = "${cfg_window_status_current_attr}"
window_status_activity_fg = "${cfg_window_status_activity_fg}"
window_status_activity_bg = "${cfg_window_status_activity_bg}"
window_status_activity_attr = "${cfg_window_status_activity_attr}"
window_status_bell_fg = "${cfg_window_status_bell_fg}"
window_status_bell_bg = "${cfg_window_status_bell_bg}"
window_status_bell_attr = "${cfg_window_status_bell_attr}"
window_status_last_fg = "${cfg_window_status_last_fg}"
window_status_last_bg = "${cfg_window_status_last_bg}"
window_status_last_attr = "${cfg_window_status_last_attr}"
clock_colour = "${cfg_clock_colour}"
clock_style = "${cfg_clock_style}"

[indicators]
pairing = "${cfg_pairing}"
pairing_fg = "${cfg_pairing_fg}"
pairing_bg = "${cfg_pairing_bg}"
pairing_attr = "${cfg_pairing_attr}"
prefix = "${cfg_prefix}"
prefix_fg = "${cfg_prefix_fg}"
prefix_bg = "${cfg_prefix_bg}"
prefix_attr = "${cfg_prefix_attr}"
mouse = "${cfg_mouse_indicator}"
mouse_fg = "${cfg_mouse_indicator_fg}"
mouse_bg = "${cfg_mouse_indicator_bg}"
mouse_attr = "${cfg_mouse_indicator_attr}"
root = "${cfg_root}"
root_fg = "${cfg_root_fg}"
root_bg = "${cfg_root_bg}"
root_attr = "${cfg_root_attr}"
synchronized = "${cfg_synchronized}"
synchronized_fg = "${cfg_synchronized_fg}"
synchronized_bg = "${cfg_synchronized_bg}"
synchronized_attr = "${cfg_synchronized_attr}"

[separators]
left_main = "${cfg_left_separator_main}"
left_sub = "${cfg_left_separator_sub}"
right_main = "${cfg_right_separator_main}"
right_sub = "${cfg_right_separator_sub}"

[battery]
bar_symbol_full = "${cfg_battery_bar_symbol_full}"
bar_symbol_empty = "${cfg_battery_bar_symbol_empty}"
bar_length = "${cfg_battery_bar_length}"
bar_palette = "${cfg_battery_bar_palette}"
hbar_palette = "${cfg_battery_hbar_palette}"
vbar_palette = "${cfg_battery_vbar_palette}"
status_charging = "${cfg_battery_status_charging}"
status_discharging = "${cfg_battery_status_discharging}"

[clipboard]
copy_to_os_clipboard = ${cfg_copy_to_os_clipboard}

[urlscan]
options = "${cfg_urlscan_options}"

[accessibility]
enabled = "${cfg_accessibility}"
keys = "${cfg_accessibility_keys}"
visual_activity = ${cfg_accessibility_visual_activity}
display_time = ${cfg_accessibility_display_time}
theme = "${cfg_accessibility_theme}"

[plugins]
update_on_launch = ${cfg_update_plugins_on_launch}
update_on_reload = ${cfg_update_plugins_on_reload}
uninstall_on_reload = ${cfg_uninstall_plugins_on_reload}
TOML_EOF
}

_build_local_block() {
  # Output .tmux.conf.local content with wizard-managed block inserted/replaced
  _start="# >>> oh-my-tmux wizard-managed start >>>"
  _end="# <<< oh-my-tmux wizard-managed end <<<"
  _mouse_val="off"
  [ "$cfg_mouse" = true ] && _mouse_val="on"
  _block="$_start
set -g mouse $_mouse_val #!important
$_end"

  if [ -f "$TMUX_CONF_LOCAL" ] && grep -qF "$_start" "$TMUX_CONF_LOCAL" 2>/dev/null; then
    awk -v start="$_start" -v end_mark="$_end" -v block="$_block" '
      $0 == start { skip=1; print block; next }
      $0 == end_mark { skip=0; next }
      !skip { print }
    ' "$TMUX_CONF_LOCAL"
  elif [ -f "$TMUX_CONF_LOCAL" ]; then
    cat "$TMUX_CONF_LOCAL"
    printf '\n%s\n' "$_block"
  else
    printf '%s\n' "$_block"
  fi
}

_transactional_write() {
  _toml_dir="$(_path_dir "$_toml_path")"
  _local_dir="$(_path_dir "$TMUX_CONF_LOCAL")"
  [ -d "$_toml_dir" ] || mkdir -p "$_toml_dir"
  [ -d "$_local_dir" ] || mkdir -p "$_local_dir"

  # Stage TOML to temp
  _tmp_toml="$(_make_temp_file "$_toml_path")" || {
    printf 'Error: cannot create temp file\n' >&2
    return 1
  }
  _build_toml > "$_tmp_toml"

  # Stage local to temp
  _tmp_local="$(_make_temp_file "$TMUX_CONF_LOCAL")" || {
    rm -f "$_tmp_toml"
    printf 'Error: cannot create temp file\n' >&2
    return 1
  }
  _build_local_block > "$_tmp_local"

  # Create timestamped backups
  _ts="$(date +%Y%m%d-%H%M%S)"
  [ -f "$_toml_path" ] && cp "$_toml_path" "${_toml_path}.bak.${_ts}"
  [ -f "$TMUX_CONF_LOCAL" ] && cp "$TMUX_CONF_LOCAL" "${TMUX_CONF_LOCAL}.pre-toml.${_ts}"

  # Atomic rename: TOML first
  if ! mv "$_tmp_toml" "$_toml_path"; then
    rm -f "$_tmp_toml" "$_tmp_local"
    printf 'Error: failed to write tmux.toml\n' >&2
    return 1
  fi

  # Atomic rename: local second
  if ! mv "$_tmp_local" "$TMUX_CONF_LOCAL"; then
    # Rollback TOML from backup
    [ -f "${_toml_path}.bak.${_ts}" ] && mv "${_toml_path}.bak.${_ts}" "$_toml_path"
    rm -f "$_tmp_local"
    printf 'Error: failed to write .tmux.conf.local\n' >&2
    return 1
  fi

  if [ "$SR_MODE" = 1 ]; then
    printf 'Configuration written successfully.\n'
    printf 'Files updated: %s and %s\n' "$_toml_path" "$TMUX_CONF_LOCAL"
  else
    printf 'Done! Configuration saved.\n'
  fi
}

_review() {
  if [ "$SR_MODE" = 1 ]; then
    printf '\nConfiguration summary:\n'
    printf '  Prefix: %s\n' "$cfg_prefix_key"
    printf '  Mouse: %s\n' "$cfg_mouse"
    printf '  Theme: colours 1-17 configured\n'
    printf '  Clipboard: %s\n' "$cfg_copy_to_os_clipboard"
    printf '  Accessibility: %s\n' "$cfg_accessibility"
    printf '  24-bit colour: %s\n' "$cfg_24b_colour"
    printf '  Pane retains path: %s\n' "$cfg_new_pane_retain_current_path"
    printf '  Plugin updates: %s\n' "$cfg_update_plugins_on_launch"
    printf '\n'
  else
    printf '\n--- Configuration Summary ---\n'
    printf '  Prefix: %s  |  Mouse: %s  |  Clipboard: %s\n' "$cfg_prefix_key" "$cfg_mouse" "$cfg_copy_to_os_clipboard"
    printf '  24-bit: %s  |  A11y: %s  |  Plugins: %s\n' "$cfg_24b_colour" "$cfg_accessibility" "$cfg_update_plugins_on_launch"
    printf '  Pane path: %s\n' "$cfg_new_pane_retain_current_path"
    printf '\n'
  fi
}

_reload() {
  if [ -n "${TMUX:-}" ] && [ "${WIZARD_NON_INTERACTIVE:-}" != 1 ]; then
    if _confirm "Reload tmux configuration now?"; then
      tmux source-file "$TMUX_CONF" 2>/dev/null && printf 'Configuration reloaded.\n' || printf 'Reload failed (you can reload manually with prefix + r).\n'
    fi
  fi
}

_build_migration_toml() {
  printf '# Oh my tmux! configuration\n'
  printf '# Migrated from .tmux.conf.local by setup-wizard.sh\n\n'

  _current_section=""

  while IFS='=' read -r _var _val || [ -n "$_var" ]; do
    [ -n "$_var" ] || continue

    case "$_val" in
      \"*\") _val="${_val#\"}"; _val="${_val%\"}" ;;
      \'*\') _val="${_val#\'}"; _val="${_val%\'}" ;;
    esac

    _section=""
    _key=""
    case "$_var" in
      tmux_conf_preserve_stock_bindings) _section="general"; _key="preserve_stock_bindings" ;;
      tmux_conf_new_session_prompt) _section="general"; _key="new_session_prompt" ;;
      tmux_conf_new_session_retain_current_path) _section="general"; _key="new_session_retain_current_path" ;;
      tmux_conf_new_window_retain_current_path) _section="general"; _key="new_window_retain_current_path" ;;
      tmux_conf_new_window_reconnect_ssh) _section="general"; _key="new_window_reconnect_ssh" ;;
      tmux_conf_new_pane_retain_current_path) _section="general"; _key="new_pane_retain_current_path" ;;
      tmux_conf_new_pane_reconnect_ssh) _section="general"; _key="new_pane_reconnect_ssh" ;;
      tmux_conf_24b_colour) _section="display"; _key="colour_24b" ;;
      tmux_conf_theme) _section="theme"; _key="enabled" ;;
      tmux_conf_theme_colour_[0-9]*) _section="theme"; _key="colour_${_var##*_colour_}" ;;
      tmux_conf_theme_window_fg) _section="theme"; _key="window_fg" ;;
      tmux_conf_theme_window_bg) _section="theme"; _key="window_bg" ;;
      tmux_conf_theme_highlight_focused_pane) _section="theme"; _key="highlight_focused_pane" ;;
      tmux_conf_theme_focused_pane_bg) _section="theme"; _key="focused_pane_bg" ;;
      tmux_conf_theme_pane_border_style) _section="theme"; _key="pane_border_style" ;;
      tmux_conf_theme_pane_border) _section="theme"; _key="pane_border" ;;
      tmux_conf_theme_pane_active_border) _section="theme"; _key="pane_active_border" ;;
      tmux_conf_theme_pane_indicator) _section="theme"; _key="pane_indicator" ;;
      tmux_conf_theme_pane_active_indicator) _section="theme"; _key="pane_active_indicator" ;;
      tmux_conf_theme_status_fg) _section="theme"; _key="status_fg" ;;
      tmux_conf_theme_status_bg) _section="theme"; _key="status_bg" ;;
      tmux_conf_theme_status_attr) _section="theme"; _key="status_attr" ;;
      tmux_conf_theme_terminal_title) _section="theme"; _key="terminal_title" ;;
      tmux_conf_theme_message_fg) _section="theme"; _key="message_fg" ;;
      tmux_conf_theme_message_bg) _section="theme"; _key="message_bg" ;;
      tmux_conf_theme_message_attr) _section="theme"; _key="message_attr" ;;
      tmux_conf_theme_message_command_fg) _section="theme"; _key="message_command_fg" ;;
      tmux_conf_theme_message_command_bg) _section="theme"; _key="message_command_bg" ;;
      tmux_conf_theme_message_command_attr) _section="theme"; _key="message_command_attr" ;;
      tmux_conf_theme_mode_fg) _section="theme"; _key="mode_fg" ;;
      tmux_conf_theme_mode_bg) _section="theme"; _key="mode_bg" ;;
      tmux_conf_theme_mode_attr) _section="theme"; _key="mode_attr" ;;
      tmux_conf_theme_status_left) _section="status_bar"; _key="left" ;;
      tmux_conf_theme_status_right) _section="status_bar"; _key="right" ;;
      tmux_conf_theme_status_left_fg) _section="status_bar"; _key="left_fg" ;;
      tmux_conf_theme_status_left_bg) _section="status_bar"; _key="left_bg" ;;
      tmux_conf_theme_status_left_attr) _section="status_bar"; _key="left_attr" ;;
      tmux_conf_theme_status_right_fg) _section="status_bar"; _key="right_fg" ;;
      tmux_conf_theme_status_right_bg) _section="status_bar"; _key="right_bg" ;;
      tmux_conf_theme_status_right_attr) _section="status_bar"; _key="right_attr" ;;
      tmux_conf_theme_window_status_format) _section="status_bar"; _key="window_status_format" ;;
      tmux_conf_theme_window_status_current_format) _section="status_bar"; _key="window_status_current_format" ;;
      tmux_conf_theme_window_status_separator) _section="status_bar"; _key="window_status_separator" ;;
      tmux_conf_theme_window_status_fg) _section="status_bar"; _key="window_status_fg" ;;
      tmux_conf_theme_window_status_bg) _section="status_bar"; _key="window_status_bg" ;;
      tmux_conf_theme_window_status_attr) _section="status_bar"; _key="window_status_attr" ;;
      tmux_conf_theme_window_status_current_fg) _section="status_bar"; _key="window_status_current_fg" ;;
      tmux_conf_theme_window_status_current_bg) _section="status_bar"; _key="window_status_current_bg" ;;
      tmux_conf_theme_window_status_current_attr) _section="status_bar"; _key="window_status_current_attr" ;;
      tmux_conf_theme_window_status_activity_fg) _section="status_bar"; _key="window_status_activity_fg" ;;
      tmux_conf_theme_window_status_activity_bg) _section="status_bar"; _key="window_status_activity_bg" ;;
      tmux_conf_theme_window_status_activity_attr) _section="status_bar"; _key="window_status_activity_attr" ;;
      tmux_conf_theme_window_status_bell_fg) _section="status_bar"; _key="window_status_bell_fg" ;;
      tmux_conf_theme_window_status_bell_bg) _section="status_bar"; _key="window_status_bell_bg" ;;
      tmux_conf_theme_window_status_bell_attr) _section="status_bar"; _key="window_status_bell_attr" ;;
      tmux_conf_theme_window_status_last_fg) _section="status_bar"; _key="window_status_last_fg" ;;
      tmux_conf_theme_window_status_last_bg) _section="status_bar"; _key="window_status_last_bg" ;;
      tmux_conf_theme_window_status_last_attr) _section="status_bar"; _key="window_status_last_attr" ;;
      tmux_conf_theme_clock_colour) _section="status_bar"; _key="clock_colour" ;;
      tmux_conf_theme_clock_style) _section="status_bar"; _key="clock_style" ;;
      tmux_conf_theme_pairing) _section="indicators"; _key="pairing" ;;
      tmux_conf_theme_pairing_fg) _section="indicators"; _key="pairing_fg" ;;
      tmux_conf_theme_pairing_bg) _section="indicators"; _key="pairing_bg" ;;
      tmux_conf_theme_pairing_attr) _section="indicators"; _key="pairing_attr" ;;
      tmux_conf_theme_prefix) _section="indicators"; _key="prefix" ;;
      tmux_conf_theme_prefix_fg) _section="indicators"; _key="prefix_fg" ;;
      tmux_conf_theme_prefix_bg) _section="indicators"; _key="prefix_bg" ;;
      tmux_conf_theme_prefix_attr) _section="indicators"; _key="prefix_attr" ;;
      tmux_conf_theme_mouse) _section="indicators"; _key="mouse" ;;
      tmux_conf_theme_mouse_fg) _section="indicators"; _key="mouse_fg" ;;
      tmux_conf_theme_mouse_bg) _section="indicators"; _key="mouse_bg" ;;
      tmux_conf_theme_mouse_attr) _section="indicators"; _key="mouse_attr" ;;
      tmux_conf_theme_root) _section="indicators"; _key="root" ;;
      tmux_conf_theme_root_fg) _section="indicators"; _key="root_fg" ;;
      tmux_conf_theme_root_bg) _section="indicators"; _key="root_bg" ;;
      tmux_conf_theme_root_attr) _section="indicators"; _key="root_attr" ;;
      tmux_conf_theme_synchronized) _section="indicators"; _key="synchronized" ;;
      tmux_conf_theme_synchronized_fg) _section="indicators"; _key="synchronized_fg" ;;
      tmux_conf_theme_synchronized_bg) _section="indicators"; _key="synchronized_bg" ;;
      tmux_conf_theme_synchronized_attr) _section="indicators"; _key="synchronized_attr" ;;
      tmux_conf_theme_left_separator_main) _section="separators"; _key="left_main" ;;
      tmux_conf_theme_left_separator_sub) _section="separators"; _key="left_sub" ;;
      tmux_conf_theme_right_separator_main) _section="separators"; _key="right_main" ;;
      tmux_conf_theme_right_separator_sub) _section="separators"; _key="right_sub" ;;
      tmux_conf_battery_bar_symbol_full) _section="battery"; _key="bar_symbol_full" ;;
      tmux_conf_battery_bar_symbol_empty) _section="battery"; _key="bar_symbol_empty" ;;
      tmux_conf_battery_bar_length) _section="battery"; _key="bar_length" ;;
      tmux_conf_battery_bar_palette) _section="battery"; _key="bar_palette" ;;
      tmux_conf_battery_hbar_palette) _section="battery"; _key="hbar_palette" ;;
      tmux_conf_battery_vbar_palette) _section="battery"; _key="vbar_palette" ;;
      tmux_conf_battery_status_charging) _section="battery"; _key="status_charging" ;;
      tmux_conf_battery_status_discharging) _section="battery"; _key="status_discharging" ;;
      tmux_conf_copy_to_os_clipboard) _section="clipboard"; _key="copy_to_os_clipboard" ;;
      tmux_conf_urlscan_options) _section="urlscan"; _key="options" ;;
      tmux_conf_accessibility) _section="accessibility"; _key="enabled" ;;
      tmux_conf_accessibility_keys) _section="accessibility"; _key="keys" ;;
      tmux_conf_accessibility_visual_activity) _section="accessibility"; _key="visual_activity" ;;
      tmux_conf_accessibility_display_time) _section="accessibility"; _key="display_time" ;;
      tmux_conf_accessibility_theme) _section="accessibility"; _key="theme" ;;
      tmux_conf_update_plugins_on_launch) _section="plugins"; _key="update_on_launch" ;;
      tmux_conf_update_plugins_on_reload) _section="plugins"; _key="update_on_reload" ;;
      tmux_conf_uninstall_plugins_on_reload) _section="plugins"; _key="uninstall_on_reload" ;;
      *)
        printf 'Warning: unmapped variable %s (skipped)\n' "$_var" >&2
        _warned_count=$((_warned_count + 1))
        continue
        ;;
    esac

    if [ "$_section" != "$_current_section" ]; then
      [ -n "$_current_section" ] && printf '\n'
      printf '[%s]\n' "$_section"
      _current_section="$_section"
    fi

    case "$_val" in
      true|false) printf '%s = %s\n' "$_key" "$_val" ;;
      ''|*[!0-9]*) printf '%s = "%s"\n' "$_key" "$_val" ;;
      *) printf '%s = %s\n' "$_key" "$_val" ;;
    esac
  done
}

_migrate() {
  _detect_paths

  if [ ! -f "$TMUX_CONF_LOCAL" ]; then
    printf 'No .tmux.conf.local found at %s\n' "$TMUX_CONF_LOCAL" >&2
    return 1
  fi

  if [ ! -f "$TMUX_CONF" ]; then
    printf 'Error: .tmux.conf not found at %s (needed for parser)\n' "$TMUX_CONF" >&2
    return 1
  fi

  _ptcode="$(awk '
    /^# _parse_toml\(\)/ { found=1; depth=0 }
    found {
      s = substr($0, 3)
      for (i=1; i<=length(s); i++) {
        c = substr(s, i, 1)
        if (c == "{") depth++
        if (c == "}") depth--
      }
      print s
      if (found && depth == 0 && s ~ /}/) exit
    }
  ' "$TMUX_CONF")"

  if [ -z "$_ptcode" ]; then
    printf 'Error: cannot extract _parse_toml from %s\n' "$TMUX_CONF" >&2
    return 1
  fi
  eval "$_ptcode"

  _ts="$(date +%Y%m%d-%H%M%S)"
  cp "$TMUX_CONF_LOCAL" "${TMUX_CONF_LOCAL}.pre-toml.${_ts}"

  _migrated_count=0
  _preserved_count=0
  _warned_count=0
  _conditional_depth=0
  _toml_lines=""
  _new_local=""

  while IFS= read -r _line || [ -n "$_line" ]; do
    case "$_line" in
      '%if'*)
        _conditional_depth=$((_conditional_depth + 1))
        _new_local="${_new_local}${_line}
"
        _preserved_count=$((_preserved_count + 1))
        continue
        ;;
      '%endif'*)
        _new_local="${_new_local}${_line}
"
        _preserved_count=$((_preserved_count + 1))
        if [ "$_conditional_depth" -gt 0 ]; then
          _conditional_depth=$((_conditional_depth - 1))
        fi
        continue
        ;;
    esac

    if [ "$_conditional_depth" -gt 0 ]; then
      _new_local="${_new_local}${_line}
"
      _preserved_count=$((_preserved_count + 1))
      continue
    fi

    case "$_line" in
      '#'* )
        _new_local="${_new_local}${_line}
"
        _preserved_count=$((_preserved_count + 1))
        continue
        ;;
      '' )
        _new_local="${_new_local}
"
        continue
        ;;
      *'#!important'*)
        _new_local="${_new_local}${_line}
"
        _preserved_count=$((_preserved_count + 1))
        continue
        ;;
      *'$('*|*'`'*)
        _new_local="${_new_local}${_line}
"
        _preserved_count=$((_preserved_count + 1))
        printf 'Note: preserved shell expression: %s\n' "$_line" >&2
        continue
        ;;
      tmux_conf_*=*)
        _varname="${_line%%=*}"
        _varval="${_line#*=}"
        _toml_lines="${_toml_lines}${_varname}=${_varval}
"
        _new_local="${_new_local}#[migrated-to-toml] ${_line}
"
        _migrated_count=$((_migrated_count + 1))
        continue
        ;;
    esac

    _new_local="${_new_local}${_line}
"
    _preserved_count=$((_preserved_count + 1))
  done < "$TMUX_CONF_LOCAL"

  if [ -n "$_toml_lines" ]; then
    _toml_dir="$(_path_dir "$_toml_path")"
    [ -d "$_toml_dir" ] || mkdir -p "$_toml_dir"
    _tmp_toml="$(_make_temp_file "$_toml_path")" || {
      printf 'Error: cannot create temp file\n' >&2
      return 1
    }
    if ! printf '%s' "$_toml_lines" | _build_migration_toml > "$_tmp_toml"; then
      rm -f "$_tmp_toml"
      printf 'Error: failed to build tmux.toml\n' >&2
      return 1
    fi
    [ -f "$_toml_path" ] && cp "$_toml_path" "${_toml_path}.bak.${_ts}"
    if ! mv "$_tmp_toml" "$_toml_path"; then
      rm -f "$_tmp_toml"
      printf 'Error: failed to write tmux.toml\n' >&2
      return 1
    fi
  fi

  _tmp_local="$(_make_temp_file "$TMUX_CONF_LOCAL")" || {
    printf 'Error: cannot create temp file\n' >&2
    return 1
  }
  printf '%s' "$_new_local" > "$_tmp_local"
  if ! mv "$_tmp_local" "$TMUX_CONF_LOCAL"; then
    rm -f "$_tmp_local"
    printf 'Error: failed to write .tmux.conf.local\n' >&2
    return 1
  fi

  printf 'Migration complete: %d migrated, %d preserved, %d warnings\n' \
    "$_migrated_count" "$_preserved_count" "$_warned_count"
}

_detect_colour_support() {
  case "${COLORTERM:-}" in
    truecolor|24bit) printf 'truecolour'; return ;;
  esac
  case "${TERM:-}" in
    *-256color|*-256colour) printf '256'; return ;;
  esac
  [ -n "${TMUX:-}" ] && {
    printf '256'
    return
  }
  printf 'basic'
}

_hex_to_rgb() {
  _hex6="$1"
  case "$_hex6" in
    [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
    *) _r=""; _g=""; _b=""; return 1 ;;
  esac
  _full=$((0x${_hex6}))
  _r=$((_full / 65536))
  _g=$((_full / 256 % 256))
  _b=$((_full % 256))
}

_preview_colour() {
  _hex_input="$1"
  _label="$2"

  [ "$SR_MODE" = 1 ] && return

  _hex_stripped="${_hex_input#\#}"

  case "$_hex_stripped" in
    [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
    *)
      printf '  %s %s\n' "$_label" "$_hex_input"
      return
      ;;
  esac

  _hex_to_rgb "$_hex_stripped" || {
    printf '  %s %s\n' "$_label" "$_hex_input"
    return
  }

  case "$(_detect_colour_support)" in
    truecolour)
      printf '  %s \033[48;2;%d;%d;%dm    \033[0m %s\n' "$_label" "$_r" "$_g" "$_b" "#$_hex_stripped"
      ;;
    256)
      _ri=$((_r * 5 / 255))
      _gi=$((_g * 5 / 255))
      _bi=$((_b * 5 / 255))
      _idx=$((16 + _ri * 36 + _gi * 6 + _bi))
      printf '  %s \033[48;5;%dm    \033[0m %s\n' "$_label" "$_idx" "#$_hex_stripped"
      ;;
    *)
      printf '  %s #%s\n' "$_label" "$_hex_stripped"
      ;;
  esac
}

_rollback() {
  _show_all=0
  case "${1:-}" in
    --all) _show_all=1 ;;
  esac

  set --
  for _f in "${_toml_path}.bak."*; do
    [ -f "$_f" ] || continue
    set -- "$@" "toml:$_f"
  done
  for _f in "${TMUX_CONF_LOCAL}.pre-toml."*; do
    [ -f "$_f" ] || continue
    set -- "$@" "local:$_f"
  done

  if [ $# -eq 0 ]; then
    printf 'No backups found. Your current configuration is unchanged.\n'
    return 0
  fi

  _total=$#
  _n=1
  for _entry in "$@"; do
    eval "_bk_$_n=\"\$_entry\""
    _n=$((_n + 1))
  done

  _max_display=15
  [ "$_show_all" = 1 ] && _max_display=9999
  printf 'Available restore points:\n'

  _displayed=0
  _i="$_total"
  while [ "$_i" -gt 0 ] && [ "$_displayed" -lt "$_max_display" ]; do
    _displayed=$((_displayed + 1))
    eval "_entry=\"\$_bk_$_i\""
    _type="${_entry%%:*}"
    _path="${_entry#*:}"
    _name="$(basename "$_path")"
    _ts=""
    case "$_name" in
      *.bak.[0-9]*) _ts="${_name##*.bak.}" ;;
      *.pre-toml.[0-9]*) _ts="${_name##*.pre-toml.}" ;;
    esac
    [ -z "$_ts" ] && _ts="(unknown date)"
    printf '  %d) [%s] %s\n' "$_displayed" "$_type" "$_ts"
    _i=$((_i - 1))
  done
  [ "$_total" -gt "$_max_display" ] && printf '  ... and %d older backups (use --rollback --all to see)\n' "$((_total - _max_display))"

  printf '  0) Cancel\n'
  printf 'Selection: '
  read -r _answer || {
    printf 'Cancelled.\n'
    return 0
  }

  case "$_answer" in
    *[!0-9]*) printf 'Invalid selection.\n' >&2; return 1 ;;
  esac
  [ -z "$_answer" ] && {
    printf 'Invalid selection.\n' >&2
    return 1
  }
  [ "$_answer" -eq 0 ] 2>/dev/null && {
    printf 'Cancelled.\n'
    return 0
  }

  if [ "$_answer" -lt 1 ] || [ "$_answer" -gt "$_displayed" ]; then
    printf 'Invalid selection.\n' >&2
    return 1
  fi

  _real_idx=$((_total - _answer + 1))
  eval "_chosen_entry=\"\$_bk_$_real_idx\""

  _chosen_type="${_chosen_entry%%:*}"
  _chosen_path="${_chosen_entry#*:}"

  case "$_chosen_type" in
    toml) _restore_target="$_toml_path" ;;
    local) _restore_target="$TMUX_CONF_LOCAL" ;;
    *) printf 'Unknown backup type: %s\n' "$_chosen_type" >&2; return 1 ;;
  esac

  if [ ! -r "$_chosen_path" ]; then
    printf 'Error: backup file is not readable: %s\n' "$_chosen_path" >&2
    return 1
  fi
  if [ ! -s "$_chosen_path" ]; then
    printf 'Error: backup file is empty: %s\n' "$_chosen_path" >&2
    return 1
  fi
  if [ -L "$_restore_target" ]; then
    printf 'Error: restore target is a symlink (refusing for safety): %s\n' "$_restore_target" >&2
    return 1
  fi

  printf 'Restore %s -> %s? [Y/n] ' "$(basename "$_chosen_path")" "$_restore_target"
  read -r _yn || _yn="n"
  case "$_yn" in
    [Nn]*) printf 'Cancelled.\n'; return 0 ;;
  esac

  _tmp="$(_make_temp_file "$_restore_target")" || {
    printf 'Error: cannot create temp file\n' >&2
    return 1
  }
  if ! cp "$_chosen_path" "$_tmp"; then
    rm -f "$_tmp"
    printf 'Error: failed to copy backup\n' >&2
    return 1
  fi
  if ! mv "$_tmp" "$_restore_target"; then
    rm -f "$_tmp"
    printf 'Error: failed to restore\n' >&2
    return 1
  fi

  printf 'Restored from %s\n' "$(basename "$_chosen_path")"
}

# --- Signal Handling ---
trap '_die "Setup cancelled. No changes written."' INT TERM

# --- Main ---
main() {
  _detect_paths

  # CLI dispatch
  case "${1:-}" in
    --rollback) shift; _rollback "$@"; exit $? ;;
    --migrate) _migrate; exit $? ;;
    --help|-h) printf 'Usage: setup-wizard.sh [--rollback [--all] | --migrate | --help]\n'; exit 0 ;;
  esac

  # Env-var dispatch for testing
  if [ "${WIZARD_MIGRATE_ONLY:-}" = 1 ]; then
    _migrate
    exit $?
  fi

  _load_defaults
  _load_existing

  # Screen reader detection
  if _confirm "Are you using a screen reader?"; then
    SR_MODE=1
  else
    SR_MODE=0
  fi

  # Mode selection
  _choose "Setup mode" "Quick setup (8 questions)" "Preset" "Preset + customize"
  case $_answer in
    1) _ask_quick ;;
    2)
      _choose "Preset" "Minimal" "Power user" "Accessible"
      case $_answer in
        1) _preset_minimal ;;
        2) _preset_power_user ;;
        3) _preset_accessible ;;
      esac
      ;;
    3)
      _choose "Start from" "Minimal" "Power user" "Accessible"
      case $_answer in
        1) _preset_minimal ;;
        2) _preset_power_user ;;
        3) _preset_accessible ;;
      esac
      _ask_quick
      ;;
  esac

  _review

  if ! _confirm "Apply these settings?"; then
    _die "Cancelled. No changes written."
  fi

  _transactional_write
  _reload
}

# Allow sourcing for unit tests
[ "${WIZARD_SOURCE_ONLY:-}" = 1 ] && return 0 2>/dev/null || true
main "$@"
