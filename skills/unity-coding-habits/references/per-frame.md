# Lifecycle, per-frame cost, and waiting

Everything here is about the same budget: a frame. On a 60fps target you have about 16ms for
every object in the scene, and the garbage collector spends part of it for you if you let it.

## The order you can rely on

Per object, in order, once each:

| Callback | When | Use it for |
|---|---|---|
| `Awake` | Object created, before anything is enabled | Your own components: `GetComponent`, field setup |
| `OnEnable` | Every time the object becomes active | Subscribing to events |
| `Start` | Before the object's first `Update`, after every `Awake` in the scene | Reaching other objects |
| `Update` | Every frame | Input edges, general logic |
| `LateUpdate` | Every frame, after all `Update`s | Reading transforms that moved this frame |
| `OnDisable` | Every time the object becomes inactive | Unsubscribing |
| `OnDestroy` | Object destroyed | Releasing anything `Awake` acquired |

`FixedUpdate` runs on the physics clock, not the frame clock — zero, one or several times per
frame.

**Between two objects, nothing is guaranteed.** Object A's `Awake` may run before or after
object B's. What *is* guaranteed is that all `Awake` calls precede all `Start` calls, which is
the whole reason the `Awake` / `Start` split exists: resolve yourself in `Awake`, reach outward
in `Start`.

If two systems genuinely must initialise in order, have one call an explicit `Initialize()` on
the other. `[DefaultExecutionOrder]` and the Script Execution Order project setting exist, but
they are invisible from the code that depends on them — a reader of the class cannot tell. Use
them only for a project-wide bootstrapper, and say so in a comment where it matters.

`Awake` and `OnEnable` also run on a disabled-then-enabled object in different combinations:
`Awake` fires once ever, `OnEnable` fires every activation. A subscription in `Awake` that is
unsubscribed in `OnDisable` will therefore be gone after the first deactivation. Pair by
lifetime: `OnEnable`/`OnDisable`, or `Awake`/`OnDestroy`.

## Which loop

| Work | Loop | Why |
|---|---|---|
| `AddForce`, `MovePosition`, setting `velocity` | `FixedUpdate` | Physics steps on its own clock; writing from `Update` gives frame-rate-dependent motion |
| `Input.GetKeyDown`, `GetButtonDown` | `Update` | The edge is set per frame; `FixedUpdate` can run zero times in a frame and miss it, or twice and double it |
| Following or looking at something that moved | `LateUpdate` | Everything else has already moved |
| Anything on a timer | A coroutine, or an accumulator | Not a per-frame `if` that is false 99% of the time |

Multiply by `Time.deltaTime` in `Update` and `LateUpdate`, by `Time.fixedDeltaTime` in
`FixedUpdate`. Crossing them is a silent bug that only shows up at a different frame rate.

An empty or near-empty `Update` still costs a managed-to-native call per object per frame. If a
component only reacts to events, delete its `Update`. If a hundred objects need the same tick,
one manager iterating a list beats a hundred `Update` methods.

## Where the garbage comes from

Per-frame allocation is the usual cause of periodic stutter: the allocation itself is cheap, the
collection is not.

- **`foreach` over a non-generic or interface-typed collection** boxes its enumerator. `foreach`
  over `List<T>` by its concrete type does not.
- **String work.** Concatenation, `$"..."` interpolation, `ToString()` on a number — all allocate.
  A per-frame UI label costs a string every frame; update it only when the value changes.
- **LINQ.** `Where`, `Select`, `OrderBy` allocate delegates, closures and intermediate
  collections. Fine in setup code, not in a loop that runs every frame.
- **Array-returning APIs.** `GetComponents<T>()`, `Physics.RaycastAll`, `OverlapSphere`,
  `Mesh.vertices` — each returns a fresh array. Use the `List<T>` or `NonAlloc` overloads with a
  buffer you allocated once.
- **`new WaitForSeconds(...)` inside a coroutine loop.** Cache one instance in a field and yield
  the same object.
- **Lambdas that capture.** A closure over a local allocates each time the lambda is created.

`TryGetComponent<T>(out var c)` exists specifically to avoid the allocation `GetComponent<T>()`
makes in the editor when the component is absent. Prefer it wherever you would follow
`GetComponent` with a null check.

`CompareTag("Player")` beats `gameObject.tag == "Player"` on both counts: the `tag` property
allocates a managed string on every read, and `CompareTag` throws on a tag that does not exist in
the project instead of quietly never matching.

## Instantiate/Destroy churn

`Instantiate` and `Destroy` are not free — allocation, `Awake`/`OnEnable`, and eventually a
collection. Anything that appears and disappears repeatedly — bullets, impact effects, damage
numbers, list rows — should be pooled: created once, deactivated instead of destroyed,
reactivated and reset instead of instantiated.

`UnityEngine.Pool.ObjectPool<T>` ships with the engine in current editors and saves writing one.
Whatever you use, the rule that matters is that **the pool resets state on release, not on
get** — an object returned dirty will be handed out dirty by whichever code forgets.

Do not pool on principle. Pool what the profiler says churns.

## Coroutines and async

Both are legitimate. They fail in different ways, so pick per task rather than per project, and
follow what the project already does.

**Coroutines** are Unity-native and tied to the component that started them. `StartCoroutine`
on a `MonoBehaviour` stops automatically when that behaviour is disabled or its object is
destroyed, which is exactly the lifetime you usually want.

```csharp
private readonly WaitForSeconds tick = new WaitForSeconds(0.5f);

private IEnumerator Regenerate()
{
    while (health < maxHealth)
    {
        health += 1;
        yield return tick;
    }
}
```

Traps: a coroutine started on a *different* behaviour outlives yours; disabling the component
stops the coroutine without running any cleanup after the `yield`, so anything that must be
undone belongs in `OnDisable`; and they cannot return a value or propagate an exception to a
caller.

**`async`/`await`** gives you return values, real exception propagation, and composition. What it
does *not* give you is Unity's lifetime: a `Task` keeps running after the object is destroyed,
and continuing to touch that object then throws — or worse, keeps it alive. Every `async` method
that touches a Unity object needs a `CancellationToken`, and `MonoBehaviour.destroyCancellationToken`
is the one to pass on editors that have it (recent 2022 LTS onward — check yours).

Unity 6 adds `Awaitable`, an allocation-light awaitable with frame-aware helpers
(`Awaitable.NextFrameAsync()`, `EndOfFrameAsync()`, `WaitForSecondsAsync()`) and main-thread
resumption. It does not exist on 2022 LTS. If the project must run on both, coroutines or a
third-party async library are the portable choice.

Either way: nothing that awaits or yields may assume the object it started on still exists when
it resumes. Re-check with `!= null`, per the fake-null rule in the skill.
