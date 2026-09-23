# Wiring, loading, and assemblies

How one object reaches another, how assets reach the game, and how the whole thing compiles.
These are the three decisions that get made once by accident and paid for forever.

## Four ways to find another object

Ordered by how well they fail.

**1. A serialized reference.** The dependency is visible in the inspector, the asset records it,
and a missing one is obvious before the game runs.

```csharp
[SerializeField] private Spawner spawner;
```

Cost: something must set it. Inside a prefab, drag it. Across prefabs, have the spawner pass
itself to what it spawns. Across scenes, you cannot — which is the honest signal that you need
one of the next two.

**2. A registry.** Participants register themselves; consumers ask the registry. A plain static
class works; a `ScriptableObject` asset works better, because the registry itself is then a
referenceable thing rather than a global.

```csharp
public class EnemyRegistry : ScriptableObject
{
    private readonly List<Enemy> active = new List<Enemy>();
    public IReadOnlyList<Enemy> Active => active;

    public void Register(Enemy e) => active.Add(e);
    public void Unregister(Enemy e) => active.Remove(e);
}
```

Register in `OnEnable`, unregister in `OnDisable` — the same pairing rule as events, and for the
same reason. A `ScriptableObject` holding runtime state persists across play-mode sessions in the
editor, so clear it on first registration or in `OnEnable`.

**3. A singleton**, for genuinely global services — audio, save, scene loading. One shape,
project-wide:

```csharp
public class AudioService : MonoBehaviour
{
    public static AudioService Instance { get; private set; }

    private void Awake()
    {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this;
    }

    private void OnDestroy()
    {
        if (Instance == this) Instance = null;
    }
}
```

The `OnDestroy` clear is the part usually missing, and its absence is what produces a stale
`Instance` pointing at a destroyed object after a scene load — a fake null that passes a
`!= null` written as `?.`. Note also that `Awake` order between objects is undefined, so nothing
may read `Instance` from its own `Awake`; `Start` is safe.

**4. A scene-wide search.** `FindAnyObjectByType<T>()`, `FindObjectsByType<T>(...)`,
`GameObject.Find("name")`. These walk loaded objects, skip inactive ones unless you ask for them,
and in the `GameObject.Find` case depend on a string the compiler never checks. Acceptable in
editor tooling, tests, and one-time setup. Not an architecture, and never inside per-frame code.

On Unity 6 the older `FindObjectOfType`/`FindObjectsOfType` are deprecated in favour of
`FindAnyObjectByType`/`FindObjectsByType`; the newer calls also exist on 2022 LTS. Recent Unity 6
releases are additionally phasing out the `FindObjectsSortMode` overloads. Write what the
project's editor accepts without a warning, and do not modernise existing call sites as a
drive-by.

**Mixing these is the actual problem.** Pick the one the project already uses for that kind of
dependency and use it. A codebase with two service-location mechanisms has twice the lifetimes to
reason about and no single place to look when something is null.

## Loading assets

Avoid `Resources.Load`. Everything under any folder named `Resources` is force-built into the
player whether or not a single line references it, is loaded by string path the compiler cannot
check, and inflates startup because the engine builds an index of all of it.

In order of preference:

1. A serialized reference to the asset. Unity then knows the dependency and builds only what is
   reachable.
2. Addressables, for anything loaded on demand, patched separately, or too large to hold at once.
3. `Resources`, only where the project already standardised on it — consistency beats a second
   mechanism.

If you do add an Addressables or similar dependency, that is a package decision. Ask first.

## Namespaces

Every script gets a namespace, matching its folder path under `Assets/`:

```
Assets/Scripts/Gameplay/Combat/Health.cs   →   namespace Game.Gameplay.Combat
```

A half-namespaced project is worse than an un-namespaced one — the types that have a namespace
cannot be used without a `using`, and the ones that do not will eventually collide with a type
in a package you install. If the project already has a root namespace, use it. If it has none at
all, adding namespaces to the whole project is its own task, not something to start inside an
unrelated change.

## Assembly definitions

Without an `.asmdef`, every script under `Assets/` compiles into one assembly, and every
one-character edit recompiles all of it. On a project of a few hundred scripts that is the
difference between a second and half a minute, paid on every save.

An `.asmdef` in a folder makes that folder (and its subfolders, until the next `.asmdef`) its own
assembly. A change then recompiles that assembly and whatever depends on it, and nothing else.

```json
{
  "name": "Game.Gameplay",
  "references": ["Game.Core"],
  "autoReferenced": true
}
```

Rules that keep them useful:

- **Split along real seams** — core, gameplay, UI, editor tooling, tests. Not one per folder;
  each assembly has its own compile overhead, and hundreds of tiny ones are slower than a few.
- **References form a directed acyclic graph.** Circular references do not compile, and the
  error appears at the assembly level, well away from the line that caused it. If two assemblies
  want to reference each other, one of them is in the wrong place — or the shared part belongs in
  a third.
- **Editor-only code goes in an editor assembly**, with the platform list restricted to `Editor`.
  Otherwise a `using UnityEditor` compiles fine in the editor and breaks the player build.
- **An `.asmdef` is an asset with a `.meta`.** Create it through the editor and commit both
  files — see `unity-scene-habits`.

Adding assembly definitions to a project that has none changes what compiles against what, and
will surface missing references across the codebase. Worth doing; not worth doing halfway, and
not inside another task.
