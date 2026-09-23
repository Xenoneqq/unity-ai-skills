# Driving the editor from the command line

## Finding an editor

Hub keeps installs under a per-version directory; the binary inside differs per platform. To
list what is actually installed rather than guessing:

```bash
# macOS
"/Applications/Unity Hub.app/Contents/MacOS/Unity Hub" -- --headless editors -i
# Windows
"C:\Program Files\Unity Hub\Unity Hub.exe" -- --headless editors -i
# Linux
unityhub --headless editors -i
```

Match `m_EditorVersion` from `ProjectSettings/ProjectVersion.txt` exactly, including the suffix
(`f1`, `f3`). Opening a project with a newer editor **upgrades the project** and cannot be
undone; a missing version is a question for the user, never a substitution.

## The flags that matter

| Flag | Why |
|---|---|
| `-batchmode` | No UI, no interaction. Required for everything here. |
| `-quit` | Exit when the method returns. Omit it and the editor sits there forever. |
| `-projectPath <dir>` | The directory containing `Assets/` and `ProjectSettings/`. |
| `-executeMethod <Class.Method>` | The static method to run. |
| `-logFile -` | Log to stdout. Without it the log goes to a platform-specific file. |
| `-nographics` | No GPU, faster start, works headless. Drop it only when the task renders. |
| `-accept-apiupdate` | Lets the API updater rewrite source. Not a default — see below. |
| `-disable-assembly-updater` | The opposite: fail fast instead of rewriting assemblies. |
| `-silent-crashes` | Suppresses the crash dialog on a headless box. |

`-nographics` does not suppress logging, whatever a given doc revision says: a run with the flag
and a run without it produce identical log output, to a file and to stdout alike. Use it freely
for asset work.

`-accept-apiupdate` is the one flag to leave off by default. It permits the API updater to
rewrite source across the project on load. That is occasionally what you want and never what you
want in the middle of a small prefab change, where it turns a two-line diff into a thousand-line
one. If a run fails because the project needs updating, surface that to the user as a decision
rather than adding the flag to get past the error.

## Licensing

Batch mode requires an activated license and will not prompt for one. Without it the run emits
about thirty lines of licensing output, ends in `No valid Unity Editor license found. Please
activate your license.`, and exits 1 having done nothing — the `-executeMethod` never runs. The
preceding `[Licensing::Client] Error: Code 500 … No ULF license found` lines are the tell.

The licence lives in one of:

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/Unity/licenses/` or `/Library/Application Support/Unity/Unity_lic.ulf` |
| Windows | `C:\ProgramData\Unity\Unity_lic.ulf` |
| Linux | `~/.local/share/unity3d/Unity/Unity_lic.ulf` |

Fixing it means signing in through Unity Hub, which only the user can do. Ask them to sign in
and say that batch mode is blocked until they have. Do not attempt to activate a licence from
the command line and do not handle their credentials.

## The project lock

Only one editor instance can hold a project. If a run fails with a lock or "project is already
open" error, an editor has it — including one the user forgot about, and including a clone tool
that opened a linked copy. Ask; do not kill their editor.

## The task script

`-executeMethod` only finds static methods in an assembly compiled for the editor, which in
practice means a file under a folder named `Editor`. Keep it in one fixed place and leave it
there between runs.

```csharp
// Assets/Editor/CliTasks/CliTask.cs
using UnityEditor;
using UnityEngine;

public static class CliTask
{
    public static void Run()
    {
        try
        {
            // work goes here
            AssetDatabase.SaveAssets();
            EditorApplication.Exit(0);
        }
        catch (System.Exception e)
        {
            Debug.LogError($"CliTask failed: {e}");
            EditorApplication.Exit(1);
        }
    }
}
```

Always exit explicitly. An uncaught exception exits 1, but a method that just returns leaves the
exit code to `-quit`, which reports success even after logged errors.

To pass arguments, read `System.Environment.GetCommandLineArgs()` and put your own flags after
the Unity ones.

Do not create and delete the script around each run. Adding an editor script triggers a full
script recompile and removing it triggers another, so a create-run-delete cycle pays for two
recompiles on every task — on a large project, minutes of pure waste each way.

Keep it out of the user's diff with `.gitignore` instead, once:

```
Assets/Editor/CliTasks/
Assets/Editor/CliTasks.meta
```

Ignore the folder's own `.meta` alongside it, or git offers you a meta for an ignored directory.
If the project already has an editor-tools folder of its own, put the task there and follow its
naming.

## Reading the run

Piping `-logFile -` through `tail -40` is enough for a passing run. For a failure, keep the whole
log and search it:

```bash
"$UNITY" -batchmode -quit -nographics -projectPath "$ROOT" \
  -executeMethod CliTask.Run -logFile - > /tmp/unity.log 2>&1; echo "exit $?"
grep -nE 'error CS|Exception|Failed|Aborting' /tmp/unity.log | head -30
```

`error CS….` means the project does not compile — the task never ran, and the compile error may
be someone else's, not yours. Fix or report that before retrying.

## When a run takes forever

The first batch-mode run against a cold or invalidated `Library/` reimports every asset. On a
large project that is minutes to tens of minutes, and it looks identical to a hang. Let it
finish once; later runs are fast. Deleting `Library/` guarantees paying that cost again, which
is why step 3 of the skill forbids it as a fix.

A run that produces no log output at all for a long stretch, on a warm project, is a real hang —
usually a dialog the editor is waiting on. `-batchmode` suppresses most, but not all.

## Running tests

Same binary, different verb. Do not combine it with `-executeMethod`.

```bash
"$UNITY" -batchmode -runTests -projectPath "$ROOT" \
  -testPlatform EditMode -testResults /tmp/results.xml -logFile -
```

`-testPlatform` takes `EditMode`, `PlayMode`, or a build target name. `-testFilter`,
`-testCategory` and `-assemblyNames` all take semicolon-separated lists. Results are NUnit XML;
read the `<test-run>` attributes for the totals rather than scrolling the log. PlayMode tests
render, so drop `-nographics` for those.
