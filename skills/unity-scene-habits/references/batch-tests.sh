#!/usr/bin/env bash
# Run Unity tests in batch mode, editor closed, through the Unity CLI's `unity test`. A template:
# copy it into the project once and check the lines marked CHECK against your CLI version.
# Why batch is the default: batch-mode.md. The connected-editor runner is run-tests.sh.
#
#   batch-tests.sh [--mode EditMode|PlayMode] [--category NAME] [--nographics] [NAME...]
#
# NAMEs run one call each, since `unity test --filter` takes one pattern, so rerunning only the
# failures is one call. With no NAME and no --category, everything in the mode runs.
# --category '!NAME' leaves a category out, e.g. '!Screenshot' to keep older shots on disk.
# --nographics is for suites with no rendering; screenshot tests need graphics.
# Set UNITY_PROJECT_PATH to the Unity project (default: the current directory).
#
# Exit: 0 passed, 1 a test failed or nothing ran, 2 setup failed (an editor holds the project,
# no licence, a compile error, or no report written), 3 a run hit RUN_TIMEOUT (the other names
# still run).

set -u

MODE=EditMode CATEGORY= NOGFX=0 NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)       MODE=$2; shift 2 ;;
    --category)   CATEGORY=$2; shift 2 ;;
    --nographics) NOGFX=1; shift ;;
    -h|--help)    sed -n '2,15p' "$0"; exit 0 ;;
    *)            NAMES+=("$1"); shift ;;
  esac
done
if [ -n "$CATEGORY" ] && [ ${#NAMES[@]} -gt 0 ]; then
  echo "batch-tests: give --category or names, not both"; exit 2
fi

ROOT=${UNITY_PROJECT_PATH:-.}
RUN_TIMEOUT=${RUN_TIMEOUT:-900}   # seconds, per call
PY=; for c in python3 python; do "$c" -c pass 2>/dev/null && { PY=$c; break; }; done   # a Windows Store stub fails here
[ -n "$PY" ] || { echo "batch-tests: needs python3 or python"; exit 2; }

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
trap 'exit 130' INT TERM

say() { echo "batch-tests: $*"; }
die() { say "$2"; exit "$1"; }

# Setup failures show in the logs, not the report: the run never got to the tests. The editor
# log carries compile errors; the CLI's own output carries the rest.
setup_failed() {
  local log=$OUT/$1.all
  cat "$OUT/$1.log" "$OUT/$1.editor.log" > "$log" 2>/dev/null
  [ "$2" -ge $((RUN_TIMEOUT - 5)) ] && { say "$3: timed out after ${2}s with no report"; return 3; }
  grep -qE 'error CS[0-9]{4}' "$log" &&
    die 2 "compile error, no tests ran: $(grep -m3 -E 'error CS[0-9]{4}' "$log" | tr '\n' ' ')"
  grep -qiE 'No valid Unity Editor license' "$log" &&
    die 2 "no Unity licence; only the user can sign in"
  grep -qiE 'already open|another Unity instance|UnityLockfile|project lock' "$log" &&   # CHECK: wording
    die 2 "an editor holds the project; batch cannot run until it is closed. Do not close the user's editor."
  die 2 "no results report; see the last lines: $(tail -5 "$log" | tr '\n' ' ')"
}

# Totals and failed names from one NUnit report: "T P F" on the first line, then one failed name
# per line with its message. A fixture whose setup failed counts failures without failed test
# cases, so failed suites are listed when no case is.
summarize() {
  "$PY" - "$1" <<'PY'
import sys, xml.etree.ElementTree as ET
try: root = ET.parse(sys.argv[1]).getroot()
except Exception: print("0 0 0"); sys.exit(0)
run = root if root.tag == "test-run" else root.find(".//test-run") or root
a = run.attrib
print(a.get("total", "0"), a.get("passed", "0"), a.get("failed", "0"))
def failed(nodes):
    out = []
    for n in nodes:
        if n.get("result", "").lower().startswith("fail"):
            msg = (n.findtext("./failure/message") or "").strip().splitlines()
            out.append(f'{n.get("fullname") or n.get("name")} | {msg[0] if msg else ""}')
    return out
lines = failed(root.iter("test-case"))
if not lines:
    suites = [n for n in root.iter("test-suite") if n.get("type") != "Assembly"]
    lines = failed(n for n in suites if not any(
        c.get("result", "").lower().startswith("fail") for c in n.iter("test-suite") if c is not n))
print("\n".join(lines))
PY
}

run_once() {
  local name=$1 i=$2
  local args=(test "$ROOT" --mode "$MODE" --output "$OUT/$i.xml" --timeout "$RUN_TIMEOUT" --no-banner)
  [ -n "$name" ] && args+=(--filter "$name")
  local extra=()
  [ -n "$CATEGORY" ] && extra+=(-testCategory "$CATEGORY")
  [ "$NOGFX" = 1 ] && extra+=(-nographics)
  extra+=(-logFile "$OUT/$i.editor.log")
  args+=(-- "${extra[@]}")
  local start=$SECONDS
  unity "${args[@]}" > "$OUT/$i.log" 2>&1
  [ -s "$OUT/$i.xml" ] || setup_failed "$i" $((SECONDS - start)) "${name:-${CATEGORY:-all}}"
}

TOTAL=0 FAILED=0 RUNS=0 FAILS=() NORUN=() TIMEDOUT=()
[ ${#NAMES[@]} -eq 0 ] && NAMES=("")
for name in "${NAMES[@]}"; do
  label=${name:-${CATEGORY:-all}}
  RUNS=$((RUNS + 1))
  run_once "$name" "$RUNS" || { TIMEDOUT+=("$label"); continue; }
  before=${#FAILS[@]}
  { read -r T _ F; while IFS= read -r line; do [ -n "$line" ] && FAILS+=("$line"); done; } \
    < <(summarize "$OUT/$RUNS.xml")
  case "$T" in ''|*[!0-9]*) T=0 ;; esac
  case "$F" in ''|*[!0-9]*) F=0 ;; esac
  [ "$T" = 0 ] && { NORUN+=("$label"); continue; }
  [ "$F" != 0 ] && [ ${#FAILS[@]} -eq "$before" ] && FAILS+=("$label | $F failed, no failing test named in the report")
  TOTAL=$((TOTAL + T)); FAILED=$((FAILED + F))
done

if [ ${#TIMEDOUT[@]} -gt 0 ]; then
  say "timed out: ${TIMEDOUT[*]}; raise RUN_TIMEOUT if the suite is just slow"
  [ ${#FAILS[@]} -eq 0 ] && [ ${#NORUN[@]} -eq 0 ] && exit 3
fi
if [ ${#FAILS[@]} -eq 0 ] && [ ${#NORUN[@]} -eq 0 ]; then
  say "$MODE ok: $TOTAL tests passed in $RUNS run(s)"
  exit 0
fi
[ ${#NORUN[@]} -gt 0 ] && say "no tests ran for: ${NORUN[*]} (wrong filter or category)"
if [ ${#FAILS[@]} -gt 0 ]; then
  for f in "${FAILS[@]}"; do say "failed: $f"; done
  rerun=() ; for f in "${FAILS[@]}"; do rerun+=("${f%% |*}"); done
  say "rerun only the failures: $0 --mode $MODE $(printf '%q ' "${rerun[@]}")"
fi
say "$MODE FAILED: $FAILED of $TOTAL failed in $RUNS run(s)"
exit 1
