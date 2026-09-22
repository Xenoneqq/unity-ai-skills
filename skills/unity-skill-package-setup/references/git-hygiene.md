# Git hygiene for a Unity repo

Two files decide whether this repo is workable: `.gitignore` decides what gets committed, and
`.gitattributes` decides whether a scene conflict is survivable.

## Check behaviour, not text

Grepping `.gitignore` tells you what it says. `git check-ignore` tells you what git will actually
do, including rules inherited from a parent `.gitignore` or a global one. Always check behaviour:

```bash
cd "$REPO"
check() { git check-ignore -q "$1" && echo "IGNORED  $1" || echo "tracked  $1"; }
for p in Library Temp Obj Logs UserSettings MemoryCaptures Build; do check "$ROOT/$p/x"; done
check "$ROOT/Assets/Foo.prefab"
check "$ROOT/Assets/Foo.prefab.meta"
check "$ROOT/Assets/Deep/Nest/Bar.asset.meta"
```

Read the result against what it should be:

| Path | Must be |
|---|---|
| `Library/`, `Temp/`, `Obj/`, `Logs/`, `Build/`, `MemoryCaptures/` | IGNORED — generated, and `Library` alone is gigabytes |
| `UserSettings/` | IGNORED — per-user editor layout and state, pure conflict noise |
| Any asset under `Assets/` | tracked |
| **Any `.meta` under `Assets/`, at any depth** | **tracked** |

The meta row is the one that silently ruins a project. A broad `*.meta` rule, or a careless
`*.asset` style pattern, makes assets arrive without their GUIDs on every fresh clone and breaks
every reference to them. Unity's standard template guards it with a negation that must survive
any edit:

```
# Asset meta data should only be ignored when the corresponding asset is also ignored
!/[Aa]ssets/**/*.meta
```

If a `.meta` under `Assets/` comes back IGNORED, that is the highest-priority finding in the
whole setup. Say so plainly.

## What a missing file looks like

If there is no `.gitignore` at all, offer Unity's standard template. Beyond the generated
directories above it also covers the IDE project files Unity rewrites constantly (`*.csproj`,
`*.sln`, `*.user`), build outputs (`*.apk`, `*.aab`, `*.app`, `*.unitypackage`) and crash dumps.
Those are regenerated from the project and committing them produces conflicts nobody can resolve.

Propose it; do not write it silently. An existing `.gitignore` gets additions shown to the user,
never a replacement — projects often ignore things for reasons that are not visible from here.

## Teaching git to merge scenes

Unity ships a YAML-aware merge tool that resolves the mechanical scene and prefab conflicts plain
git cannot. Wiring it up touches the user's git config and adds a tracked `.gitattributes`, so
**ask before doing it**.

```
# .gitattributes
*.unity   merge=unityyamlmerge eol=lf
*.prefab  merge=unityyamlmerge eol=lf
*.asset   merge=unityyamlmerge eol=lf
```

```bash
git config merge.unityyamlmerge.name "Unity SmartMerge"
git config merge.unityyamlmerge.driver '"<tool path>" merge -p --force %O %B %A %A'
```

The tool lives beside the editor; `unity-scene-habits` has the per-platform paths. The
`.gitattributes` file is shared, but **the `git config` half is per-clone** — every teammate runs
it themselves or the driver silently does nothing for them. Say that when you set it up, and put
it in `CLAUDE.md` so the next person finds it.
