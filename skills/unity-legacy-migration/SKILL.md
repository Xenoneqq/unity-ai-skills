---
name: unity-legacy-migration
description: >
  Move old Unity code and assets onto a project's current conventions deliberately, without
  breaking a reference: decide whether the migration is worth doing at all, rename and move
  through `AssetDatabase` so GUIDs survive, carry serialized values across a field rename, add a
  namespace without losing anything, split a god-object component safely, and land each step as
  its own commit with no behaviour change mixed in. Use when: "modernise this old script", "bring
  this up to our conventions", "rename this class everywhere", "put these scripts in a
  namespace", "split this god object", "this component predates our layout", "migrate the legacy
  folder", "/unity-legacy-migration".
---

# Unity legacy migration

**Most old code should be left alone.** Migration competes with shipping and pays nothing back on
its own — the game is not faster or less buggy because a class moved. "This is fine as it is" is
a valid answer and usually the right one.

**The project decides what "current" means.** Migrate toward the conventions this repo already
has — its `STRUCTURE.md`, its contributor notes, the shape of its newest code — not toward the
taste in this file or any other skill. Where the project has no opinion, do not invent one
mid-migration: ask, or leave the old shape alone.

This is the deliberate counterpart to the `unity-coding-habits` rule against restyling code you
are passing through. That rule holds; this is what you do instead.

| Reference | Read it when |
|---|---|
| [references/rename-and-move.md](references/rename-and-move.md) | Renaming or moving any file under `Assets/`, or a whole folder. |
| [references/serialized-values.md](references/serialized-values.md) | Renaming a serialized field, adding a namespace, or moving a type between assemblies. |
| [references/splitting-types.md](references/splitting-types.md) | Breaking one large `MonoBehaviour` into several components. |

## 1. Decide whether to migrate at all

Migrate when one of these holds: you are about to do real work in that code anyway and its shape
makes that work harder; it is actively breaking, like a deprecated API the project's next editor
drops or a field name that now means the wrong thing; it blocks something concrete, like an
assembly split or a folder move the layout needs; or a person asked for it, knowing the cost.

Not because it is old, inconsistent, or not how you would write it — note it and move on. The
cost is not the edit: it is every reference that can break silently, every serialized value that
can vanish without an error, reviewers who now have to tell a move from a change, and everyone
else's in-flight branch.

## 2. Know what binds a scene object to your script

Everything below follows from this. All five links break **silently** — no compile error, no
exception, an empty inspector slot at best.

| Link | Keys on | Breaks when |
|---|---|---|
| Component → script | the GUID in the script's `.cs.meta` | the `.meta` is lost, or the asset is reimported fresh |
| Script → class | file name equal to class name | one is renamed and the other is not |
| Serialized field → value | the field's name, within its type | the field is renamed |
| `[SerializeReference]` → type | class name **plus** namespace **plus** assembly | the type is renamed, renamespaced or moved between assemblies |
| `UnityEvent` → method | the target object plus the method name as a string | the method is renamed or moved to another component |

A component points at its script as `m_Script: {fileID: 11500000, guid: 9e1fc5a1…, type: 3}`, and
a `.cs.meta` holds that GUID and the importer settings — **no class name, no namespace**. That is
why the namespace is invisible to this link and the file name is not.

## 3. One thing at a time, each in its own commit

- **A pure move or rename lands first, alone.** No behaviour change in the same commit; a
  reviewer must be able to read "this only moved" and stop there.
- **One kind of change per commit** — rename, or namespace, or split. Mix two and neither can be
  reverted alone, and here reverting one step is the recovery plan.
- **Order matters**, because each step is cheaper once the one before it has landed: move and
  rename files → add namespaces → rename serialized fields and re-serialize → split or merge
  types → only then, any behaviour change, as a separate task reviewed on its own merits.
- **Never migrate a file somebody else is editing.** Scan the other branches the way
  `unity-scene-habits` says to for contested scenes, and say what you found.

## 4. Renaming and moving assets

**Never `mv` or `git mv` anything under `Assets/`.** It separates the asset from its `.meta`, and
the GUID every reference points at dies with it.

Use `AssetDatabase.RenameAsset` or `AssetDatabase.MoveAsset`, driven through the editor CLI per
`unity-scene-habits`. Both move the `.meta` with the asset and preserve the GUID, and both
**return an error string rather than throwing** — an ignored return value is the classic way to
believe a move happened when it did not.

Renaming a script is two edits that must land as one: the class name in the source, and the file
name through `RenameAsset`. Do either alone and the script resolves to no class — every component
using it reads *The referenced script on this Behaviour is missing!* while its serialized data
sits unreachable. The procedure, the folder case and batching are in
[references/rename-and-move.md](references/rename-and-move.md).

## 5. Carrying serialized values across a field rename

Serialization keys on the field name: rename `hp` to `health` and every prefab and scene instance
loses what was in `hp`, silently. Carry the old name.

```csharp
[UnityEngine.Serialization.FormerlySerializedAs("hp")]
[SerializeField] private int health = 100;
```

Two properties of this attribute decide the procedure, both verified on 2022 LTS and Unity 6:

- **Fields only, multiples allowed** — a field renamed twice can carry both old names.
- **Editor only; it does nothing at runtime.** So it migrates nothing by itself. It lets the
  *editor* read the old data once, and Unity does not write upgraded data back to disk just
  because it read it.

That makes the rename a three-commit sequence — add the attribute, force the assets to
re-serialize, remove the attribute a release later — set out in
[references/serialized-values.md](references/serialized-values.md).

## 6. Namespaces and assemblies

**Adding a namespace to an existing `MonoBehaviour` or `ScriptableObject` does not break the
scene and prefab references to it.** That link is the script file's GUID, and the `.cs.meta`
records no type name at all. Do it freely. You still owe it two things: the class name must still
match the file name, and every file that used the type now needs a `using`.

What a namespace change does break is anything storing a type **by name** —
`[SerializeReference]` fields, `Type.GetType("...")`, the string overload of `AddComponent`, and
UnityEvent arguments typed to the moved class. Moving a type into a different assembly breaks the
same list. `[MovedFrom]` is the rescue for the serialized ones; the exact form and the full list
are in [references/serialized-values.md](references/serialized-values.md).

## 7. Splitting a large type

Nothing migrates by itself. Move a field from component `A` to a new component `B` and the stored
value is dropped from `A` on the next write, while `B` is a type that is on no object yet, and
`[FormerlySerializedAs]` maps a name inside one type, never across two. So a split is not one
edit. Add `B` while `A` keeps its fields, run a one-off editor pass that
puts `B` on every object carrying `A` and copies the values over, verify, and only then remove
the moved fields from `A`. The procedure, the wiring that has to be re-pointed by hand and the
UnityEvent trap are in [references/splitting-types.md](references/splitting-types.md).

## 8. Verify after every step, not at the end

A migration's failure mode is silence, so the checking is the work.

- **Run the broken-reference scan after every commit**, not once at the end — it is in
  `unity-agent-worker`, `references/verification.md`. Run it on the base branch first so only new
  unresolved GUIDs count as yours.
- **Every asset paired with its `.meta`**, every `.meta` with its asset. `unity-scene-habits` has
  the one-liner. An unpaired file is a blocker, not a nitpick.
- **Spot-check real values.** Open a prefab that used the renamed field and confirm the number is
  still there. Compiling proves nothing about serialized data.
- **The scene diff is intended.** A migration meant to touch only scripts that shows a `.unity`
  diff did something you did not ask for.
- **Say which rung you reached**, per `unity-agent-worker`. "Compiles, no new broken references,
  values confirmed on three prefabs" is honest. "Migrated" is not.

Then read your own commit through `unity-review-change`, which triages exactly these failures
from the other side, before handing it over.

## 9. Stopping, and running a backlog of these

Stop at the boundary of what was agreed, even when the next file is obviously the same problem —
a migration that grows while it runs is the thing reviewers cannot review. Stop outright and
report when the old code turns out to have behaviour nobody knew about, when the only way forward
is an editor upgrade, when no editor or licence is available to re-serialize the assets, or when
the migration is now larger than the work it was meant to make easier.

**A half-done migration is worse than none** — the project then has two conventions and no way to
tell which is current. If you cannot finish a step, revert that step rather than leave it partial.

A list of these runs through `unity-manage-work` like any other backlog, stating per item the
single change it makes, what it must land after, and whether it touches assets or only C#. They
suit it unusually well: each is small, each is independently revertable, and the ordering in step
3 maps straight onto that skill's conflict map. Pure-C# migrations go anywhere; anything renaming
or moving an asset is an asset conflict and goes adjacent to the tasks sharing those files.
