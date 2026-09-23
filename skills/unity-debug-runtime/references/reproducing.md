# Getting from "sometimes" to "every time"

A bug you cannot summon is a bug you cannot fix — you can only make a change and hope. Everything
here is about turning an anecdote into a procedure, before any code is read.

## Write the reproduction down first

Four lines, before anything else:

```
1. Open <scene>, press play.
2. <the actions, in order, with the values used>
3. Observed: <exactly what happens, quoting the log line if there is one>
4. Happens: 3 of 3 runs.
```

That last line is the point of the exercise. Until it says "n of n", every later statement about
the fix is a guess. If it says "1 of 5", the job right now is determinism, not diagnosis.

Keep the file next to the work and update it when you narrow the steps. A reproduction that
shrinks from twelve steps to three *is* progress, even on a day the bug is not fixed.

## Removing the sources of variation

In roughly the order that pays off:

**Randomness.** `UnityEngine.Random.InitState(seed)` at startup makes the sequence repeatable.
Where one system must not disturb another's sequence, save and restore around it:

```csharp
var saved = Random.state;
Random.InitState(seed);
// … the thing under test
Random.state = saved;
```

`System.Random` instances are seeded separately and are not covered by this — find them too.
Anything seeded from the clock, a GUID, or the current frame is a variation source wearing a
disguise.

**Frame timing.** A bug that moves with the frame rate is a timing bug, and it will not reproduce
until the cadence is fixed. `Time.captureDeltaTime` steps the game by a constant amount
regardless of real time. `Application.targetFrameRate` and `QualitySettings.vSyncCount` decide
whether the monitor is a variable in your experiment. Physics runs on `Time.fixedDeltaTime` and
is capped by `Time.maximumDeltaTime`, so a slow frame changes how many physics steps run — which
is exactly why "it only happens on the slow laptop" is a real category of bug.

**Physics determinism is not something you can assume.** Unity's physics is not guaranteed to
produce identical results across platforms, editor versions, or frame rates. A physics bug that
will not repeat may not be intermittent at all — it may be reacting to timing you have not
pinned yet. Pin the timestep and the frame cadence before concluding it is random.

**Input.** Hand-played input is never the same twice. Where the bug depends on a sequence, drive
it from code — call the same methods the input layer calls — rather than replaying a human.

**Scene state.** A scene that has been played once is not the scene that was loaded. Check
whether the bug needs a fresh enter-play, a reload, or a second run to appear; each answer points
somewhere different.

## Isolating

Two directions, and the cheap one first.

**Cut down.** Duplicate the scene, delete everything not on the path, and rerun. If the bug
survives, you have halved the suspects at no analytical cost. Repeat. Duplicate the scene rather
than editing it — the scene is a shared file and editing it for an experiment is a merge conflict
someone else pays for (see [`unity-scene-habits`](../../unity-scene-habits/SKILL.md)).

**Build up.** When cutting down makes the bug vanish immediately, go the other way: an empty
scene with only the suspect prefab in it. If it reproduces there, the reproduction just became
something you can hand to someone else.

Either way the target is the same: **the smallest thing that still fails.** That artefact is more
valuable than any theory about it, and it is what makes the fix verifiable afterwards.

## Editor, development build, release build

They are three different environments and a bug can live in exactly one of them. Know which you
are standing in.

| | Editor Play mode | Development build | Release build |
|---|---|---|---|
| Named `Unassigned`/`Missing` reference exceptions | yes | no | no |
| "Referenced script … is missing" | yes | yes | yes |
| Profiler counters and markers | yes | yes | **no** |
| Managed code stripping applied | no | per Managed Stripping Level | per Managed Stripping Level |
| Editor-only code (`#if UNITY_EDITOR`) compiled in | yes | no | no |
| Representative performance | no | on the target device | closest, but unmeasurable |

Three consequences worth internalising:

- **A build-only bug is usually stripping, editor-only code, or a platform difference** — in that
  order. Code inside `#if UNITY_EDITOR`, or anything in an `Editor` folder, does not exist in the
  build; if the game depended on it, it only ever worked for you.
- **A release build is not a debugging environment.** It cannot be profiled and it will not name
  its exceptions. Reproduce in a development build first, and only chase a release-only
  difference when you have shown there is one.
- **An editor-only bug is real too** and worth fixing — but say so, because "works in the build"
  is a different report from "fixed".

## When it still will not reproduce

Do not start changing code. Add evidence instead, and ship it to wherever the bug lives:

- **Log the state, not the event.** "Spawn failed" is a sentence you already know. Log the inputs
  that decided it — the count, the index, the flag, the object's name — so the next occurrence
  arrives with its own diagnosis attached.
- **Stamp the log.** `-timestamps` on the player, or include the frame count, so the sequence is
  recoverable afterwards. See [log-locations.md](log-locations.md).
- **Put a development build in the hands of whoever sees it**, and collect the player log rather
  than a description. One log beats five rounds of questions.
- **Say plainly that you could not reproduce it**, and what you did instead. An unreproduced bug
  closed on a plausible-looking change is a bug that comes back with your name on it.
