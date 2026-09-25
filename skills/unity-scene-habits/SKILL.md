---
name: unity-scene-habits
description: >
  Prefab-first habits for working in a Unity project through the editor CLI: turn anything
  groupable into a prefab, make changes as prefab-asset edits instead of scene edits, keep the
  scene out of the diff unless the task genuinely needs it, never break an asset reference, and
  say so at the end when another branch already edits the same scene. Use when the work touches a
  scene, a prefab, an asset or the editor itself: "add this to the scene", "make this a prefab",
  "why does my scene keep conflicting", "run Unity headless", "-executeMethod",
  "/unity-scene-habits", or any change that would touch a `.unity`, `.prefab` or `.meta` file.
---

# Unity scene habits

Two rules. Everything below is how to keep them.

**Prefab first.** If a thing can be grouped, it is a prefab. Prefabs are cheap to save, cheap to
edit, and two people editing two prefabs do not conflict.

**Scene last.** A scene is one giant shared file. Every line you add to it is a merge conflict
someone else pays for. Change it only when the task cannot be done any other way.

Work through the editor CLI, not by hand-editing files. Scene and prefab files are YAML with
internal file ids and GUID references; a hand edit that looks right corrupts references you
cannot see. The editor is the only safe writer.

## 1. Probe before touching anything

Two things decide how you work: the editor version, and whether the Unity CLI is here. Run this
from inside the repo. Do not skip it — the project root is often not the repo root, and the
quoting matters because project paths contain spaces.

```bash
PV=$(find . -path '*/ProjectSettings/ProjectVersion.txt' -not -path '*/Library/*' -print -quit)
ROOT=$(dirname "$(dirname "$PV")")
VER=$(awk '/^m_EditorVersion:/{print $2}' "$ROOT/ProjectSettings/ProjectVersion.txt")
echo "project root  : $ROOT"
echo "editor version: $VER"
awk '/m_SerializationMode/{print "serialization : "$2"  (2 = force text; anything else, stop)"}' "$ROOT/ProjectSettings/EditorSettings.asset"

if command -v unity >/dev/null; then
  unity editors -i --verbose --json --no-banner   # installed editors, with locations
  unity license --json --no-banner                # data: [] means no licence
  unity pipeline list --json --no-banner          # which editors are running
  unity status --json --no-banner                 # which of them are connected and ready
else
  echo "no unity CLI — batch mode only"
fi
```

**Pick the path from the editor version.** Pipeline needs **6.0 or newer**; that floor is not
negotiable and no amount of CLI version will move it.

| Project editor | Path | Reference |
|---|---|---|
| 6.0+, editor running, Pipeline installed | Connected editor — `unity command eval`, `[CliCommand]` | [references/connected-editor.md](references/connected-editor.md) |
| 2022 LTS or older, no editor running, or CI | Batch mode — `-executeMethod` | [references/batch-mode.md](references/batch-mode.md) |

Prefer the connected path when it is available. Batch mode pays an editor boot and a script
recompile per change; the connected path answers in milliseconds against the already-loaded
project.

With Pipeline installed but no editor open, do not open one on your own: it takes a window and
the user's focus. Ask the user once whether to (a manager asks at kickoff). If the editor closes
mid-session, carry on in batch mode without asking again. Never open the editor while a batch
job is running; it takes the project lock and the job fails.

**Confirm the editor is reachable before any connected work.** `unity status --json` should list
this project in state `ready`. Two things make a running editor look absent, and neither means
"fall back to batch mode" or "edit the files by hand":

- **Safe Mode.** A project with compile errors opens in Safe Mode, where no package loads,
  Pipeline included. `unity pipeline list` reports it. Fix the compile errors in the C# source,
  then ask the user to restart the editor.
- **Your own sandbox.** A sandboxed shell can be blocked from seeing the editor's discovery file
  or its local port, and gets the same "no editor" answer. If the user may have one open, ask.
  Never suggest turning the sandbox off; suggest running the one blocked command outside it.

[references/connected-editor.md](references/connected-editor.md) has how to tell these apart.

Without the Unity CLI, resolve the editor binary by hand:

| Platform | Path |
|---|---|
| macOS | `/Applications/Unity/Hub/Editor/$VER/Unity.app/Contents/MacOS/Unity` |
| Windows | `C:\Program Files\Unity\Hub\Editor\$VER\Editor\Unity.exe` |
| Linux | `~/Unity/Hub/Editor/$VER/Editor/Unity` |

Four things stop the work before it starts:

- **No licence.** Both paths need one and neither will prompt. Batch mode dies after about
  thirty lines of licensing output ending in `No valid Unity Editor license found`, exit 1, with
  `-executeMethod` never run. Note that `unity license` reports `"success": true` and exit 0 even
  when there is no licence — the empty `data` array is the real answer. Only the user can fix
  this, by signing in through Unity Hub or `unity auth login`. Never handle their credentials.
- **Serialization is not Force Text.** Diffs and merges are worthless until it is. Tell the user;
  do not flip it yourself, it rewrites every asset in the project.
- **The editor and the project lock.** Batch mode refuses a project an editor has open; the
  connected path *requires* one open. The same fact points opposite ways, so establish which path
  you are on first. Never close someone's editor to clear a lock without asking — `unity close`
  exits without saving.
- **That editor version is not installed.** Never substitute a nearby version — opening a project
  in a newer editor upgrades it irreversibly.

If the project documents its own layout, folder conventions, or prefab rules, those win over
everything in this file. Read its contributor notes first.

## 2. Decide: prefab edit, or scene edit

Ask one question before every change: **could this be a change to a prefab asset the scene
already instances?** If yes, it is not a scene change. Do it as a prefab edit.

These should all be prefabs. If the task touches one of them and it is loose in the scene, that
is the bug — fix it by prefabizing, not by editing the scene around it.

| Kind | Examples |
|---|---|
| Anything spawned at runtime | enemies, projectiles, pickups, effects, popups |
| Anything made of parts | a house, a vehicle, a prop cluster, a map section, a whole map |
| Managers | a GameObject that carries nothing but logic scripts |
| The player | the rig, its camera, its input, as one prefab |
| UI | screens, panels, reusable widgets, list rows |

### What genuinely needs the scene

Short list. If the task is not one of these, it is not a scene change:

- **Placing a new top-level instance** — the scene is where instances live, so adding one shows
  up there. Adding a *child* to an existing prefab does not.
- **Lighting and environment** — skybox, fog, ambient, baked data. These are scene settings and
  have nowhere else to go.
- **Wiring two separate instances together**, where neither prefab can hold the reference.
- **The build settings scene list**, which is `ProjectSettings`, not the scene, but travels with
  the same kind of change.

Everything else — values, components, hierarchy inside a group, new children, swapped meshes,
adjusted scripts — belongs in a prefab asset.

Converting a loose object into a prefab **is** a scene change — a one-time one that removes
every future one. It is worth making, but keep it as its own commit, separate from the
behaviour change that prompted it.

## 3. Do the work

**Connected editor (6.0+).** Run C# straight against the live editor — no script file, no
recompile, no domain reload:

```bash
unity command eval "return UnityEditor.AssetDatabase.FindAssets(\"t:Prefab\").Length;" --json
```

For anything you will run more than once, register it with `[CliCommand]` instead of re-pasting
it. Installing the Pipeline package changes the project's package manifest, so **ask before
running `unity pipeline install`** — that is a dependency decision, not a detail of your task.
[references/connected-editor.md](references/connected-editor.md) has the command surface, the
result-reading traps, and the rest.

**Batch mode (older editors, CI, no editor running).** One static method per run:

```bash
"$UNITY" -batchmode -quit -nographics \
  -projectPath "$ROOT" -executeMethod CliTask.Run \
  -logFile - > /tmp/unity.log 2>&1; echo "exit $?"
tail -40 /tmp/unity.log
```

Keep the whole log — a failing run is exactly when you need the lines a `tail` would have thrown
away. Two flags deserve a decision rather than a habit: `-nographics` is right for asset work and
starts faster, but drop it when the task renders; and **`-accept-apiupdate` is not a default**,
because it lets the API updater rewrite source across the project and bury a one-line prefab
change in a thousand-line diff. If a run fails needing it, that is the user's decision, not a
flag you add to get past an error.

The task script lives in a fixed, ignored folder — `Assets/Editor/CliTasks/` — and stays there
between runs. Creating and deleting it each time forces two full script recompiles per task.
[references/batch-mode.md](references/batch-mode.md) has the scaffold, the flag list, the
licensing failure and how to read the log.

Code that generates assets the project commits is not throwaway, so it does not live there. It
goes in committed builders that rerun without changing anything;
[references/builders.md](references/builders.md) has the rules, the changes the editor makes on
its own, and when a setting needs a test instead of a convention.

Edit prefab assets directly — never by dragging an instance into a scene and applying overrides.
`PrefabUtility.EditPrefabContentsScope` opens a prefab asset, lets you change it, and saves it,
with no scene involved and no scene diff.
[references/prefab-recipes.md](references/prefab-recipes.md) has that and the rest: extracting a
selection into a prefab, adding a component across many prefabs, making variants, applying
overrides, and moving assets safely.

Never do these:

- Hand-edit `.unity`, `.prefab` or `.meta` files.
- Add, remove or upgrade a package by editing `Packages/manifest.json`. Ask first, then go
  through `UnityEditor.PackageManager.Client`, which resolves dependencies. It is asynchronous,
  which breaks the usual batch-mode run; [references/batch-mode.md](references/batch-mode.md)
  has the pattern.
- `PrefabUtility.UnpackPrefabInstance` — it destroys the link the whole habit depends on.
- Delete `Library/` to fix something. It costs a full reimport and fixes almost nothing.
- Run batch mode against a project an editor has open.
- Modify, restore, check out or delete a `.unity` or `.prefab` on disk while the user's editor
  has it open. It raises a modal dialog that blocks the editor until someone clicks it.

## 4. Keep references intact

Every asset has a sibling `.meta` file holding the GUID that every reference to it points at.
The GUID lives in the `.meta`, not in the asset. This step matters more the more prefabs you
make, which is to say: it matters here more than anywhere.

- **A new asset is two files.** `Crate.prefab` and `Crate.prefab.meta` are committed together,
  always. Commit the prefab alone and everyone else gets a fresh GUID on import — every
  reference to it silently becomes `None`, across every scene and prefab that used it.
- **Never move or rename an asset with `mv` or `git mv`.** That separates the file from its
  meta, or leaves the meta behind, and the references die. Use `AssetDatabase.MoveAsset` or
  `AssetDatabase.RenameAsset`, which move both and preserve the GUID. Recipe in
  [references/prefab-recipes.md](references/prefab-recipes.md).
- **Never delete a `.meta` to fix an import problem.** It changes the GUID on the next import,
  which is the same breakage by another route.
- **Check `.gitignore` covers meta correctly.** It must ignore `Library/`, `Temp/`, `Obj/`,
  `Logs/` and `UserSettings/`, and must *not* ignore `*.meta` under `Assets/`.

## 5. Verify before calling it done

Never report a change you have not confirmed landed. Three checks, all cheap:

**The run succeeded.** In batch mode that means exit 0 and no compile errors in the log:

```bash
grep -nE 'error CS|Exception|Aborting|No valid Unity Editor license' /tmp/unity.log | head
```

An `error CS…` means the project did not compile, so the task never ran — and the error may be
someone else's, not yours. Report it; do not paper over it.

On the connected path, read the JSON payload rather than the exit code. Some commands return
`"success": true` with empty `data` and exit 0 when the answer is "nothing found". `unity command`
exits **6** when it cannot reach a Pipeline server — editor closed, package missing, or server
down. And a pipeline masks the status: `unity command … | head` reports `head`'s exit code, not
Unity's, so capture it before piping.

**The change is actually in the asset.** Reopen it and assert, in the task script or a second
run. A `SaveAsPrefabAsset` that silently no-ops looks identical to one that worked.

**It looks right, if it is visual.** Render it to a PNG in a PlayMode test and open the PNG;
[references/visual-checks.md](references/visual-checks.md) has the recipe.

**Every asset has its meta, and every meta its asset:**

```bash
git status --porcelain -z -- "$ROOT/Assets" | while IFS= read -r -d '' e; do
  f=${e#???}
  case "$f" in
    *.meta) [ -e "${f%.meta}" ] || echo "orphan meta (asset missing): $f" ;;
    */)     ;;
    *)      [ -e "$f.meta" ]    || echo "missing meta (reference will break): $f" ;;
  esac
done
```

Silence is a pass. Any output is a broken reference waiting to happen — fix it before committing.

Then look at what you built. Anything the task touched that matches the table in step 2 and is
still loose in the scene, raise it: say what you would group and why. Do not prefabize things
the task never touched — that is someone else's diff to review.

## 6. If the scene did change, close the loop

```bash
git diff --stat -- '*.unity'
```

A scene diff of a few lines is usually fine. A large one after a small task means the editor
re-serialized something — read
[references/scene-scan.md](references/scene-scan.md) before committing it.

Then scan the other branches for the same scenes. The procedure and the exact commands are in
[references/scene-scan.md](references/scene-scan.md). **Whenever another branch touches a scene
this change touches, say so in your final message** — name the branch and the scene, and say
that a merge conflict is coming. Do not try to resolve it, and do not go quiet about it because
the change is small.

If the scene came out unchanged, say that too. It is the outcome worth reporting.
