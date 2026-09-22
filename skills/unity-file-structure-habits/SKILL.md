---
name: unity-file-structure-habits
description: >
  Decide where a new file or asset goes in a Unity project, and keep the layout from drifting:
  read STRUCTURE.md as the authority, follow what the project already does over any default,
  move assets only through the editor so references survive, add a category rather than dumping
  a file in the nearest folder, and update STRUCTURE.md when the tree gains something new. Use
  when: creating a script, prefab, material or any asset; "where should this go", "where do I put
  this", "the project structure is a mess", "/unity-file-structure-habits"; or reviewing a change
  that adds files.
---

# Unity file structure habits

One rule: **the project's own layout wins.** `STRUCTURE.md` records it, the tree confirms it, and
both outrank every default in this file.

A structure is only worth having if it answers the question "where does this go" without a
discussion. That means it has to be written down, and it has to stay true.

## 1. Before creating anything, read the layout

```bash
REPO=$(git rev-parse --show-toplevel)
sed -n '1,80p' "$REPO/STRUCTURE.md" 2>/dev/null || echo "no STRUCTURE.md — see step 5"
ls -d "$ROOT/Assets"/*/
```

`STRUCTURE.md` is the authority. Where it and the tree disagree, the tree is what exists and the
file is what someone intended — report the gap, do not silently pick one.

No `STRUCTURE.md` at all means the project has not been set up. Run
`unity-skill-package-setup` rather than inventing a layout here; it scans what the project
already is first, which is the part that matters.

## 2. Placing a file

Ask in this order, stopping at the first answer:

1. **Does `STRUCTURE.md` name a folder for this kind of thing?** Use it. Done.
2. **Does a sibling of the same kind already exist?** Put it beside them and mirror their naming.
   One existing example beats any rule here.
3. **Is it third-party?** It keeps the layout it shipped with, untouched. Never reorganize an
   imported package — the next update undoes the work and the conflicts are miserable.
4. **Otherwise it is a new category.** Go to step 4. Do not resolve it by dropping the file in
   the closest folder that nearly fits.

Two defaults, for when the project genuinely has no opinion:

- **Scripts split by feature, not by type.** `Scripts/Inventory/`, not `Scripts/Managers/` and
  `Scripts/Interfaces/`. Type folders stop meaning anything at around thirty files and scatter
  one feature across five directories.
- **Assets group by what they are part of**, not by file extension, once a feature owns more than
  a few. A folder per enemy beats a pile of every mesh in the game.

## 3. Folder names Unity treats specially

These change how the project compiles and ships. They are not style choices:

| Name | Effect |
|---|---|
| `Editor/` | Compiles into an editor-only assembly, ships in no build. Works at any depth. |
| `Resources/` | Everything inside ships and is indexed at startup, referenced or not. |
| `StreamingAssets/` | Copied verbatim into the build, readable at runtime by path. |
| `Plugins/` | Native libraries and platform binaries. |

Never create a folder with one of these names for an unrelated reason — a folder called
`Resources` for "resource sprites" quietly adds all of them to every build. And never put runtime
code under `Editor/`: it will not exist in a build and the failure appears only at player build
time.

## 4. Adding a category

A new category is a small, deliberate change, not a side effect of saving a file.

1. Create the folder where it belongs in the existing hierarchy — beside its peers, not at the
   root because the root is easier to find.
2. Name it for what it holds, in the project's existing casing. Match `Scripts/` vs `scripts/`
   to whatever is already there; consistency beats correctness here.
3. **Add a row to `STRUCTURE.md` in the same change.** A folder that exists but is not in the
   table is exactly the drift this skill is for.
4. If it is empty for now, mark it with `.gitkeep` — Unity's importer ignores dot-prefixed files,
   so it generates no `.meta` and never appears in the project window.

## 5. Moving and renaming

**Never `mv` or `git mv` an asset under `Assets/`.** The GUID that every reference points at lives
in the sibling `.meta`; moving one without the other breaks every scene and prefab that used it.
Use `AssetDatabase.MoveAsset` / `RenameAsset`, driven through the CLI — `unity-scene-habits` has
the recipe and the trap that `MoveAsset` returns an error string rather than throwing.

C# files outside `Assets/` are ordinary files and move normally. Inside `Assets/`, a `.cs` file is
still an asset with a meta, and moving it by hand breaks every serialized reference to the
component in every prefab and scene.

Restructuring an existing project is a task with its own review, not something to do while
passing through. If the right fix is "this whole folder is in the wrong place", say so and let it
be scheduled — `unity-manage-work` can order it against the scenes it touches.

## 6. Keeping STRUCTURE.md true

Check for drift whenever a change adds folders, and whenever you are asked whether the structure
is a mess:

```bash
# folders on disk, one per line, against the paths the table names
ls -d "$ROOT/Assets"/*/ | sed "s|.*/Assets/|Assets/|"
grep -oE '`Assets/[^`]*`' "$REPO/STRUCTURE.md" | tr -d '`' | sort -u
```

Three outcomes, three different actions:

- **On disk, not in the table** → the table is behind. Add the row, or say what the folder is if
  you cannot tell.
- **In the table, not on disk** → either it was removed, or nobody has needed it yet. An
  aspirational row for a folder that has never existed should go; the table describes the
  project, it does not prescribe one.
- **Third-party folders** → one row covering the vendor directory, not a row per package. The
  table is a map, not an inventory.

Update `STRUCTURE.md` in the same commit as the change that moved the tree. A structure file
updated separately is a structure file that is wrong in between.
