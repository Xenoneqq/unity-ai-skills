# Keeping the scene out of the diff

## Why a scene diff costs more than it looks

A scene is one file holding every object in it, keyed by numeric file ids. Two branches that add
unrelated things to the same scene still edit the same file, often in the same region, and git
has no way to know the changes are independent. That is the whole reason for the prefab habit:
twenty prefabs are twenty small files that merge cleanly, and the same content inlined into a
scene is one file that does not.

## Judging the diff you produced

```bash
git diff --stat -- '*.unity'
```

A handful of changed lines for a handful of changed things is what you want. When the diff is
far larger than the task, the editor re-serialized the file rather than edited it. The usual
causes:

- **A different editor version opened it.** Check `ProjectSettings/ProjectVersion.txt` against
  the version you actually ran. This is the common one and it is not yours to commit — it will
  touch every scene and prefab the run opened.
- **Lighting or navmesh data rebaked.** Large blocks of generated data appear. Whether that
  belongs in the commit is a project decision; ask rather than assume.
- **Objects moved by a pixel.** `m_LocalPosition` / `m_LocalRotation` churn across many objects
  usually means something got dragged. Revert it.

To drop a scene change that was not needed at all, restore the file outright rather than editing
the diff by hand:

```bash
git checkout -- "Assets/Scenes/Main.unity"
```

Partial-hunk staging on a scene file is not safe — the hunks are not independent. All or
nothing. Close the editor first, or it will write the file back from memory.

## Teach git to merge scenes

Unity ships a YAML-aware merge tool. It will not save you from every conflict, but it resolves
the mechanical ones that plain git cannot. It lives beside the editor:

| Platform | Path |
|---|---|
| macOS | `/Applications/Unity/Hub/Editor/$VER/Unity.app/Contents/Tools/UnityYAMLMerge` |
| Windows | `C:\Program Files\Unity\Hub\Editor\$VER\Editor\Data\Tools\UnityYAMLMerge.exe` |
| Linux | `~/Unity/Hub/Editor/$VER/Editor/Data/Tools/UnityYAMLMerge` |

Wiring it up is a change to the user's git config and `.gitattributes`, so propose it rather
than doing it silently:

```
# .gitattributes
*.unity   merge=unityyamlmerge eol=lf
*.prefab  merge=unityyamlmerge eol=lf
*.asset   merge=unityyamlmerge eol=lf
```

```bash
git config merge.unityyamlmerge.name "Unity SmartMerge"
git config merge.unityyamlmerge.driver '"<path from the table>" merge -p --force %O %B %A %A'
```

## The cross-branch scan

Run this whenever the change ends up touching a scene. It answers one question: is anyone else
already editing these scenes?

```bash
BASE=${BASE:-main}
HERE=$(git rev-parse --abbrev-ref HEAD)
git fetch --all --quiet

git diff --name-only -z "$BASE...HEAD" -- '*.unity' > /tmp/scenes.nul
if [ ! -s /tmp/scenes.nul ]; then echo "no scene changes on this branch"; exit 0; fi

printf 'scenes this branch touches:\n'; tr '\0' '\n' < /tmp/scenes.nul

git for-each-ref --format='%(refname:short)' refs/heads refs/remotes |
  grep -vE "(^|/)HEAD$" | grep -vxE "$HERE|origin/$HERE" |
  while read -r b; do
    hits=$(xargs -0 git diff --name-only "$BASE...$b" -- < /tmp/scenes.nul)
    [ -n "$hits" ] && printf '\n=== %s also touches:\n%s\n' "$b" "$hits"
  done
```

Scene paths contain spaces often enough that the NUL handling matters — do not simplify it into
an unquoted variable.

Set `BASE` when the project's integration branch is not `main`. Without `git fetch`, remote
branches are whatever was last pulled, and the scan quietly under-reports.

## What to report

If nothing else touches the scenes, say so in one line — it is the good outcome and it is worth
stating.

If something does, it goes in the final message, every time, however small the change. Name the
branch, name the scene, and stop there:

> `feature/lighting-pass` also changes `Assets/Scenes/Main.unity`, which this branch edits too.
> Those two will conflict on merge.

Do not merge, rebase, or resolve anything to get ahead of it. Whoever owns the other branch
needs to know it exists; the decision about what to do is theirs and the user's.
