# What to check, per extension

One section per thing the census turns up. Read the ones in front of you and skip the rest. Where
a line says "per `<skill>`", that skill owns the rule — apply it, do not argue with it here.

## `.cs`

Ordinary code review first: does it do the task, is it readable, does it handle the empty and
error cases. Then the Unity reads, per `unity-coding-habits`:

- **A serialized field renamed, retyped or moved to another type**, with no
  `[FormerlySerializedAs]`. Every value set in a prefab or scene reverts to the default, silently.
- **`public` fields added** where a `[SerializeField] private` field plus a read-only property
  would do. Public is API; serialized is data.
- **`?.`, `??` or `??=` on anything deriving from `UnityEngine.Object`.** They bypass the
  overloaded `==`, so they run on destroyed objects.
- **New work inside `Update`, `FixedUpdate` or `LateUpdate`** — lookups, allocations, `Camera.main`,
  string comparisons, `Find*`. Diff with `-W` to see which method a hunk is in.
- **`+=` with no `-=`.** Subscribe in `OnEnable`, unsubscribe in `OnDisable`; `Awake` pairs with
  `OnDestroy`. A static event that is never detached survives scene loads.
- **A new way for objects to find each other** — a singleton in a project that uses serialized
  references, or a scene search in a project that uses a registry. Mixing mechanisms is the cost.
- **Editor-only code outside an `Editor/` folder or assembly**, and runtime code inside one. The
  second fails only at player build time.
- **Restyling in passing** — renames, reordered members, reformatting in code the task merely
  touched. Say it and stop reviewing those hunks; ask for them to come out.

Networked C# — `NetworkBehaviour`, `[Command]`, `[ClientRpc]`, `[SyncVar]` — goes to
`unity-multiplayer-habits`. The four that matter most in a diff: a `[Command]` that trusts its
parameters instead of re-deriving the caller from the connection, state pushed by RPC that a late
joiner will never receive, a branch on `isServer` where it meant `isServerOnly`, and a new
spawnable prefab that is not registered anywhere.

## `.unity`

- **Should this task have touched a scene at all?** Per `unity-scene-habits`, only a new top-level
  instance, lighting and environment, wiring two separate instances, or the build scene list do.
  Everything else is a prefab edit that leaked into the scene.
- **Is the diff proportionate to the change?** If not, the editor re-serialized the file.
- **Lighting or navmesh data** in the diff — large generated blocks. Whether they belong in the
  commit is a project decision, so ask rather than assume.
- **`m_LocalPosition` / `m_LocalRotation` churn** across objects the task never mentions — usually
  something got dragged in the hierarchy window.
- **Is another branch editing the same scene?** The scan is in
  [`unity-scene-habits/references/scene-scan.md`](../../unity-scene-habits/references/scene-scan.md),
  and the answer goes in the report either way.
- **Components inlined into the scene** that the census shows are not backed by a prefab — the
  thing the prefab-first habit exists to prevent.

## `.prefab`

- **Both files present** — the prefab and its `.meta`.
- **Edited as an asset, not through an instance.** A prefab change paired with a scene change to
  the same objects usually means overrides were applied from an instance.
- **A new prefab that is a variant of an existing one**, or that should have been. Duplicated
  hierarchies are the version of copy-paste that does not show up in a code diff.
- **`m_Script:` lines added** — new components. Check each against the C# section.
- Prefab modifications removed wholesale (`m_Modifications`) means a link was broken or unpacked.
  `unity-scene-habits` forbids `UnpackPrefabInstance` for exactly this reason.

## `.asset`, `.mat`, `.controller`, `.anim`, `.shadergraph`

Serialized data. Read it as data, and read the values, not the structure.

- **A `ScriptableObject` asset whose script changed** in the same diff — a renamed or retyped
  field here loses the tuned numbers, and this is where tuned numbers live.
- **Tuning changes with no mention in the description.** A damage or cost value moved in an asset
  is a gameplay change, however small the diff.
- **A material or shader swap** on something the task did not claim to touch visually.
- **A new asset that duplicates an existing one** rather than referencing it.

## `.meta`

- **Never review a hand-edited `.meta`.** The only legitimate diffs here are importer settings
  changed through the inspector, and the file appearing or disappearing with its asset.
- **A changed `guid:` line is a blocker.** A GUID does not change under normal use; if it did, the
  asset was deleted and re-imported, and every reference to the old GUID is now broken.
- **Importer settings changed on assets the task did not touch** — a texture compression or model
  import sweep hidden inside a feature change. Ask for it as its own commit.

## `.asmdef`, `.asmref`

- **A new assembly definition changes what compiles against what**, and a script that moves into
  one loses access to everything that assembly does not reference. Check the references list, not
  just the file.
- **A missing platform or `Editor` constraint** on an editor-only assembly.
- **An asmdef added in a folder that already had scripts** pulls all of them in. That is a bigger
  change than the diff looks.

## `ProjectSettings/`

Project-wide, and the diff is usually smaller than the consequence.

| File | What it means |
|---|---|
| `ProjectVersion.txt` | An editor upgrade — irreversible, and everyone follows. Blocker unless that *is* the change. |
| `EditorBuildSettings.asset` | The build scene list. A removed or reordered scene changes what ships and what loads first. |
| `TagManager.asset` | Tags, layers and sorting layers, referenced by index. Inserting one renumbers the rest. |
| `InputManager.asset` | Input axes by name. A rename breaks every call that used the old one. |
| `GraphicsSettings.asset`, `QualitySettings.asset` | Render pipeline and quality tiers — global, and a common accident. |
| `ProjectSettings.asset` | Bundle id, company, versions, platform settings. Check nothing personal landed here. |

## `Packages/manifest.json`, `Packages/packages-lock.json`

A dependency decision, not an implementation detail. Check the package was actually agreed, that
the version is pinned the way the project pins things, and that a lock-file change matches the
manifest change. A lock file moving on its own means someone's editor resolved something.

## Binary assets — textures, models, audio, fonts

`git diff` cannot show you these, so review the facts around them:

```bash
git diff --no-renames --diff-filter=A --name-only "$BASE...HEAD" -- Assets |
  xargs -I{} sh -c 'test -f "{}" && echo "$(wc -c < "{}") {}"' | sort -rn | head
```

- **Size.** A large binary committed straight into git is there forever. Check whether the project
  uses Git LFS (`.gitattributes`), and whether this file matches those patterns.
- **Licence and provenance** for anything that came from outside. If the change cannot say where
  an asset came from, that is a finding.
- **Its `.meta`** — importer settings for a new texture or model are part of the review, even when
  the asset itself is opaque.

## Files that should not be in the diff at all

Each of these is a `[BLOCKER]` on sight, because they land on everyone:

- `Library/`, `Temp/`, `Obj/`, `Logs/`, `UserSettings/`, `Build/`, `Builds/` — generated.
- `*.csproj`, `*.sln` — regenerated by the editor per machine.
- `.gitignore` that stops ignoring the above, or starts ignoring `*.meta` under `Assets/`.
- `.vscode/`, `.idea/`, `.DS_Store` and friends, unless the project deliberately commits them.
- Anything holding a key, a token, a signing credential or a personal path.
