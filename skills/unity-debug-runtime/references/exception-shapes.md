# The shapes a Unity runtime failure comes in

## Reading the trace

A managed stack trace reads top to bottom, innermost first. The top frame is where the exception
was **thrown**; the bug is where the bad value was **produced**, which is further down.

```
NullReferenceException: Object reference not set to an instance of an object
  at Game.Combat.DamageApplier.Apply (Game.Combat.Hit hit) [0x0001f] in <…>/DamageApplier.cs:42
  at Game.Combat.WeaponSwing.OnTriggerEnter (UnityEngine.Collider other) [0x0000c] in <…>/WeaponSwing.cs:88
  at UnityEngine.Component.SendMessage …
```

Read it as three bands:

- **Engine frames at the bottom** (`UnityEngine.…`, `SendMessage`, the player loop) say *how* your
  code was entered — a physics callback, an `Update`, a coroutine, a `UnityEvent`. That is often
  the real clue: an `OnTriggerEnter` frame means the object may be mid-destruction.
- **Your frames in the middle** are the suspects. Start at the lowest one you own, not the
  highest.
- **The top frame** is the crime scene, not the criminal.

Two things that silently change what you get:

- **`ScriptOnly` is the default**, so native frames are absent. A crash *inside* the engine
  therefore produces a trace that looks like your code's fault. Switch to `Full` before
  concluding anything about an engine-level failure.
- **Line numbers are not guaranteed in a build.** They depend on the scripting backend and on
  symbols being shipped. A build trace with no `:line` is normal and is a reason to reproduce in
  the editor, not a reason to distrust the trace.

Exceptions thrown off the main thread — a job, a `Task`, a network callback — reach
`Application.logMessageReceivedThreaded` but may not reach the console in a useful order. If a
trace looks truncated or arrives without context, suspect a background thread.

## The four nulls

### 1. A serialized reference nobody dragged in

The most common runtime failure in a Unity project, and the least like a programming bug.

```
UnassignedReferenceException: The variable targetMarker of AimAssist has not been assigned.
```

The message names the field and the type, which is the whole diagnosis. Causes, in order of how
often they are the answer:

- The prefab or scene object was created before the field existed, so the inspector slot is
  empty on that one instance while every other instance looks fine.
- A prefab **variant** or an instance carries an override that clears the slot the base prefab
  fills.
- The field was renamed, which drops whatever was serialized under the old name. See
  [`unity-coding-habits`](../../unity-coding-habits/references/serialization.md).

Confirm it by selecting the object and looking at that one field, not by reading code. A field
that is `None` in the inspector and non-null in your head is the bug.

### 2. A reference to something already destroyed

```
MissingReferenceException: The object of type 'GameObject' has been destroyed but you are still
trying to access it.
```

The reference was valid and the object is gone: destroyed this frame, unloaded with its scene, or
pooled and returned. Look for a cached reference taken in `Awake` that nothing re-checks, or an
event subscription that outlived its subscriber.

This is also where Unity's fake null bites. A destroyed `UnityEngine.Object` compares equal to
`null` through the overloaded `==`, but `?.`, `??` and `is null` bypass the overload and see a
live managed reference. `target?.Take(10)` on a destroyed object throws;
`if (target != null)` does not. The rule and the reasoning are in
[`unity-coding-habits`](../../unity-coding-habits/SKILL.md) — this is what it looks like when
it fires at runtime.

### 3. The script asset itself is gone

```
The referenced script on this Behaviour (Game Object 'HealthBar') is missing!
```

Unlike the two above, **this one appears in player builds too** — the message is in the player
binary. The component survives in the scene or prefab with its serialized data and no class to
put it in. Causes: a script deleted or moved without its `.meta`, a class renamed without the
file, an assembly definition change that moved the type, or a package removed.

Everything that object's script was doing simply does not happen, usually with no exception at
all — which is why it presents as "it does nothing" rather than as an error. Finding every
instance across the project is the broken-reference sweep in
[`unity-agent-worker`](../../unity-agent-worker/references/verification.md) rung 1; use that
rather than a new script here.

`MissingComponentException` is the adjacent case: the GameObject never had the component the
code asked for. `[RequireComponent]` prevents the whole class of it.

### 4. Actual logic

A lookup returned nothing, a collection was empty, a parse failed, an `async` result never
arrived. Only conclude this after the other three are ruled out, because the other three are more
common and each takes under a minute to check.

## Why a build says less than the editor

Verified by inspecting the shipped binaries of two editor versions: the message formats for
`UnassignedReferenceException` and `MissingReferenceException` are present in the **editor**
binary and absent from **both** the development and the release player. The same bug is a named,
self-explaining exception in the editor and a bare `NullReferenceException` in any build.

Practical consequence: a null in a build is worth ten minutes trying to reproduce in the editor
before it is worth any analysis, because the editor will usually name it for free.

Two further things a release build removes that a development build keeps:

- **Managed code stripping** deletes code the linker cannot see being used. Anything reached only
  by reflection or by name is a candidate, and it fails at runtime, only in the build, with a
  missing type or method. If a build-only failure smells like "the type isn't there", check the
  project's **Managed Stripping Level** and its `link.xml` before suspecting your own code.
- **Profiler counters and markers** do not exist at all — see [profiling.md](profiling.md).

## Failures with no exception at all

Not everything throws. When the symptom is "nothing happens", check in this order, because each
is cheaper than the last:

1. Is the GameObject active and the component enabled? A disabled component's `Update` never runs
   and says nothing about it.
2. Is the script missing (case 3 above)?
3. Did an exception earlier in the same callback skip the rest of the method? Unity logs it and
   continues — with `Collapse` on, one red line can represent thousands.
4. Is something else writing the value back — a second component, an animation curve, a network
   sync overwriting a local change?
