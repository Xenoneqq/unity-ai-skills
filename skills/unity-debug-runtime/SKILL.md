---
name: unity-debug-runtime
description: >
  Work out why a Unity game is running wrong — it crashes, it throws, a reference is null in
  play mode but looks fine in the inspector, it stutters, the frame rate sags — on a project
  with no automated tests to tell you. Evidence before theories: reproduce it on demand, read
  the right log, read the stack trace properly, narrow it, confirm the fix killed it. Use when:
  "why does my game crash", "NullReferenceException", "MissingReferenceException", "the
  referenced script on this Behaviour is missing", "my reference is null at runtime", "the game
  is stuttering", "frame rate drops after a while", "GC spike", "it works in the editor but not
  in the build", "where is the Unity log", "how do I profile this", "when did this break", or
  "/unity-debug-runtime".
---

# Debugging a Unity game at runtime

**Evidence before theories.** A Unity bug reads like three plausible stories at once, and
reading code picks whichever one you thought of first. Get a fact, then pick.

Four moves, in this order: **reproduce → locate → narrow → confirm.** Skip the reproduce and
you cannot tell a fix from a coincidence. Skip the confirm and you never find out which it was.

This is the half [`unity-agent-worker`](../unity-agent-worker/references/verification.md) leaves
open: its ladder says *whether* something is broken, this says *why*. What the code should look
like afterwards is [`unity-coding-habits`](../unity-coding-habits/SKILL.md).

## 1. Name the symptom before touching anything

Profiling a logic bug and reading stack traces for a frame-rate bug both find nothing.

| Shape | Looks like | Start at |
|---|---|---|
| It throws | Red in the console, a stack trace | §3, §4 |
| It misbehaves quietly | Wrong value, nothing happens, nothing logged | §2, then §5 |
| It is slow | Low frame rate, stutter, climbing memory | §6 |
| It dies | Process gone, no managed trace | §3 — the crash file, not the console |

## 2. Make it reproduce, before reading any code

Write the steps down and run them three times. Three out of three is a bug; one out of three is
an observation, and the next move is to make it deterministic, not to start guessing.

- **Seed the randomness.** `Random.InitState(seed)` at startup; save and restore `Random.state`
  around anything that must not disturb the sequence.
- **Cut the scene down.** A copy with everything off the path deleted. If the bug survives you
  have removed half the suspects for free; if it vanishes, what you deleted is a suspect.
- **Pin the frame cadence.** Timing bugs move when the frame rate moves.
  `Time.captureDeltaTime` drives a fixed step; `Application.targetFrameRate` and
  `QualitySettings.vSyncCount` decide whether the monitor's refresh rate is in your variables.

Unity's physics is not reproducible across platforms, editor versions or frame rates, so a
physics bug that will not repeat is not necessarily intermittent — it may be timing you have
not fixed yet. [references/reproducing.md](references/reproducing.md) has the rest, including
what a release build hides and when a development build is the only honest place to test.

## 3. Find the log that actually holds the evidence

**The console is a view, not the record.** `Collapse` shows only the first of a repeating
message — how a once-per-frame exception comes to read as one stray error — and `Clear on Play`
discards the previous run. Turn both off before trusting what you see, and turn on `Error
Pause`, which pauses play mode on `Debug.LogError` so the scene is still standing.

The log file is the record: it survives the editor closing, does not collapse, and for a build
it is all there is. **Verify the path rather than recalling it — it moved.** 2022 LTS and 6000.0
write a global per-user editor log; 6000.5 defaults to `<Project>/Logs/Editor.log` and uses the
global one only with `-useGlobalLog`. `ls -lt` both candidates and trust the one just written
to; from inside a running editor or player, `Application.consoleLogPath` answers it outright.
Every path per platform, the player log, the crash files and the player command-line flags:
[references/log-locations.md](references/log-locations.md).

## 4. Read the stack trace as evidence, not as an address

The top frame is where the exception was **thrown**, rarely where the bug is. Work down to the
first frame in the project's own code, then ask what produced the bad value it passed on — the
bug is usually a frame or two below the first familiar name.

- **Traces are `ScriptOnly` by default** — managed frames only. `Full` adds native frames: what
  a crash inside the engine needs, noise for anything else. Set it per log type in Player
  Settings, from the Console's Stack Trace Logging menu, or with
  `Application.SetStackTraceLogType`. Immediate in the editor; a built player must be rebuilt.
- **An exception in a `MonoBehaviour` callback does not stop the game.** Unity logs it and moves
  to the next callback. The rest of that method never runs — so the visible symptom is often the
  half-finished work, not the red line — and the next frame calls it again.

## 5. The null question: unassigned, destroyed, or genuinely wrong

Most `NullReferenceException` reports in Unity are not logic bugs — they are a serialized field
nobody dragged a value into. One question separates them: **is the field serialized?**

| Cause | In the editor | In a player build |
|---|---|---|
| Serialized field never assigned | `UnassignedReferenceException`, naming field and type | plain `NullReferenceException` |
| Reference to a `Destroy`ed object | `MissingReferenceException`, naming the type | plain `NullReferenceException` |
| The script asset is gone | "The referenced script on this Behaviour (Game Object '…') is missing!" | same message |
| Real logic — a lookup found nothing | `NullReferenceException` | `NullReferenceException` |

The first two rows are **editor-only diagnostics**: those message formats live in the editor
binary and in neither the development nor the release player, so the bug that names itself in
the editor arrives as a bare `NullReferenceException` in a build. When a build throws a null the
editor does not, reproduce it in the editor before theorising — it will usually tell you which
of the four you have, for free. How to confirm each, and the fake-null trap that makes `?.` skip
the check: [references/exception-shapes.md](references/exception-shapes.md).

## 6. Inspect the live state instead of reasoning about it

A running editor answers questions directly. `unity command eval` runs C# against the loaded
project with no recompile and no domain reload: which field is null *now*, what is in that list,
how many of the thing exist. It needs editor **6.0 or newer** with the Pipeline package, and the
mechanics, exit codes and result-reading traps are already in
[`unity-scene-habits`](../unity-scene-habits/references/connected-editor.md) — use those rather
than a version reinvented here — pass `--skill unity-debug-runtime` on calls made from here.
`unity command --runtime <process name>` points the same mechanism at a running player.

With no CLI, the substitutes are cruder but real: `Debug.Log(msg, gameObject)` attaches a context
object, so clicking the message highlights what logged it, and `Error Pause` plus the inspector
beats any number of print statements once the game is stopped in the act.

## 7. Slow is three different bugs needing three different kinds of evidence

| Symptom | Shape in the profiler | Usually |
|---|---|---|
| Steady low frame rate | Every frame costs the same too-much | Per-frame work, or GPU-bound |
| Periodic spike | One frame in N is many times the rest | GC collection, or batched work on a timer |
| One-off hitch | A single huge frame at a nameable moment | Loading, instantiation, shader compilation |

Three caveats decide whether the numbers mean anything:

- **Deep Profiling distorts what it measures.** It hooks every managed call, so it moves the
  costs it reports. Use it to find the neighbourhood, then confirm with `Profiler.BeginSample`
  markers around the suspect.
- **Play mode is not the game.** The editor's UI, inspectors, scene view and asset management
  share the process and the main thread. Unity's own position: Play mode "doesn't give you an
  accurate reflection" of performance on a real device.
- **A release build cannot be profiled at all** — its profiler counters do not exist. Profile a
  **development build**, on the target platform.

Which module answers which question, the build settings that make a player profilable, and
reading GC allocation: [references/profiling.md](references/profiling.md). Code-level causes of
per-frame cost are [`unity-coding-habits`](../unity-coding-habits/references/per-frame.md).

## 8. If it is networked, first work out which side threw

"It doesn't work" in multiplayer is two machines disagreeing, and you were handed one machine's
trace. Collect both logs, establish whether the failing side is server, client or a host being
both at once, and check whether it survives a late join. The reasoning is
[`unity-multiplayer-habits`](../unity-multiplayer-habits/SKILL.md); do not re-derive it here.

## 9. When the log does not say enough, ask git

If it worked before and nothing explains why it stopped, bisect. It finds the commit without
your having a theory at all — `git bisect start`, `bad` on the current commit, `good` on one you
trust, then the §2 reproduction at each step. Three Unity-specific things before starting:

- **Every step reimports.** A different commit means different assets and a rebuilt `Library/`,
  so keep the per-step test as cheap as the bug allows; minutes per step is normal.
- **Never bisect across an editor upgrade.** Check
  `git log --oneline -- ProjectSettings/ProjectVersion.txt` first and bound the range to one
  version — opening the project in a newer editor upgrades it irreversibly, silently.
- **`git bisect run <script>` works** when the reproduction is scriptable. The script must exit
  non-zero on the bug and you must have watched it do so once, or the bisect confidently returns
  the wrong commit.

## 10. Confirm, and say only what you proved

A fix is confirmed when the reproduction from §2 fails before it and passes after it, and **you
watched it fail**. A repro you never saw fail proves nothing. Then be exact, in the words the
ladder uses ([`unity-agent-worker`](../unity-agent-worker/references/verification.md)):

- What reproduces the bug, and where it stopped reproducing.
- Whether that was the editor, a development build, or the target. Three claims, not one.
- What you narrowed to but could not prove. "The spike goes when I disable the spawner" is a
  finding, not a diagnosis, and saying which costs nothing.

Never report a performance win from Play mode numbers alone, and never report a build-only bug
fixed because the editor stopped throwing.
