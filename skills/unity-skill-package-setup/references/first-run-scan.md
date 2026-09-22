# The first-run scan

A project adopting these skills has years of decisions already in it. This pass reads them, so
`STRUCTURE.md` describes the project rather than an ideal, and so the user starts with a real
backlog instead of a clean-looking repo that quietly is not.

**Read-only. Change nothing.** Findings go to the user; fixing them is separate work, and most of
it belongs to `unity-manage-work`.

Run the independent lookups as parallel read-only agents — they do not touch each other.

## Filter third-party first

Establish the vendor paths before anything else and exclude them from every count. Imported
packages are large, churn on import, and will otherwise dominate every ranking — an asset store
package's example scenes can easily out-rank the project's own.

```bash
VENDOR='Assets/(ThirdParty|Plugins|Mirror|.*Examples?)/'   # widen from what you actually see
ls -d "$ROOT/Assets"/*/ | sed "s|$ROOT/||"
```

Show the user the exclusion list. Getting it wrong in either direction makes the whole scan
misleading.

## What to look for

**Contested scenes.** Which scenes change most, and which are changed by more than one person —
these are the ones that will hurt, and they set the order in `unity-manage-work`'s conflict map.

```bash
git log --format= --name-only -- '*.unity' | sed '/^$/d' | grep -Ev "$VENDOR" |
  sort | uniq -c | sort -rn | head -10
```

Also run the cross-branch scan from `unity-scene-habits` — a scene already being edited on
another branch is a live hazard, not a statistic.

**Unpaired metas across the whole tree**, not just new files. An asset committed without its
`.meta`, or a meta whose asset is gone, is already breaking references for someone.

**Folders that are not in the tree.** Anything under `Assets/` outside the vendor list and
outside the scaffold is an uncategorised category. It is not wrong — it is a row that
`STRUCTURE.md` is missing.

**Assembly definitions.** Count `.asmdef` files. A project with none recompiles every script on
every change, which is the difference between a two-second and a forty-second edit loop, and it
taxes every worker and every batch run. Report it; adding them restructures compilation and is
its own task.

**Render pipeline.** Built-in, URP or HDRP — it changes what a material or a shader asset even
is. Check the graphics settings and the installed packages. It belongs in the generated
`CLAUDE.md`.

**`Resources/` usage.** Everything inside ships and is indexed at startup. A large `Resources/`
is a build-size finding worth naming.

**Loose objects that should be prefabs.** Sample the project's own scenes for top-level objects
matching the prefab table in `unity-scene-habits`. Do not open every scene — a couple of the
contested ones is enough to say whether the habit is already there.

## What to produce

1. **Findings**, ordered by what will hurt soonest: broken references first, then contested
   scenes, then structure gaps, then the advisory items.
2. **A backlog** the user can hand straight to `unity-manage-work` — one line per task, each a
   real deliverable, already ordered by the conflict map.
3. **The folder list that `STRUCTURE.md` must cover**, including the uncategorised ones, so the
   generated file matches the project on day one.

Say clearly which findings you are confident about and which came from a sample. A scan that
overstates its coverage is worse than one that admits it looked at three scenes.
