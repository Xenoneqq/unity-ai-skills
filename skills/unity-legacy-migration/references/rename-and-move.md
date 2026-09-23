# Renaming and moving without losing a GUID

Every asset under `Assets/` is two files: the asset and its `.meta`. The `.meta` holds the GUID
that every scene, prefab and asset reference points at. `mv` and `git mv` move one file, so they
break the pair and every reference with it — including on a `.cs`, which is an asset like any
other once it lives under `Assets/`.

Two APIs move both files and keep the GUID. Drive them through the editor CLI per
`unity-scene-habits` — the connected path on 6.0+, batch mode otherwise.

| Call | Signature | Returns |
|---|---|---|
| `AssetDatabase.RenameAsset` | `(string pathName, string newName)` | `""` on success, otherwise an error message |
| `AssetDatabase.MoveAsset` | `(string oldPath, string newPath)` | `""` on success, otherwise an error message |
| `AssetDatabase.ValidateMoveAsset` | `(string oldPath, string newPath)` | `""` if the move would succeed |

All three are present and identical in shape on 2022 LTS and Unity 6.

## They return errors, they do not throw

This is the trap that makes a migration look finished when nothing moved:

```csharp
var err = AssetDatabase.MoveAsset(oldPath, newPath);
if (!string.IsNullOrEmpty(err))
    throw new System.Exception($"move failed: {oldPath} -> {newPath}: {err}");
```

Never call either one as a bare statement. A failed move is an ordinary return value, and a task
script that ignores it exits 0 having done nothing.

`newName` for `RenameAsset` is the name **without** the extension — `"Health"`, not
`"Health.cs"`. Unity keeps the existing extension.

Use `ValidateMoveAsset` first when you are moving in bulk: it answers without touching anything,
so a whole batch can be checked before a single file changes. The usual reason a move is
refused is that the destination folder does not exist — create it with
`AssetDatabase.CreateFolder(parentFolder, newFolderName)`, which returns the new folder's GUID,
and check `AssetDatabase.IsValidFolder(path)` if you are unsure.

## Renaming a script is one change made of two edits

Unity resolves a component's script by GUID, then resolves the *class* inside that script by
matching the class name to the file name. Both editors refuse a mismatch outright — *"The
scripts file name does not match the name of the class defined in the script!"* — and a component
whose script resolves to no class shows as *"The referenced script on this Behaviour is
missing!"* with its serialized data stranded.

So rename the class in the source **and** the file through `RenameAsset`, and do not let the
editor import between the two. On the connected path, do both inside one command. In batch mode,
edit the source file and run the rename in the same invocation.

```csharp
// after the source edit, in the same run
var path = AssetDatabase.GUIDToAssetPath(guid);      // resolve by GUID, not by old path
var err  = AssetDatabase.RenameAsset(path, "Health");
if (!string.IsNullOrEmpty(err)) throw new System.Exception(err);
AssetDatabase.SaveAssets();
```

Resolving the path from the GUID rather than hard-coding the old path is worth the extra line:
it is the one identifier that does not change, and a script that hard-codes paths silently
no-ops the second time it runs.

Anything that referred to the old class name in *source* — `using`, type references, `nameof`,
a string passed to `Type.GetType` — still has to be updated by hand. The compiler catches the
first three. It catches none of the strings.

## Moving many files

Every move triggers an import. Wrap a batch so the project imports once:

```csharp
try
{
    AssetDatabase.StartAssetEditing();
    foreach (var (from, to) in moves)
    {
        var err = AssetDatabase.MoveAsset(from, to);
        if (!string.IsNullOrEmpty(err)) failures.Add($"{from}: {err}");
    }
}
finally
{
    AssetDatabase.StopAssetEditing();   // must run even on an exception
}
AssetDatabase.Refresh();
```

The `finally` is not optional. `StartAssetEditing` pauses automatic importing project-wide; an
exception that escapes without `StopAssetEditing` leaves the editor in that state, and the
symptom — asset changes that appear to do nothing — looks like anything except its cause.

Collect failures and report all of them. Stopping at the first one leaves a half-moved folder,
which is the worst of both outcomes.

## Moving a folder

`MoveAsset` takes a folder path and moves the folder, its contents and every `.meta` in one
call. Prefer that over moving files one at a time: fewer imports, and no window where half the
folder is in each place.

A folder move is still a large diff — every path under it changes — so it gets its own commit
with nothing else in it, and `STRUCTURE.md` is updated in that same commit per
`unity-file-structure-habits`.

## After the move

```bash
git status --porcelain -- Assets | head -50
```

Three things to confirm before committing, in this order:

1. **Every rename shows as a pair.** The asset and its `.meta` moved together. A file that moved
   without its meta, or a meta left behind alone, is the failure this whole procedure exists to
   prevent.
2. **No GUID changed.** A renamed asset keeps its GUID; if `git diff` shows the `guid:` line in a
   `.meta` changing, the file was deleted and re-imported rather than renamed, and every
   reference to it is now dead.
3. **The broken-reference scan is clean** relative to the base branch — `unity-agent-worker`,
   `references/verification.md`.

If any of the three fails, revert the whole commit and redo the move. Repairing a half-broken
rename by hand means editing `.meta` files, which nothing in this plugin permits.
