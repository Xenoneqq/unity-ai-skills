# Keeping serialized values through a rename

Unity stores a serialized field under its **name**, inside the type that declares it. Nothing
else identifies it — not a declaration order, not an id. Rename the field and the stored value no
longer matches anything, so it is dropped on the next write. No error, no warning, and the
inspector shows the field's initializer, which looks exactly like a value somebody set.

## `[FormerlySerializedAs]`, and why it is not the whole job

```csharp
using UnityEngine.Serialization;

[FormerlySerializedAs("hp")]
[FormerlySerializedAs("hitPoints")]
[SerializeField] private int health = 100;
```

Verified identical on 2022 LTS and Unity 6:

- **Fields only.** It cannot rename a type, a property or a method.
- **Multiple allowed.** A field renamed more than once carries every old name, newest first is
  irrelevant — Unity takes whichever it finds in the data.
- **Editor only. It does nothing at runtime.** Unity's own serialization table lists
  `FormerlySerializedAs` as supported in the Editor and *not supported* at runtime, on both
  versions.

That last point is the one that decides the procedure. The attribute does not migrate anything;
it lets the editor *read* old data once. And Unity deliberately does not write upgraded data back
to disk just because it read it — an asset is only rewritten when something dirties it. So after
adding the attribute, the stored data is still the old name, on disk, in everyone's checkout.

## The three commits

**1. Add the attribute with the rename.** Nothing else in the commit. At this point the project
works, old assets load, and nobody has to do anything.

**2. Re-serialize the assets, alone.** This is what actually writes the new field name to disk:

```csharp
AssetDatabase.ForceReserializeAssets(paths);   // or the no-argument overload for the whole project
```

`ForceReserializeAssets` loads, upgrades and writes back the assets you name, which is exactly
the "flush outstanding data changes" the rename needs. Give it its own commit: it rewrites whole
asset files, so the diff is large and mechanical, and mixed into a code commit it hides
everything else. Scope it to the paths that actually use the type where you can — the
no-argument overload rewrites the entire project.

Run it in the editor, per `unity-scene-habits`. If no editor or licence is available, stop here
and say so; the migration is not finishable without one.

**3. Remove the attribute, later.** Not in the same session. It has to stay until every branch,
every colleague's local assets and every build have been through step 2 — at least one release.
Removing it early re-opens the same silent data loss for anyone who had not pulled.

## Adding a namespace

**It does not break the scene and prefab references to a `MonoBehaviour` or `ScriptableObject`.**
That link is `m_Script: {fileID: 11500000, guid: …, type: 3}` — the script *file's* GUID — and the
`.cs.meta` records only that GUID and the importer settings. No class name, no namespace. Unity
resolves the class inside the file by matching the class name to the file name; the namespace
never participates.

What a namespace change does break is anything storing a type **by name**:

| Also stores the type by name | What happens | Rescue |
|---|---|---|
| `[SerializeReference]` fields | The reference becomes a missing type; its data is retained but unusable | `[MovedFrom]` |
| `UnityEvent` with an argument typed to the moved class | The argument type fails to resolve and falls back to `UnityEngine.Object` | Re-pick the argument in the inspector |
| `Type.GetType("Namespace.Name")` and friends | Returns null | Fix the string |
| `AddComponent("Name")`, the string overload | Fails | Use the generic overload |
| Assembly definition references, if the type also moved assemblies | Compile error, which is the good case | Fix the `.asmdef` |

Moving a type into a different assembly — the common side effect of adding `.asmdef`s — breaks
the same list, for the same reason.

## `[MovedFrom]` for `[SerializeReference]` data

A `[SerializeReference]` field does not store a value; it stores an entry recording the
reference's id, its **fully qualified class name** and its fields. Unity's own editor type for a
reference it cannot resolve carries exactly `assemblyName`, `namespaceName` and `className`, which
is the list of things that must not change.

```csharp
using UnityEngine.Scripting.APIUpdating;

[MovedFrom("Game.Old.Effects")]           // the type's previous namespace
[System.Serializable]
public class BurnEffect : IEffect { }
```

Verified on both editors: `UnityEngine.Scripting.APIUpdating.MovedFromAttribute`, applicable to
class, struct, enum, interface and delegate, with two constructors —
`MovedFrom(string sourceNamespace)`, and
`MovedFrom(bool autoUpdateAPI, string sourceNamespace = null, string sourceAssembly = null,
string sourceClassName = null)` for a rename or an assembly move.

Two things worth knowing before you reach for it:

- **It is public but absent from the Scripting API reference** on Unity 6. It is a real, shipped
  attribute, not an internal — the runtime helper that reads it is present in the player build as
  well as the editor, so it is consulted when types are resolved and not only by the editor's API
  updater. It is nonetheless less documented than the rest of this file, so verify it behaves as
  expected on the project's own editor before relying on it across a large migration.
- **`autoUpdateAPI: true`** additionally permits Unity's API updater to rewrite *source* that
  referenced the old name. That is the same machinery `unity-scene-habits` warns about with
  `-accept-apiupdate`: useful for a package, usually not what you want in the middle of a
  project-internal migration, where a thousand-line source rewrite buries the change.

Leave `[MovedFrom]` in for the same reason and the same length of time as
`[FormerlySerializedAs]`, and re-serialize the affected assets the same way.

## What nothing rescues

- **A value moving between two types.** `[FormerlySerializedAs]` maps a name inside one type. It
  cannot carry a field from component `A` to component `B` — see
  [splitting-types.md](splitting-types.md).
- **A field whose type changed.** `int` to `float`, a class to a struct, a single value to a
  list. Unity reads what it can and defaults the rest. If the old value matters, keep the old
  field, add the new one, convert in `ISerializationCallbackReceiver.OnAfterDeserialize`,
  re-serialize, and remove the old field in a later commit — the same three-step shape as a
  rename.
- **A renamed method behind a `UnityEvent`.** The persistent call stores the method name as a
  plain string, so nothing checks it at compile time and nothing reports it at runtime; the
  button simply does nothing. Grep for the method name before renaming it, and re-check the
  inspector afterwards.
