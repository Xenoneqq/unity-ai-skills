# What Unity actually serializes

Unity's serializer is not C# reflection and not `System.Text.Json`. It has its own list of what
it will store in a scene, prefab or asset, and anything outside that list silently comes back as
the type's default. Most "the inspector forgot my value" bugs are this list.

## The rule

A field is serialized when **all** of these hold:

- it is `public`, or `private`/`protected` with `[SerializeField]`
- it is not `static`, `const`, or `readonly`
- its type is one Unity can serialize

Serializable types: the primitives, `string`, `enum`, Unity's own structs (`Vector2/3/4`,
`Quaternion`, `Color`, `Rect`, `Bounds`, `LayerMask`, `AnimationCurve`, …), anything deriving
from `UnityEngine.Object` (stored as a reference, not a copy), a plain class or struct marked
`[System.Serializable]`, and a single-level `List<T>` or `T[]` of any of those.

Not serialized, in the editors you are likely to meet:

| Not serialized | What to do instead |
|---|---|
| Properties | Back with a field, or `[field: SerializeField]` on an auto-property |
| `static`, `const`, `readonly` fields | If it must be editable, it is not any of those |
| `Dictionary<,>` | Two lists, or a `List<Entry>` with `[System.Serializable] class Entry` |
| Nested generics — `List<List<T>>`, `T[][]` | Wrap the inner one in a `[System.Serializable]` class |
| Multidimensional arrays — `T[,]` | Flat array plus a width, or jagged via a wrapper class |
| `interface`-typed fields | `[SerializeReference]`, or serialize the concrete type |
| Nullables — `int?` | A value plus a `bool`, or a sentinel |
| Abstract/polymorphic class fields | `[SerializeReference]` (stores by reference, allows null and subclasses) |

`[SerializeReference]` exists in current editors and solves the interface and polymorphism cases,
at the cost of a heavier serialized form. Reach for it deliberately, not by default.

## Initializers lose to stored data

```csharp
[SerializeField] private int lives = 3;
```

`3` is what a *new* component gets. On an object that was already saved, Unity runs the
initializer and then overwrites the field with the stored value. So editing the initializer
changes nothing for existing prefabs and scene instances — you have to change the asset.

The corollary: a serialized field's value does not come from your constructor either. Do not put
setup in a `MonoBehaviour` constructor; use `Awake`, `OnEnable` or `Reset`.

## Renaming a serialized field drops its value

Serialization keys on the field's name. Rename `hp` to `health` and every prefab and scene
instance loses whatever was in `hp`, silently, with no error. Carry the old name:

```csharp
using UnityEngine.Serialization;

[FormerlySerializedAs("hp")]
[SerializeField] private int health = 100;
```

Leave the attribute in for at least one release, so branches and colleagues' local assets
migrate too. This is also the main reason not to tidy field names in code you are only passing
through.

## Inspector attributes worth the keystrokes

Each of these removes a class of mistake rather than decorating:

```csharp
[Header("Movement")]                 // groups the block that follows
[Tooltip("Metres per second.")]      // says what the number means
[Range(0f, 20f)] public float speed; // makes an invalid value unreachable
[Min(0f)] public float radius;       // same, one-sided
[HideInInspector] public int runtimeId;  // serialized but not designer-editable
```

`[HideInInspector]` still serializes — it hides, it does not exclude. To exclude a public field
from serialization entirely, use `[System.NonSerialized]`.

## ScriptableObject config

A `ScriptableObject` is a serialized asset with no GameObject. It is where tunable data belongs:
one asset, edited by whoever owns the numbers, referenced by every instance that needs it, and a
small readable diff when it changes.

```csharp
[CreateAssetMenu(menuName = "Config/Weapon")]
public class WeaponConfig : ScriptableObject
{
    [SerializeField] private float damage = 10f;
    [SerializeField] private float fireRate = 3f;

    public float Damage => damage;
    public float FireRate => fireRate;
}
```

Two things to hold on to:

- **It is shared, not copied.** Every component holding the reference sees the same object.
  Writing to a `ScriptableObject` field at runtime mutates it for everyone — and in the editor
  the change persists after play mode ends, which looks like a save bug. Keep them read-only at
  runtime; put mutable per-instance state on the component.
- **It is an asset, so it has a `.meta` and a GUID.** Create, move and delete it through the
  editor — `unity-scene-habits` covers why and how.

For data that must survive a domain reload cleanly, or be rebuilt from a serialized form,
`ISerializationCallbackReceiver` gives you `OnBeforeSerialize`/`OnAfterDeserialize`. It is the
standard answer for "I need a dictionary at runtime and a list on disk".
