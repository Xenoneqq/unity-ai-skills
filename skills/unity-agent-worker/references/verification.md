# The verification ladder

Most game projects have no automated tests. A gate that only knows how to run a test suite is
useless in exactly the common case, so verification here is a ladder: climb as far as the project
allows, then **say which rung you reached**. "Gate green" on a project with no tests must not read
like "this works".

| Rung | What it proves | Needs |
|---|---|---|
| 0 | It compiles and imports | nothing |
| 1 | Nothing references a deleted asset or script | nothing |
| 2 | The game starts without throwing | an editor run |
| 3 | It builds for a target | an editor run, minutes |
| 4 | The feature actually works | **a human** |

Rung 4 is not a fallback. It is the last gate before a task is accepted, and it blocks.

## Rung 0 — compiles and imports

No `error CS` in the run. No new console errors, missing scripts or broken shaders beyond the
clean-import baseline you were given. Every asset paired with its `.meta`. The scene diff is
intended. These are in the skill's gate step and run on every commit.

## Rung 1 — broken references

The most common real breakage in a Unity project, and it needs no test framework. Two ways to
find it.

**Without the editor**, which also works while the editor is blocked. Compare every GUID that
scene and prefab files reference against every GUID declared by a `.meta`:

```bash
python3 - <<'PY'
import re, os, collections
GUID    = re.compile(rb'guid: ([0-9a-f]{32})')
BUILTIN = re.compile(rb'^0{16}[0-9a-f]0{15}$')     # Unity's own default resources
declared, refs = set(), collections.Counter()
for base in ('Assets', 'Packages', 'Library/PackageCache'):
    if not os.path.isdir(base): continue
    for root, dirs, fs in os.walk(base):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for f in fs:
            p = os.path.join(root, f)
            if f.endswith('.meta'):
                m = GUID.search(open(p, 'rb').read(4096))
                if m: declared.add(m.group(1))
            elif base == 'Assets' and f.endswith(('.unity', '.prefab', '.asset', '.mat', '.controller')):
                for g in set(GUID.findall(open(p, 'rb').read())): refs[g] += 1
miss = {g: c for g, c in refs.items() if g not in declared and not BUILTIN.match(g)}
print(f"unresolved: {len(miss)} distinct, {sum(miss.values())} sites")
for g, c in collections.Counter(miss).most_common(20): print(" ", g.decode(), c)
PY
```

Three things make this usable rather than noise, and all three matter:

- **`Library/PackageCache` must be in the declared set.** Package assets declare their GUIDs
  there, not under `Assets/`. On a real project, adding it cut the unresolved count from 104
  distinct GUIDs to 11.
- **Filter Unity's built-in resources** — the `0000000000000000?000000000000000` pattern. Those
  are the default material, default font and friends; they resolve inside the engine and have no
  `.meta` anywhere.
- **It needs a warm `Library/`.** On a cold checkout `PackageCache` does not exist yet and every
  package reference looks broken.

Some references resolve to packages that ship inside the editor rather than in `PackageCache`,
so even an untouched render-pipeline template can list a handful, typically from its renderer
and volume profile assets. Add the editor's built-in packages folder to the declared set if you
can find it, and otherwise leave them to the baseline. Keep `.mixer` files out of the scanned
set: their exposed-parameter GUIDs are not asset references.

Treat the result as **candidates to check, not a verdict** — a handful of editor-internal
references can still show up. Run it on the base branch too, and only the new ones are yours.

**With the editor**, which is authoritative. A null entry in a component list means the script is
gone; an object reference that is null while still holding an instance id means the asset it
pointed at was deleted:

```csharp
foreach (var guid in AssetDatabase.FindAssets("t:Prefab"))
{
    var path = AssetDatabase.GUIDToAssetPath(guid);
    var go = AssetDatabase.LoadAssetAtPath<GameObject>(path);
    foreach (var c in go.GetComponentsInChildren<Component>(true))
    {
        if (c == null) { Debug.LogError($"missing script: {path}"); continue; }
        var so = new SerializedObject(c);
        var p = so.GetIterator();
        while (p.NextVisible(true))
            if (p.propertyType == SerializedPropertyType.ObjectReference
                && p.objectReferenceValue == null
                && p.objectReferenceInstanceIDValue != 0)
                Debug.LogError($"broken reference: {path} :: {p.propertyPath}");
    }
}
```

`objectReferenceInstanceIDValue != 0` with a null value is the distinction that matters: it
separates "points at something deleted" from "deliberately empty".

## Rung 2 — does it start

Load the project's main scene, run it briefly, and check nothing threw. For most game projects
this is where most of the value of having tests actually lives.

**This rung is unproven and you must establish which mechanism works in this project before
relying on it.** Two candidates:

- **A single smoke test.** One `[UnityTest]` that loads the scene and yields a few frames, run
  with `unity test --mode PlayMode`. Reliable and it reuses the normal test path — but it needs
  `com.unity.test-framework`, and adding a package is a decision for the user, not for you.
- **An editor script that enters play mode** in batch, collects `Application.logMessageReceived`
  for a few seconds, then exits. No package needed, but driving play mode headlessly has
  historically been flaky and may simply not work on a given version.

Try one, confirm it actually runs and actually fails when something is broken, and record which
one works in the project's notes so nobody re-derives it. If neither works, say so and treat
rung 2 as unavailable rather than quietly skipping it.

## Rung 3 — does it build

```bash
unity build <project> --json
```

Slow — minutes — so run it per task, not per milestone. It catches a class nothing else does:
editor-only code reaching runtime, a missing platform dependency, a shader that compiles in the
editor and not for the target. A green build is the strongest automated statement available
without tests.

## Rung 4 — the human, and it blocks

When nothing above proves the feature behaves, a person has to look. That is not a shrug and not
a note in the PR — **the task is not done until they confirm it.**

Write the checklist as steps someone can follow without reading the diff:

```
Manual verification — needed, nothing above covers behaviour.

1. Open `Assets/Scenes/Main.unity` and press play.
2. Place a drill on a power node.
3. Confirm the drill starts, and the power readout drops by 5/s.
4. Confirm removing the node stops the drill within a second.

Expected: as above. If any step differs, that is a failure — say which step.
```

Rules:

- **Name the scene and the exact steps.** "Check the drill works" is not a checklist.
- **Say what counts as failure**, not only what counts as success.
- **One checklist per task**, written when the task is otherwise green — not accumulated and not
  deferred.
- A reported failure comes back as a fix round to the same worker, exactly like a review finding.

## Reporting the level

Every task reports what it reached, in one line, in the worker's handover, the draft PR and the
final report:

> compiles, imports clean, no new broken references, build green. No automated tests in this
> project — behaviour unverified. Manual checklist below, awaiting confirmation.

Never write "verified" or "tests pass" for a project that has no tests. State the rung, state
what is still unproven, and let the reader judge.
