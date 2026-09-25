---
name: unity-coding-habits
description: >
  Good Unity C# habits that hold in any project: serialize private fields instead of exposing
  public ones, keep lookups out of per-frame code, treat destroyed `UnityEngine.Object`s as the
  fake null they are, pick one way to find things instead of mixing singletons and scene
  searches, keep types small and namespaced, and never restyle code you are only passing
  through. Use when writing or changing a `MonoBehaviour`, `ScriptableObject` or any C# under
  `Assets/`, including tests; "is this MonoBehaviour right", "clean up this component", "how
  should I write this component", "how do I test this", "write a PlayMode test",
  "/unity-coding-habits". Reviewing a change is `unity-review-change`; diagnosing a
  game that already runs badly is `unity-debug-runtime`.
---

# Unity coding habits

Clean, readable code is the point. Every rule below has a reason — correctness, performance,
readability, or compile time. Where the reason does not apply, neither does the rule.

**The project outranks this file.** If the repo documents its conventions — `CLAUDE.md`,
`CONTRIBUTING.md`, contributor notes — or the surrounding code clearly and consistently
demonstrates one, follow that. These are the fallback for when nothing says otherwise.

**Do not restyle code you are passing through.** Smallest diff that solves the task. Renaming
fields, adding `[SerializeField]`, extracting helpers or converting coroutines in code you merely
touched turns a reviewable diff into an unreviewable one — and in Unity a field rename silently
drops every value already serialized in a scene or prefab. Converting old code is real work:
propose it, get it agreed, and do it deliberately — `unity-legacy-migration` is that job, and it
carries the procedures that keep references and stored values intact.

| Reference | Read it when |
|---|---|
| [references/serialization.md](references/serialization.md) | Adding or renaming a serialized field, writing a `ScriptableObject`, or the inspector shows the wrong value. |
| [references/per-frame.md](references/per-frame.md) | Writing `Update`/`FixedUpdate`, chasing frame cost or GC spikes, or writing a coroutine or `async` method. |
| [references/wiring.md](references/wiring.md) | Deciding how one object finds another, loading assets at runtime, or setting up namespaces and assembly definitions. |
| [references/testing.md](references/testing.md) | Writing a test for input- or chance-driven code, a PlayMode test, or a playthrough that proves a level can be finished. |

## 1. Expose to the inspector, not to the codebase

A serialized field is data the designer sets. A public field is API every other type may write.
Not the same need — and `public` gives you the second in order to get the first.

```csharp
[SerializeField] private float maxHealth = 100f;
public float MaxHealth => maxHealth;
```

Default to `[SerializeField] private`. Go `public` only when something outside the type really
must read or write it, and prefer a property so the setter stays yours. `[SerializeField]` works
on `private` and `protected` fields; `[field: SerializeField]` does the same for an
auto-property.

Unity's serializer is narrower than C#: no properties, `static`, `const`, `readonly`,
`Dictionary`, nested generics or interface-typed fields, and it overwrites your field
initializers with whatever the asset stored. Renaming a serialized field loses its value unless
you carry the old name — [references/serialization.md](references/serialization.md) has the full
list and the rescue attribute.

## 2. A destroyed Unity object is not null

`UnityEngine.Object` overloads `==` so that a destroyed object compares equal to `null` while
the managed reference still exists. The C# operators that skip `==` do not know that:

```csharp
target?.TakeDamage(10);        // runs on a destroyed object — MissingReferenceException
var t = target ?? fallback;    // picks the destroyed object
if (target != null) target.TakeDamage(10);   // correct
```

Never use `?.`, `??` or `??=` on anything deriving from `UnityEngine.Object` — components,
GameObjects, assets. Use `== null` / `!= null`, which route through the overload. `is null` and
`ReferenceEquals` bypass it too, so they answer a different question — "is the managed reference
null" rather than "is this usable". That is occasionally what you want; it is never what you want
when checking whether something still exists. It is also why a cached reference to
something destroyable needs re-checking, not just caching.

## 3. Look things up once, not every frame

Resolve references in `Awake` (your own components) or `Start` (other objects, once every
`Awake` has run), store them in fields, and use the fields afterwards. A per-frame method should
contain no `GetComponent`, no `Find*`, no `Resources.Load`, no `Camera.main`.

```csharp
private Rigidbody body;
private void Awake() => body = GetComponent<Rigidbody>();
```

`Awake` and `OnEnable` run as an object is created; `Start` runs before its first `Update`, after
every `Awake` in the scene. Across two objects the order is **not defined** — never write code in
`Awake` that assumes another object's `Awake` already ran. If two things genuinely must order,
have one call `Initialize()` on the other rather than reaching for script execution order.

Inside per-frame code, prefer the calls that do not allocate:

| Instead of | Use | Why |
|---|---|---|
| `GetComponent<T>()` then null-check | `TryGetComponent<T>(out var t)` | No managed allocation when the component is absent |
| `go.tag == "Player"` | `go.CompareTag("Player")` | `tag` allocates a string every read; no typo-silent mismatch |
| `GetComponents<T>()` | the `List<T>` overload, list reused | The array overload allocates per call |
| `Physics.RaycastAll` | `Physics.RaycastNonAlloc` with a reused buffer | Same |

Pick the loop by what it does: physics writes in `FixedUpdate`, input edges and general logic in
`Update`, anything reading a transform after everything else moved in `LateUpdate`. Scale by
`Time.deltaTime` in `Update`, `Time.fixedDeltaTime` in `FixedUpdate`, never cross them. And an
`Update` earns its keep by not existing — an empty one is still a call per object per frame.
[references/per-frame.md](references/per-frame.md) has the callback order, the allocation
sources, and pooling instead of `Instantiate`/`Destroy` churn.

## 4. Unsubscribe from everything you subscribe to

A delegate holds a strong reference to its target. Subscribe in `OnEnable`, unsubscribe in
`OnDisable`; subscribe in `Awake`, unsubscribe in `OnDestroy`. Always the matching pair, always
both written in the same edit.

```csharp
private void OnEnable()  => spawner.Spawned += HandleSpawned;
private void OnDisable() => spawner.Spawned -= HandleSpawned;
```

Miss the unsubscribe and the publisher keeps your destroyed component alive, then invokes it —
back to the fake-null trap in step 2. The same applies to `UnityEvent.AddListener` called from
code, and to any static event, which outlives scene loads entirely.

## 5. Pick one way for objects to find each other

Mixing mechanisms is the real cost: a project where some code uses a static `Instance`, some
calls `FindAnyObjectByType` and some drags references in the inspector has three lifetimes to
reason about and nowhere single to look when something is null. Decide once, per project, and
follow what is already there. In order of preference:

1. **A serialized reference**, set in the inspector or by whoever spawns the object. Explicit,
   visible, and fails loudly at edit time instead of silently at runtime.
2. **A registry, or a `ScriptableObject` participants register with.** Keeps the dependency
   one-directional and testable.
3. **A singleton**, for the small handful of genuinely global services. One per project's
   convention, never one per convenience.

Scene-wide searches (`FindAnyObjectByType`, `FindObjectsByType`, `GameObject.Find`) are the last
resort — they scan loaded objects, miss inactive ones by default, and in the `Find` case hang on
a string the compiler cannot check. Fine in editor tooling and one-off setup; not an
architecture, and never per frame. The older `FindObjectOfType`/`FindObjectsOfType` are
deprecated on Unity 6 — write what the project's editor accepts without a warning rather than
assuming a version.

## 6. Keep types small, named and namespaced

- **One responsibility per type, one type per file, file name equal to type name.** This is what
  the C# compiler, Unity's script-to-file expectation and every reviewer already assume.
- **PascalCase** for types, methods, properties, consts and events; **camelCase** for fields,
  parameters and locals. Do not invent a scheme.
- **A file past roughly 300 lines is a signal**, not a hard limit. A `MonoBehaviour` that long
  is usually three components sharing a file — the shape that makes merges hurt.
- **Every script gets a namespace**, matching its folder path under `Assets/`. Half a project
  with namespaces is worse than none: the namespaced types need a `using`, and the rest collide
  with every package you install.
- **Group scripts behind assembly definitions.** Without them every edit recompiles every
  script. [references/wiring.md](references/wiring.md) has the layout and the traps.
- **Say it in an attribute when you can.** `[RequireComponent(typeof(Rigidbody))]`,
  `[DisallowMultipleComponent]`, `[Range]` and `[Tooltip]` on anything a designer tunes.

## 7. Config belongs in assets, not in code

Numbers a designer tunes — damage, speed, prices, spawn tables — go in a `ScriptableObject`
asset, not in fields scattered across prefabs and not in a `const`. One asset, edited without
touching code, shared by every instance, diffable, reached by serialized reference.

Avoid `Resources.Load`: everything under a `Resources` folder is force-built into the player
whether used or not, is addressed by an unchecked string, and lengthens startup. Prefer a direct
reference, or Addressables on demand — and where the project already commits to `Resources`,
follow it rather than adding a second mechanism.

## 8. Before you call it done

- **It compiles, with no new warnings.** A new warning in your file is yours.
- **You changed only what the task needed.** Re-read your diff for drive-by renames, reordered
  members and reformatting, and take them back out.
- **Every subscribe has its unsubscribe, every cached reference its assignment.**
- **Nothing per-frame got heavier.** If you added to an `Update`, say so.
- **Scene and prefab work went through the editor**, not through hand-edited YAML — see
  `unity-scene-habits`. New files landed where `unity-file-structure-habits` says they go.
