#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$PROJECT_DIR/scripts/fixtures/insertion-target.html"
LOG_DIR="$HOME/Library/Application Support/MacVoice/Diagnostics"
TODAY="$(date +%Y-%m-%d)"
LOG_FILE="$LOG_DIR/macvoice-diagnostics-$TODAY.log"

usage() {
  cat <<USAGE
Usage: $0 prepare|say-insert|tail|latest-input

prepare      Open the browser fixture that catches incorrect paste attempts.
say-insert   Play a spoken "ok insert" prompt through macOS speech output.
tail         Follow today's MacVoice diagnostic log input/pipeline/insert lines.
latest-input Print recent insertion-related diagnostic lines.
USAGE
}

case "${1:-}" in
  prepare)
    open "file://$FIXTURE"
    echo "Opened fixture: $FIXTURE"
    echo "Now focus the real source textbox (for example Codex), trigger MacVoice, switch back to the browser fixture, then run: $0 say-insert"
    ;;
  say-insert)
    say "ok insert"
    ;;
  tail)
    touch "$LOG_FILE"
    tail -n 0 -F "$LOG_FILE" | grep -E '\[(input|pipeline|insert|shortcut)\]'
    ;;
  latest-input)
    if [[ -f "$LOG_FILE" ]]; then
      grep -E '\[(input|pipeline|insert|shortcut)\]' "$LOG_FILE" | tail -80
    else
      echo "No log file yet: $LOG_FILE"
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
