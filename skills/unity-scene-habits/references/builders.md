# Builders

A builder is editor code that generates assets the project commits: prefabs, a test scene,
textures, baked data. Read this before writing one, or before rerunning one somebody else wrote.

## Where they live

Commit them, next to nothing else: `Assets/Editor/Builders/<Feature>Builder.cs`, or the project's
own editor-tools folder if it has one. The gitignored task runner from
[batch-mode.md](batch-mode.md) only calls them.

A builder kept in the ignored runner works until someone needs it. Nobody can regenerate the
assets from a fresh clone, every change to it skips review, and several workers editing one
uncommitted file leaves its history only in their reports.

## Rerunning must be harmless

Run a builder twice and the second run should change nothing. That is what makes it safe to
rerun after someone else's change.

- **Edit existing prefabs in place** through `PrefabUtility.EditPrefabContentsScope` or by loading
  the asset. Deleting and recreating one gives it a new GUID, breaking every reference, and new
  fileIDs for every child, which churns every scene that uses it.
- **Re-bake into the existing data asset** (navmesh, lighting, anything with a `.asset` output)
  rather than deleting it and making a new one. Same GUID problem.
- **Create only what is missing.** Look up an object by name or component before adding it.
- **Verify only what the builder owns.** A check like "the scene has exactly one camera" breaks
  the day another builder adds a second. Check your own objects.
- **Enforce order in code.** If one builder needs another's output, it checks for it and fails
  with a clear message, or calls that builder itself. A note in a comment is not enforcement.
- **Stop regenerating what a person has edited.** Once someone hand-tunes generated geometry or
  layout in the editor, the builder must leave it alone. The simplest rule: it only creates an
  area when the area is missing.

To check that a rerun is neutral, run it and look at `git status`. If fileIDs churn anyway, a
coarse check that ignores them compares the YAML with IDs normalised. Unity orders objects by
fileID, so sort the lines too:

```bash
norm() { sed -E 's/&-?[0-9]+/\&N/; s/fileID: -?[0-9]+/fileID: N/g' | sort; }
diff <(git show HEAD:"$f" | norm) <(norm < "$f") && echo "neutral apart from fileIDs"
```

It is coarse on purpose: equal output means the same content, but a reordered hierarchy can hide.
Prefer builders that keep their IDs, so the plain `git status` check is enough.

## Scenes built from code

A new scene made by a builder looks unlit until lighting is generated once, because on recent
editors the scene's ambient settings only apply through its lighting data. Generate lighting once
(baked and realtime GI off is enough) and commit the resulting `LightingData.asset` with its
`.meta`.

## Changes the editor makes on its own

Some files change without anyone asking. Expect them, commit them as a separate housekeeping
commit, and do not treat them as a worker's work:

- **Opening the editor** re-saves materials whose properties it syncs, for example a render
  pipeline copying a legacy colour property into its own.
- **The first run of a new editor** can add files under `ProjectSettings/`.
- **Adding a layer or tag** bumps `TagManager.asset`'s `serializedVersion` and trims empty slots.
- **The first player build** re-serializes some graphics, player and pipeline settings.

Check that those are the only changes in those files. Anything else in them is real.

## Project-wide settings get a test

When the whole project must share an import setting, such as point filtering in a pixel-art
game, a fixed pixels-per-unit, or a compression rule, check it with an EditMode test rather than
by convention. A convention holds for the worker who knows it; the test holds for the next one.

```csharp
[Test]
public void ArtTexturesArePointFiltered()
{
    foreach (var guid in AssetDatabase.FindAssets("t:Texture2D", new[] { "Assets/Art" }))
    {
        var path = AssetDatabase.GUIDToAssetPath(guid);
        if (AssetImporter.GetAtPath(path) is TextureImporter importer)
            Assert.AreEqual(FilterMode.Point, importer.filterMode, path);
    }
}
```

Use the project's own art folder, and have the builder that makes each texture set the same
settings it is tested against.
