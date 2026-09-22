# The folder scaffold

## The default tree

Propose this, adapt it to what the project already calls things, and create only what is missing.

```
Assets/
  Scenes/        every .unity file
  Prefabs/       prefab assets, grouped by kind as the project grows
  Scripts/       runtime C#, split by feature not by type
  Materials/
  Textures/
  Models/        meshes and their imported rigs
  Audio/
  Animations/    clips, controllers, timelines
  UI/            UI prefabs, sprites, fonts
  Settings/      ScriptableObject config assets
  Editor/        editor-only C# — see below, the name is load-bearing
  ThirdParty/    imported packages, left exactly as they came
```

`Scripts/` splits by feature — `Scripts/Inventory/`, `Scripts/Enemies/` — not by type
(`Scripts/Managers/`, `Scripts/Interfaces/`). Type-based folders stop meaning anything at about
thirty files, and they scatter one feature across five directories.

## Folder names Unity treats specially

These are not conventions, they change how Unity compiles and ships the project. Never create,
rename or move one casually:

| Name | What Unity does with it |
|---|---|
| `Editor/` | Contents compile into an editor-only assembly and ship in no build. Required for `-executeMethod` task scripts. Works at any depth. |
| `Resources/` | Everything inside ships in the build and is indexed at startup, whether referenced or not. |
| `StreamingAssets/` | Copied to the build verbatim, readable at runtime by path. |
| `Plugins/` | Native libraries and platform-specific binaries. |
| `Gizmos/`, `Standard Assets/` | Legacy special cases; leave alone if present. |

**Do not scaffold `Resources/` by default.** It looks like the obvious place for loadable assets
and it is a build-size trap — everything in it is included and loaded regardless of use. Create
it only if the project already relies on it, and say why when you do.

## Creating the folders

Empty directories do not exist in git, so a bare `mkdir` scaffold vanishes on clone. Mark each
one:

```bash
for d in Scenes Prefabs Scripts Materials Textures Models Audio Animations UI Settings Editor; do
  [ -d "$ROOT/Assets/$d" ] || { mkdir -p "$ROOT/Assets/$d" && touch "$ROOT/Assets/$d/.gitkeep"; }
done
```

`.gitkeep` is the right marker specifically because **Unity's importer ignores anything starting
with a dot**. It generates no `.meta`, never appears in the project window, and adds no asset
churn. A `README.txt` or an empty `.asset` would do none of that.

Unity generates each new folder's own `.meta` on the next import. That meta is a real tracked
file and belongs in the same commit as the folder — the pairing rule from `unity-scene-habits`
applies to folders exactly as it does to assets.

## What not to do

- **Never move or rename an existing folder** as part of setup. It breaks references unless done
  through `AssetDatabase.MoveAsset`, and reorganizing a live project is its own task with its own
  review, not a side effect of adding a CLAUDE.md.
- **Never reorganize `ThirdParty/` or an imported package.** Re-importing or updating it will
  undo the work and the conflicts are miserable. Imported assets keep the layout they shipped
  with.
- **Do not invent categories the project has no assets for.** An empty `Animations/` in a project
  with no animation is noise that everyone learns to ignore. Scaffold what is used; let
  `STRUCTURE.md` grow as real categories appear.
