# Splitting one component into several

The shape this is for: a `MonoBehaviour` that grew until it holds movement, health, inventory and
audio, sits on forty prefabs, and has half the project wired into it through the inspector.

## What happens if you just move the fields

Nothing migrates by itself.

- **The values are dropped.** Move `dashSpeed` from `Movement` to a new `Dash` component and
  `Movement` no longer declares it, so on the next write it is gone from every prefab and scene
  instance. `[FormerlySerializedAs]` does not help — it maps a field name *inside one type*, never
  across two.
- **The new component is on nothing.** `Dash` is a type that exists and is attached to no object.
  Everything that used to dash stops dashing, silently, because a missing component is not an
  error.
- **References to the old component still resolve.** Anything serialized as a `Movement` field
  keeps pointing at the same component — the GUID and the class name did not change. That is the
  one thing you get for free.
- **References that should now point at `Dash` do not exist yet**, and every `UnityEvent` wired
  to a method that moved is now pointing at a method its target no longer has. The persistent
  call stores the method name as a string, so nothing reports it: the button just does nothing.

## The safe order

Five steps. Steps 1, 3 and 5 are commits; 2 and 4 are checks.

**1. Add the new component; change nothing else.** `Dash` declares the fields it is taking,
**with the same names they had on `Movement`**, and `Movement` keeps declaring them too. Nothing
is lost because nothing was removed. Put `[RequireComponent(typeof(Movement))]` on `Dash` if it
genuinely depends on it, so nobody ends up with half the pair.

Do not rename the fields in this step. A split and a rename in one move means two silent failure
modes with one diff to debug them from. Rename afterwards, per
[serialized-values.md](serialized-values.md).

**2. Write and run the migration pass.** A one-off editor script that puts `Dash` on every object
carrying `Movement` and copies the values across. Run it through the editor CLI per
`unity-scene-habits`.

```csharp
foreach (var guid in AssetDatabase.FindAssets("t:Prefab"))
{
    var path = AssetDatabase.GUIDToAssetPath(guid);
    using var scope = new PrefabUtility.EditPrefabContentsScope(path);

    foreach (var old in scope.prefabContentsRoot.GetComponentsInChildren<Movement>(true))
    {
        if (old.TryGetComponent<Dash>(out _)) continue;        // already migrated

        var moved = old.gameObject.AddComponent<Dash>();
        var src = new SerializedObject(old);
        var dst = new SerializedObject(moved);

        foreach (var field in new[] { "dashSpeed", "dashCooldown", "dashCurve" })
        {
            var p = src.FindProperty(field);
            if (p != null) dst.CopyFromSerializedProperty(p);
        }
        dst.ApplyModifiedPropertiesWithoutUndo();
    }
}
AssetDatabase.SaveAssets();
```

Four things make this survivable:

- **`EditPrefabContentsScope` edits the prefab asset**, not an instance in a scene. No scene
  diff, no override to apply. It is present on 2022 LTS and Unity 6 alike, with the same
  `prefabContentsRoot` field.
- **`CopyFromSerializedProperty` copies by property path**, so it handles object references,
  arrays, nested serializable classes and curves without you enumerating types. It needs the same
  field name on both sides, which is why step 1 forbids renaming.
- **The `TryGetComponent` guard makes it idempotent.** You will run this more than once. A pass
  that doubles components on the second run is worse than one that fails.
- **`GetComponentsInChildren<T>(true)`** — the `true` includes inactive objects. Without it the
  disabled half of every prefab is skipped, and nobody notices until that object is enabled.

Scene instances need the same treatment where the object is not a prefab instance. If it *is* a
prefab instance, the prefab edit above already reaches it. This is the point at which converting
loose scene objects into prefabs first — `unity-scene-habits`, its own commit — pays for itself.

**3. Commit the migration pass and its result together.** Still no behaviour change: both
components hold the same values, and `Movement` still does the work.

**4. Verify before removing anything.** Load several prefabs that used the fields and read the
values off `Dash`. Count objects: every object with `Movement` should now have `Dash`. Run the
broken-reference scan — `unity-agent-worker`, `references/verification.md`. Do not proceed on a
partial result.

**5. Remove the moved fields from `Movement`, and move the code with them.** This is the first
commit that can lose data, and it is safe only because step 4 proved the data is already in the
other component. Re-serialize the affected assets so the dead fields leave the files, per
[serialized-values.md](serialized-values.md).

## The wiring you have to fix by hand

The migration pass moves data. It does not move intent.

- **Serialized references that should now point at `Dash`.** Anything holding a `Movement` to
  call a dash method on it needs its field retyped and re-pointed. The compiler catches the
  retype; the re-pointing is inspector work on every prefab.
- **`UnityEvent` targets whose method moved.** Grep for the method name across `.prefab` and
  `.unity` files before you move it — the name appears literally in `m_MethodName`. Every hit is
  a place someone has to re-pick the target by hand, and the only way to prove it worked is to
  press the button.
- **Anything that found the component by type at runtime.** A `GetComponent<Movement>()` that
  wanted the dash part now wants `Dash`. The compiler catches it only if the member moved too.

Put these in the manual checklist, not in the commit message. They are rung 4 in
`unity-agent-worker`'s verification ladder: nothing automated proves them.

## When not to split

If the god object is stable, nobody is editing it, and the split exists to satisfy a line count,
leave it. A forty-prefab migration to make one file shorter is a bad trade, and the version where
you started and stopped halfway is the worst outcome available.

Split when you are about to do real work inside it, or when two people keep colliding in the same
file. Then split only the part that work needs, and leave the rest.
