#!/usr/bin/env zsh
# subagent-chain.sh — Squad Agent notification + pipeline chaining hook
# Handles both SubagentStart and SubagentStop events
# Registered automatically by install.sh
#
# Cross-platform: macOS (osascript), Linux (notify-send), Windows/WSL (powershell)
# Claude Code is a TUI app — stdout/stderr from SubagentStart/Stop hooks
# are not displayed in the terminal. OS-native notifications are used instead.
set -uo pipefail

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
cat > "$TMPFILE"

if ! command -v jq &>/dev/null; then exit 0; fi
if ! jq empty < "$TMPFILE" 2>/dev/null; then exit 0; fi

EVENT=$(jq -r '.hook_event_name // empty' < "$TMPFILE")
AGENT_NAME=$(jq -r '.agent_type // .agent_name // empty' < "$TMPFILE")

# Only handle squad-* agents
case "$AGENT_NAME" in squad-*) ;; *) exit 0 ;; esac

DISPLAY_NAME="${AGENT_NAME#squad-}"

# --- Cross-platform notification ---
notify() {
  local title="$1" body="$2"

  case "$(uname -s)" in
    Darwin)
      osascript -e "display notification \"${body}\" with title \"${title}\"" 2>/dev/null &
      ;;
    Linux)
      if command -v notify-send &>/dev/null; then
        notify-send "${title}" "${body}" 2>/dev/null &
      fi
      ;;
    CYGWIN*|MINGW*|MSYS*)
      powershell.exe -Command "[void](New-Object -ComObject Wscript.Shell).Popup('${body}',3,'${title}',64)" 2>/dev/null &
      ;;
  esac

  # WSL detection (Linux kernel but Windows host)
  if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
    powershell.exe -Command "[void](New-Object -ComObject Wscript.Shell).Popup('${body}',3,'${title}',64)" 2>/dev/null &
  fi
}

play_sound() {
  local sound_name="$1"

  case "$(uname -s)" in
    Darwin)
      afplay "/System/Library/Sounds/${sound_name}.aiff" 2>/dev/null &
      ;;
    Linux)
      if command -v paplay &>/dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &
      elif command -v aplay &>/dev/null; then
        aplay /usr/share/sounds/sound-icons/xylofon.wav 2>/dev/null &
      fi
      ;;
  esac
}

# --- Event handling ---
if [ "$EVENT" = "SubagentStart" ]; then
  notify "🚀 Squad: ${DISPLAY_NAME}" "Status: RUNNING"
  play_sound "Pop"

elif [ "$EVENT" = "SubagentStop" ]; then
  NEXT=""
  case "$AGENT_NAME" in
    "squad-plan")    NEXT="→ implement, then /squad-review" ;;
    "squad-review")  NEXT="→ /squad-refactor or /squad-qa" ;;
    "squad-refactor") NEXT="→ /squad-review to verify" ;;
    "squad-qa")      NEXT="→ /squad-gitops commit" ;;
    "squad-debug")   NEXT="→ implement the fix" ;;
    "squad-docs")    NEXT="Documentation updated." ;;
    "squad-gitops")  NEXT="Git artifacts generated." ;;
    "squad-audit")   NEXT="Address findings before deploy." ;;
  esac
  notify "✅ Squad: ${DISPLAY_NAME}" "COMPLETED ${NEXT}"
  play_sound "Glass"
fi

exit 0
