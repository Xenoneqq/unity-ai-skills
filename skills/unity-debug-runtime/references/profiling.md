# Measuring, and not fooling yourself

## Telling the three slow-bugs apart

Before opening anything, watch the frame time for ten seconds and answer one question: **is every
frame bad, or are most frames fine?**

| Pattern | What it is | Where to look |
|---|---|---|
| Every frame equally over budget | Too much work per frame, or GPU-bound | CPU Usage module; if CPU is idle waiting, it is the GPU |
| Most frames fine, one in N terrible | A garbage collection, or work batched on a timer | GC allocation per frame; the spike's own call stack |
| Fine, then one enormous frame, then fine | Loading, `Instantiate`, shader compilation, an asset bundle | The hitch's frame in the timeline |
| Fine at first, worse over time | A leak — growing collection, unreleased handles, objects never destroyed | Memory over the session, not one frame |

These want different fixes, and the third one is often mistaken for the first because the average
frame rate reflects it. **Average frame rate hides all three.** Use frame time, and look at the
worst frames rather than the mean.

`QualitySettings.vSyncCount` and `Application.targetFrameRate` cap frame rate on purpose. A game
pinned at exactly 60 is not necessarily fast, and one that "drops to 30" may be vsync halving
because it missed one deadline. Establish what the caps are before reading anything into the
number.

## The windows

| Window | Menu | For |
|---|---|---|
| Profiler | `Window > Analysis > Profiler` (Ctrl/Cmd+7) | Frame timings, CPU/GPU, memory, GC |
| Profiler (Standalone Process) | `Window > Analysis > Profiler (Standalone Process)` | The same, out of process, so the profiler UI is not part of what you measure |
| Frame Debugger | `Window > Analysis > Frame Debugger` | Draw calls, one at a time — a rendering-cost bug, not a script one |

Both editors checked (2022 LTS and Unity 6) have all three. The module list inside the Profiler
varies by version and by which packages are installed, so read what the window offers rather
than expecting a fixed set.

The standalone process is worth the habit when profiling the editor: the profiler's own UI is
otherwise on the same main thread as the thing you are measuring.

## Three caveats, all of them Unity's own position

**Deep Profiling distorts the measurement.** It instruments every managed call rather than only
explicit markers. Unity's documentation is blunt about it — deep profiling "incurs a very large
overhead and uses a lot of memory", the game "will run significantly slower", and for complex
code it "might not be possible at all". Treat a deep profile as a way to find the *region*, never
as a source of timings you would quote. Then confirm with explicit markers:

```csharp
using UnityEngine.Profiling;

Profiler.BeginSample("Pathfinding.Rebuild");
RebuildGraph();
Profiler.EndSample();
```

Explicit markers cost far less than deep profiling and measure the thing you actually asked
about.

**Play mode is not the game.** The editor's UI, inspectors, scene view rendering and asset
management run in the same process and on the same main thread, so they are in every number.
Unity's own wording: profiling in Play mode "doesn't give you an accurate reflection of what the
performance of your application looks like on a real device." Play mode is for *comparing* —
before and after your change, on the same machine, same scene — not for absolute numbers.

**A release build cannot be profiled.** The profiler counters are simply absent from it. Checked
directly: the development player binary contains `GC Allocated In Frame`, `GC.Alloc`,
`System Used Memory` and `Total Reserved Memory`; the release player binary contains none of
them. So there are only two honest places to get a number — a development build on the target
platform, and Play mode used as a relative comparison.

## Making a player profilable

With **Development Build** on, the build settings expose:

- **Autoconnect Profiler** — Unity "bakes its IP address into the built player during the build
  process", so the player connects back on start. Right for a device on the same network; useless
  for a machine that moved, where you connect manually instead.
- **Deep Profiling Support** — deep profiling from the moment the player starts. Carries the
  overhead above into the build, so switch it on for one investigation, not by default.

Player command-line arguments, from Unity's profiler reference:

| Argument | Effect |
|---|---|
| `-profiler-enable` | Profile the startup of a player or the editor |
| `-profiler-log-file <path>` | Stream profile data to a `.raw` file from startup |
| `-profiler-capture-frame-count <n>` | How many frames to capture when streaming; players only |
| `-profiler-maxusedmemory <bytes>` | Cap the profiler's own memory |
| `-deepprofiling` | Deep profiling in a player; requires an assembly reload |

Streaming to a `.raw` file is the only way to profile the first few seconds of a build, which is
where startup hitches and load-order bugs live. Nothing you attach afterwards can see them.

## Garbage collection

A GC spike is per-frame allocation catching up with you. Two questions, in order:

**How much is allocated per frame?** The Profiler's GC Alloc column answers it for a frame you
are looking at. To watch it continuously, in a development build, read the counter:

```csharp
using Unity.Profiling;

var gcAlloc = ProfilerRecorder.StartNew(ProfilerCategory.Memory, "GC Allocated In Frame");
// gcAlloc.LastValue is bytes allocated in the last frame
```

The counter name is exact; it exists in the editor and in the development player, and not in a
release player. Steady-state gameplay should allocate nothing per frame. Anything above zero,
repeated sixty times a second, is a future spike with a date on it.

**Where is it coming from?** The usual sources are string work, boxing, `foreach` over some
non-struct enumerators, LINQ, array-returning engine calls, and closures captured per frame. The
allocation-free alternatives are catalogued in
[`unity-coding-habits`](../../unity-coding-habits/references/per-frame.md); this file is about
proving which one you have, not about fixing it.

A leak is a different shape and the Profiler's memory view is not built to find it. That needs
memory snapshots, which live in a separate package. **Installing a package changes the project's
manifest, so ask before adding one** — and check whether the project already has it first.

## Reporting a performance finding

Say all four or the number means nothing: **what** you measured, **where** (editor Play mode,
development build, which device), **against what** (the before number, same scene, same machine),
and **how** (deep profile, explicit markers, counter). A frame time with no baseline and no
platform is not evidence.
