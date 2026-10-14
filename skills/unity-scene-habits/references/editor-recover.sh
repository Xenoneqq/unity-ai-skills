#!/usr/bin/env bash
# Bring back an editor that stopped answering the Unity CLI, for the connected path. A template:
# copy it into the project once and check the lines marked CHECK against your editor.
# Why: connected-editor.md, "On demand, then close". Run it only on an editor an agent opened,
# or one the user handed over for the session; never on an editor the user is working in.
#
#   editor-recover.sh [project-path]     (default: UNITY_PROJECT_PATH, else the current directory)
#
# Order: answers already -> screen locked -> leave Play mode -> close and reopen the editor.
# A locked screen stalls the editor's main thread and a relaunch cannot fix that, but batch mode
# needs no display. So by default a locked screen closes the editor and exits 6: carry on in
# batch mode. Set LOCK_WAIT=<seconds> to wait for an unlock instead.
#
# Exit: 0 the editor answers, 4 still locked after LOCK_WAIT, 5 the relaunch never answered
# (likely a startup dialog: Safe Mode, scene recovery; ask the user), 6 screen locked, editor
# closed: switch to batch mode.

set -u
PROJECT=$(cd "${1:-${UNITY_PROJECT_PATH:-.}}" && pwd) || exit 2
LOCK_WAIT=${LOCK_WAIT:-0}   # seconds to wait for an unlock; 0 closes and switches to batch
UP_WAIT=${UP_WAIT:-900}     # seconds to wait for a relaunched editor

say() { echo "editor-recover: $*"; }
answers() {   # CHECK: the status command's name on your editor
  unity command editor_status --project-path "$PROJECT" --json --no-banner 2>/dev/null |
    grep -q '"success": *true'
}
wait_for() {
  local secs=$1 step=$2 i=0
  while [ $i -lt "$secs" ]; do answers && return 0; sleep "$step"; i=$((i + step)); done
  return 1
}

# Screen lock, per platform. Where it cannot be told, report unlocked and let the relaunch try.
locked() {
  case "$(uname -s)" in
    Darwin) ioreg -n Root -d1 -a 2>/dev/null | grep -A1 CGSSessionScreenIsLocked | grep -q true ;;
    Linux)  [ -n "${XDG_SESSION_ID:-}" ] &&
              loginctl show-session "$XDG_SESSION_ID" -p LockedHint 2>/dev/null | grep -q yes ;;
    MINGW*|MSYS*|CYGWIN*) tasklist 2>/dev/null | grep -qi '^LogonUI.exe' ;;   # lock screen shown
    *) return 1 ;;
  esac
}

editor_running() {
  command -v pgrep > /dev/null || return 0   # cannot tell: assume it is, keep the lockfile
  pgrep -if -- "-projectpath.*$PROJECT" > /dev/null
}

close_editor() {
  say "closing the editor (unsaved changes are lost)"
  unity close "$PROJECT" --timeout 60 --force > /dev/null 2>&1
  sleep 5
  editor_running || rm -f "$PROJECT/Temp/UnityLockfile"
  rm -f "$PROJECT"/Assets/InitTestScene*.unity "$PROJECT"/Assets/InitTestScene*.unity.meta
}

answers && { say "editor answers"; exit 0; }

if locked; then
  if [ "$LOCK_WAIT" -le 0 ]; then
    close_editor
    say "screen is locked; editor closed. Carry on in batch mode, which needs no display."
    exit 6
  fi
  say "screen is locked; waiting up to ${LOCK_WAIT}s for an unlock"
  i=0
  while locked && [ $i -lt "$LOCK_WAIT" ]; do sleep 60; i=$((i + 60)); done
  locked && { say "still locked"; exit 4; }
  wait_for 120 10 && { say "editor answers after unlock"; exit 0; }
fi

say "leaving Play mode"
unity command editor_stop --project-path "$PROJECT" --no-banner > /dev/null 2>&1   # CHECK: name
wait_for 60 10 && { say "editor answers after editor_stop"; exit 0; }

close_editor
say "opening the editor"
unity open "$PROJECT" > /dev/null 2>&1 &
wait_for "$UP_WAIT" 15 && { say "editor answers after relaunch"; exit 0; }
say "relaunched editor never answered (a startup dialog: Safe Mode, scene recovery?). Ask the user."
exit 5
