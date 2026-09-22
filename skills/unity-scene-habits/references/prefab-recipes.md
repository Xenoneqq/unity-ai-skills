# Prefab edits that leave the scene alone

Every snippet here works on either path: as the body of a `CliTask.Run` in batch mode
([batch-mode.md](batch-mode.md)), or inside a `[CliCommand]` method or an `eval_file` against a
running editor ([connected-editor.md](connected-editor.md)). None of them open a scene, so none
of them produce a scene diff.

## Edit a prefab asset in place

This is the default move. `EditPrefabContentsScope` loads the prefab asset, hands you its root,
then saves and unloads on exit.

```csharp
using (var scope = new PrefabUtility.EditPrefabContentsScope("Assets/Prefabs/Crate.prefab"))
{
    var root = scope.prefabContentsRoot;
    root.GetComponent<Rigidbody>().mass = 12f;
}
```

The older three-call form does the same thing and is what you need if the scope type is not
available in the project's editor version:

```csharp
var path = "Assets/Prefabs/Crate.prefab";
var root = PrefabUtility.LoadPrefabContents(path);
try
{
    root.GetComponent<Rigidbody>().mass = 12f;
    PrefabUtility.SaveAsPrefabAsset(root, path);
}
finally { PrefabUtility.UnloadPrefabContents(root); }
```

`UnloadPrefabContents` must run even on failure, hence the `finally`. Skipping it leaks the
loaded contents into the editor session.

## Change the same thing across many prefabs

Query by type, not by scanning folders — this finds prefabs wherever the project keeps them.

```csharp
foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { "Assets" }))
{
    var path = AssetDatabase.GUIDToAssetPath(guid);
    using var scope = new PrefabUtility.EditPrefabContentsScope(path);
    var target = scope.prefabContentsRoot.GetComponent<Health>();
    if (target == null) continue;   // scope still saves; harmless, but skip the work
    target.regenPerSecond = 0.5f;
}
AssetDatabase.SaveAssets();
```

Narrow the search folders when the project is large. A full `t:Prefab` sweep on a project with
hundreds of prefabs opens every one of them.

## Turn a loose scene object into a prefab

This one does touch the scene — it replaces the object with an instance. Keep it in its own
commit, and say so when reporting.

```csharp
var scene = EditorSceneManager.OpenScene("Assets/Scenes/Main.unity");
var go = GameObject.Find("Watchtower");
PrefabUtility.SaveAsPrefabAssetAndConnect(
    go, "Assets/Prefabs/Watchtower.prefab", InteractionMode.AutomatedAction);
EditorSceneManager.MarkSceneDirty(scene);
EditorSceneManager.SaveScene(scene);
```

`SaveAsPrefabAsset` (without `AndConnect`) writes the asset and leaves the scene object loose —
which defeats the point. Use `AndConnect` unless you deliberately want an unlinked copy.

Name the asset for the thing, not for the scene it came from, and put it where the project
already keeps that kind of prefab.

## Make a variant instead of a copy

When two things differ by a few values, a variant keeps them in sync for everything else.
Duplicating a prefab does not.

```csharp
var basePrefab = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Prefabs/Enemy.prefab");
var instance = (GameObject)PrefabUtility.InstantiatePrefab(basePrefab);
instance.GetComponent<Health>().max = 300;
PrefabUtility.SaveAsPrefabAsset(instance, "Assets/Prefabs/EnemyHeavy.prefab");
Object.DestroyImmediate(instance);
```

Instantiating without a scene open puts the instance in the active untitled scene, which is
never saved in batch mode — but destroy it anyway rather than relying on that.

## Nest prefabs rather than growing one

A house is a prefab. So is the map section holding twenty houses, and so is the map holding the
sections. Nesting is how "group anything groupable" stays true at every level: dropping a prefab
instance inside another prefab's contents and saving nests it, and each level stays separately
editable and separately mergeable.

## Overrides

An override is a difference between an instance and its prefab. A few are fine — placement,
one tuned value. A pile of them means the prefab is wrong, or the thing should be a variant.

```csharp
// what differs on this instance
foreach (var mod in PrefabUtility.GetPropertyModifications(instance))
    Debug.Log($"{mod.propertyPath} = {mod.value}");

// push them into the asset
PrefabUtility.ApplyPrefabInstance(instance, InteractionMode.AutomatedAction);
```

Applying an override writes the prefab asset and clears the override from the scene, so it
usually *shrinks* the scene diff. Reverting does the same. Both are good outcomes.

Never `UnpackPrefabInstance`. It severs the link, turns one instance into raw scene objects,
and every future edit to that thing becomes a scene edit.

## Move or rename without breaking every reference

The GUID that all references point at lives in the `.meta`, not in the asset. A plain `mv` or
`git mv` moves one and not the other, and every scene and prefab pointing at that asset ends up
holding a reference to nothing. Let the editor do it:

```csharp
// returns "" on success, an error string otherwise — it does not throw
var err = AssetDatabase.MoveAsset(
    "Assets/Prefabs/Crate.prefab",
    "Assets/Prefabs/Props/Crate.prefab");
if (!string.IsNullOrEmpty(err)) throw new System.Exception(err);

AssetDatabase.RenameAsset("Assets/Prefabs/Props/Crate.prefab", "SupplyCrate"); // no extension
AssetDatabase.SaveAssets();
```

`MoveAsset` returns an error string rather than throwing, so an unchecked call fails silently and
the task reports success. Always check it. The destination folder must already exist — create it
with `AssetDatabase.CreateFolder`, not `Directory.CreateDirectory`, so the folder gets its own
meta.

To delete, `AssetDatabase.DeleteAsset` — it removes the meta too. Deleting the file by hand
leaves an orphan meta behind.

## Writing new assets

`SaveAsPrefabAsset` and friends generate the `.meta` for you on the next import, but only if the
asset database sees the file. When a task writes assets through anything other than
`AssetDatabase`, finish with:

```csharp
AssetDatabase.SaveAssets();
AssetDatabase.Refresh();
```

Then confirm both files exist before reporting success — the check in step 5 of the skill catches
the case where one of them did not appear.
