# Driving a running editor

This is the fast path. It needs the Unity CLI, an editor **6.0 or newer**, that editor running
with the project open, and the Pipeline package installed. When any of those is missing, use
[batch-mode.md](batch-mode.md) instead.

Everything here was checked against Unity CLI `1.0.0-beta.10`. It is beta software and the
Pipeline package is pre-1.0 (`0.3.x-exp`), so treat command surfaces as liable to shift, and
check `unity <group> --help` rather than trusting a remembered flag.

## Is the path available?

```bash
command -v unity                                  # the CLI itself
unity editors -i --verbose --json --no-banner     # installed editors, with locations
unity pipeline list --json --no-banner            # editors running, and their Pipeline status
```

`unity editors -i --verbose` reports a `location` per editor, so there is no need to guess at
platform-specific install paths. Plain `unity editors` mixes installed editors with available
downloads — pass `-i`.

Pipeline requires editor **6.0+**. A 2021 or 2022 LTS project cannot use this path at all, no
matter what is installed; that is a hard version floor, not a preference.

## Installing the package

`unity pipeline install` adds `com.unity.pipeline` to the project, which changes the project's
package manifest — a tracked file that lands in someone's diff. **Ask before running it.** It is
a project-wide dependency decision, not an implementation detail of your task.

```bash
unity pipeline install                      # current project
unity pipeline install --project-path DIR
unity pipeline list-versions
```

The package stands up a local HTTP server on port 7800 that the CLI talks to.

## Running code

Arbitrary C# against the live editor, with no domain reload and no script file:

```bash
unity command eval "return Application.version;"
unity command eval "return UnityEditor.EditorApplication.isPlaying;"
unity command eval_file path/to/script.cs --json
```

This is the whole reason to prefer this path. Batch mode pays an editor boot and a script
recompile for every single change; `eval` answers in milliseconds against the project already
loaded. For an iterative task — inspect a prefab, change it, check the result — the difference
is minutes against seconds.

For something you will run more than once, register it instead of re-pasting it. Any static
method with the attribute becomes a command, with no separate registration step:

```csharp
[CliCommand("prefab-mass", "Set rigidbody mass on a prefab")]
public static float PrefabMass(
    [CliArg("path", "Prefab asset path", Required = true)] string path,
    [CliArg("mass", "New mass")] float mass)
{
    using var scope = new PrefabUtility.EditPrefabContentsScope(path);
    var rb = scope.prefabContentsRoot.GetComponent<Rigidbody>();
    rb.mass = mass;
    return rb.mass;
}
```

```bash
unity command prefab-mass --path Assets/Prefabs/Crate.prefab --mass 12
unity command --query prefab          # find registered commands by substring
unity command --tag assets --detail compact
```

Useful flags on `unity command`: `--project-path` when several projects are open,
`--timeout <seconds>` (default 30) for slow work, `--result-only` for just the JSON result
without the envelope, and `--detach` to submit a long job and get an id back immediately —
`unity job` then manages it.

Pass `--skill unity-scene-habits` on invocations made by this skill. It is an analytics label
the CLI provides for exactly this, and it costs nothing.

## Reading results

Every command takes `--json` (or `--format tsv|ndjson|github`). Prefer it over parsing the human
output.

**Do not judge success by exit code alone, and do not judge it by `success` alone.** Some
commands report `"success": true` with an empty `data` and exit 0 when the answer is "nothing
found" — `unity license` does exactly that on a machine with no licence. Check the payload:

```bash
unity license --json --no-banner | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))"
```

`0` means no licence, whatever the exit code said.

Exit codes that do mean something: `unity command` exits **6** when no editor with a reachable
Pipeline server is found, with a message listing the three preconditions. If you see that, the
editor is closed, the package is missing, or the HTTP server is down — check
`unity pipeline list` before retrying.

Mind shell pipelines when reading exit codes: `unity command ... | head` reports `head`'s status,
not Unity's. Capture the status before piping.

## Other commands worth knowing

| Command | Use |
|---|---|
| `unity test --mode EditMode --output r.xml` | Run tests. Also `--filter`, `--retries`, `--rerun-failed`, `--affected`, `--shard N/M`. |
| `unity build [project]` | Build; spawns the editor in batch mode and forwards CI flags. |
| `unity open` / `unity close <project>` | Open a project with the right editor, or close the one holding it. `close` exits **without saving**. |
| `unity doctor` | Diagnose a broken environment. |
| `unity commands --json` | Machine-readable manifest of the whole CLI surface, when a flag is in doubt. |

`unity close` discarding unsaved work makes it a destructive command against a colleague's open
editor. Never run it to clear a lock without asking first.
