#!/usr/bin/env bash
# Run Unity tests in the user's open editor through the Unity CLI, with the preflight that makes
# the run trustworthy. A template: copy it into the project once and check the lines marked
# CHECK against your editor (`unity command --query <name> --detail full`).
# Why each step exists: connected-editor.md, "Running tests from a worker".
#
#   run-tests.sh [--mode EditMode|PlayMode] [--category NAME] [--save-scenes] [--lock DIR] [NAME...]
#
# NAMEs run one after another, since --filter is a substring match and "A|B" matches nothing,
# so rerunning only the failures is one call. With no NAME and no --category, everything runs.
# --save-scenes saves open scenes the reload marked dirty; use it only if the project allows it.
# --lock DIR takes a mkdir lock first, so only one agent drives the editor at a time.
# Set UNITY_PROJECT_PATH when several editors are open.
#
# Exit: 0 passed, 1 a test failed or nothing ran, 2 preflight failed, 3 the editor stopped
# answering (likely a modal dialog: stop and ask the user), 4 lock not acquired.

set -u

MODE=EditMode CATEGORY= SAVE=0 LOCK= NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)        MODE=$2; shift 2 ;;
    --category)    CATEGORY=$2; shift 2 ;;
    --save-scenes) SAVE=1; shift ;;
    --lock)        LOCK=$2; shift 2 ;;
    -h|--help)     sed -n '2,16p' "$0"; exit 0 ;;
    *)             NAMES+=("$1"); shift ;;
  esac
done
if [ -n "$CATEGORY" ] && [ ${#NAMES[@]} -gt 0 ]; then
  echo "run-tests: give --category or names, not both"; exit 2
fi

FOCUS_CMD=${FOCUS_CMD-unity command editor_focus}   # CHECK: the name; FOCUS_CMD= turns it off
LOCK_TRIES=${LOCK_TRIES:-60}     # x 10 s
READY_TRIES=${READY_TRIES:-60}   # x 5 s
PLAY_TRIES=${PLAY_TRIES:-45}     # x 20 s
RUN_TIMEOUT=${RUN_TIMEOUT:-600}  # seconds, per EditMode run

OUT=$(mktemp -d)
cleanup() {
  rm -rf "$OUT"
  if [ -n "$LOCK" ] && [ "$(cat "$LOCK/owner" 2>/dev/null)" = "$$" ]; then
    rm -f "$LOCK/owner" "$LOCK/owner.note"; rmdir "$LOCK"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

say() { echo "run-tests: $*"; }
die() { say "$2"; exit "$1"; }

# One CLI call, output to a file so nothing in the shell rewrites it. Returns the CLI's status.
u() { unity command "$@" --json --no-banner > "$OUT/last.json" 2>&1; }

# A main-thread timeout means a modal dialog, not a slow editor. Never keep polling past it.
stuck() {
  if grep -qiE 'timed? ?out|main thread' "$OUT/last.json"; then
    die 3 "editor stopped answering on '$1': a modal dialog, or a run longer than its timeout. Stop and ask the user to look."
  fi
}

# jget KEY [SCOPE]: first value of KEY in the last payload (inside the first SCOPE object if
# given), case-insensitive, with JSON-encoded strings decoded.
jget() {
  python3 - "$OUT/last.json" "$@" <<'PY'
import sys, json
def dec(x):
    if isinstance(x, str):
        try: return dec(json.loads(x))
        except Exception: return x
    if isinstance(x, dict): return {k: dec(v) for k, v in x.items()}
    if isinstance(x, list): return [dec(v) for v in x]
    return x
def find(x, k):
    if isinstance(x, dict):
        for kk, v in x.items():
            if kk.lower() == k: return v
        x = list(x.values())
    if isinstance(x, list):
        for v in x:
            r = find(v, k)
            if r is not None: return r
    return None
try: d = dec(json.load(open(sys.argv[1])))
except Exception: sys.exit(0)
if len(sys.argv) > 3:
    s = find(d, sys.argv[3].lower())
    d = d if s is None else s
v = find(d, sys.argv[2].lower())
if v is not None:
    print(json.dumps(v) if isinstance(v, (dict, list)) else str(v).lower())
PY
}

# Failed test names in the last payload. CHECK: the result field names on your editor.
failed_names() {
  python3 - "$OUT/last.json" <<'PY'
import sys, json
def dec(x):
    if isinstance(x, str):
        try: return dec(json.loads(x))
        except Exception: return x
    if isinstance(x, dict): return {k: dec(v) for k, v in x.items()}
    if isinstance(x, list): return [dec(v) for v in x]
    return x
def walk(x):
    if isinstance(x, dict):
        low = {k.lower(): v for k, v in x.items()}
        state = next((str(low[k]).lower() for k in ('result', 'outcome', 'resultstate', 'status')
                      if k in low and not isinstance(low[k], (dict, list))), '')
        name = low.get('fullname') or low.get('name')
        if name and state.startswith('fail'): print(name)
        for v in x.values(): walk(v)
    elif isinstance(x, list):
        for v in x: walk(v)
try: walk(dec(json.load(open(sys.argv[1]))))
except Exception: pass
PY
}

focus() { [ -n "$FOCUS_CMD" ] && $FOCUS_CMD > /dev/null 2>&1; true; }
ev()    { u eval "$1"; }

# Readiness: isCompiling and isUpdating both false, twice in a row, with focus. Valid only after
# a focused recompile; never judge readiness by CPU load.
wait_ready() {
  local n=0 ok=0
  while [ $ok -lt 2 ]; do
    focus
    if ev 'return (UnityEditor.EditorApplication.isCompiling || UnityEditor.EditorApplication.isUpdating) ? "busy" : "ready";'; then
      if [ "$(jget result)" = "ready" ]; then ok=$((ok + 1)); else ok=0; fi
    else
      stuck readiness; ok=0   # otherwise the server is restarting during a reload
    fi
    n=$((n + 1)); [ $n -ge "$READY_TRIES" ] && die 2 "editor never became ready"
    [ $ok -lt 2 ] && sleep 5
  done
}

# 0. The editor lock: bounded wait, never proceeds without it, always released on exit.
if [ -n "$LOCK" ]; then
  n=0
  until mkdir "$LOCK" 2>/dev/null; do
    n=$((n + 1))
    [ $n -ge "$LOCK_TRIES" ] &&
      die 4 "editor lock $LOCK still held by $(cat "$LOCK/owner.note" 2>/dev/null || echo unknown); not running"
    sleep 10
  done
  echo "$$" > "$LOCK/owner"
  echo "${AGENT_NAME:-pid $$} since $(date +%H:%M:%S)" > "$LOCK/owner.note"
fi

# 1. Pick up changed scripts and compile them with focus: an unfocused editor stalls.
ev 'UnityEditor.AssetDatabase.Refresh(); return "ok";' ||
  { stuck refresh; die 2 "refresh failed: $(head -c 300 "$OUT/last.json")"; }
u recompile --focus true ||
  { stuck recompile; die 2 "recompile failed: $(head -c 300 "$OUT/last.json")"; }
n=0
until u recompile_status && grep -qi 'completed' "$OUT/last.json"; do   # CHECK: payload shape
  stuck recompile_status
  n=$((n + 1)); [ $n -ge "$READY_TRIES" ] && die 2 "compile did not complete; see 'unity command recompile_status'"
  focus; sleep 5
done
wait_ready
u console_status
[ "$(jget compilationFailed)" = "false" ] ||   # CHECK: payload shape
  die 2 "compilation failed; read 'unity command console --level error --tail 40'"

# 2-4. Before every run: a fresh domain, since the runner starts once per domain; the readiness
# gate; and no dirty scene, since a dirty scene makes run_tests open a modal save dialog.
prepare() {
  ev 'UnityEditor.EditorUtility.RequestScriptReload(); return "ok";' ||
    { stuck reload; die 2 "reload request failed"; }
  sleep 5
  wait_ready
  local code='var dirty = 0;
for (var i = 0; i < UnityEngine.SceneManagement.SceneManager.sceneCount; i++) {
  var s = UnityEngine.SceneManagement.SceneManager.GetSceneAt(i);
  if (s.isDirty && SAVE && !string.IsNullOrEmpty(s.path)) UnityEditor.SceneManagement.EditorSceneManager.SaveScene(s);
  if (s.isDirty) dirty++;
}
return dirty == 0 ? "clean" : "dirty";'
  if [ "$SAVE" = 1 ]; then code=${code//SAVE/true}; else code=${code//SAVE/false}; fi
  ev "$code" || { stuck scenes; die 2 "scene check failed"; }
  [ "$(jget result)" = "clean" ] ||
    die 2 "an open scene is dirty and run_tests would open a modal save dialog. Save it (--save-scenes, if the project allows) or ask the user."
}

# 5. One run, keeping focus while PlayMode polls. Sets T (total) and F (failed); leaves the run's
# payload in last.json.
run_once() {
  local args=(run_tests --mode "$MODE" --timeout "$RUN_TIMEOUT")
  [ -n "$CATEGORY" ] && args+=(--filter_type category --filter "$CATEGORY")   # CHECK: flag names
  [ -n "$1" ] && args+=(--filter "$1")
  focus
  if [ "$MODE" = PlayMode ]; then
    args+=(--async_tests true)
    u "${args[@]}" || { stuck run_tests; die 2 "run_tests did not start: $(head -c 300 "$OUT/last.json")"; }
    local n=0
    while :; do
      sleep 20; focus
      u test_status || stuck test_status
      case "$(jget status)" in *complete*|*finish*|*done*) break ;; esac   # CHECK: payload shape
      n=$((n + 1)); [ $n -ge "$PLAY_TRIES" ] && die 2 "PlayMode run did not finish; see 'unity command test_status'"
    done
  elif ! u "${args[@]}" && [ -z "$(jget total summary)" ]; then
    stuck run_tests; die 2 "run_tests failed: $(head -c 300 "$OUT/last.json")"
  fi
  T=$(jget total summary); F=$(jget failed summary)   # CHECK: summary field names
  case "$T" in ''|*[!0-9]*) T=0 ;; esac
  case "$F" in ''|*[!0-9]*) F=0 ;; esac
}

TOTAL=0 FAILED=0 RUNS=0 FAILS=() NORUN=()
[ ${#NAMES[@]} -eq 0 ] && NAMES=("")
for name in "${NAMES[@]}"; do
  label=${name:-${CATEGORY:-all}}
  prepare; run_once "$name"; RUNS=$((RUNS + 1))
  if [ "$T" = 0 ]; then
    # 6. An instant "total 0" usually means the runner did not start in this domain. Once more.
    say "$label: total 0, reloading and rerunning once"
    prepare; run_once "$name"; RUNS=$((RUNS + 1))
    [ "$T" = 0 ] && { NORUN+=("$label"); continue; }
  fi
  TOTAL=$((TOTAL + T)); FAILED=$((FAILED + F))
  before=${#FAILS[@]}
  while IFS= read -r x; do [ -n "$x" ] && FAILS+=("$x"); done < <(failed_names)
  [ "$F" != 0 ] && [ ${#FAILS[@]} -eq "$before" ] && FAILS+=("$label")
done

if [ ${#FAILS[@]} -eq 0 ] && [ ${#NORUN[@]} -eq 0 ]; then
  say "$MODE ok: $TOTAL tests passed in $RUNS run(s)"
  exit 0
fi
[ ${#NORUN[@]} -gt 0 ] && say "no tests ran for: ${NORUN[*]} (wrong filter, or the runner did not start)"
[ ${#FAILS[@]} -gt 0 ] && say "rerun only the failures: $0 --mode $MODE ${FAILS[*]}"
say "$MODE FAILED: $FAILED of $TOTAL failed in $RUNS run(s)"
exit 1
