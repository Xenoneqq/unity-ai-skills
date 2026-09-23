# Where the evidence is written down

Paths here were read from Unity's own log-file reference for 2022.3, 6000.0 and 6000.5, and
cross-checked against the files a real editor install writes. **They differ by version.** Check
before quoting one at a user.

## The editor log moved in Unity 6

| Project editor | Default editor log |
|---|---|
| 2022 LTS, 6000.0 | The global per-user file (table below) |
| 6000.5 | `<Project>/Logs/Editor.log`, per project |

On 6000.5 the global file is opt-in: the **Use Global Editor Log** preference, or the
`-useGlobalLog` command-line argument, which the editor announces in the log as "Command line
argument '-useGlobalLog' was supplied, skipping project log." On any version `-logFile <path>`
overrides everything.

Do not decide from the version number alone — a project can be configured either way. List both
candidates by modification time and take the one that is live:

```bash
ls -lt "$ROOT/Logs/Editor.log" ~/Library/Logs/Unity/Editor.log 2>/dev/null
```

From inside a running editor or player, `Application.consoleLogPath` gives the answer directly,
with no platform branching. Not every platform supports it. In the editor, the Console's More
(⋮) menu has **Open Editor Log** and **Open Player Log**, which is faster than any of this when
a human is at the keyboard.

### Global editor log, and its neighbours

| Platform | Editor log | Licensing client |
|---|---|---|
| macOS | `~/Library/Logs/Unity/Editor.log` | `~/Library/Logs/Unity/Unity.Licensing.Client.log` |
| Windows | `%LOCALAPPDATA%\Unity\Editor\Editor.log` | `%LOCALAPPDATA%\Unity\Unity.Licensing.Client.log` |
| Linux | `~/.config/unity3d/Editor.log` | `~/.config/unity3d/Unity/Unity.Licensing.Client.log` |

Package Manager logs default to `<Project>/Logs/upm.log`, falling back to the global directory
above when no project path resolves. `-upmLogFile <path>` overrides that and beats everything
else. Editor crash files on Windows go to `%TMP%\Unity\Editor\Crashes`, relocatable with
`-crash-report-folder`.

**`unity logs` is the Hub's log, not the editor's.** It reads
`~/Library/Application Support/UnityHub/logs/info-log.json` and its per-platform equivalents.
Useful for install and licensing problems, useless for a runtime bug. Do not reach for it
expecting `Editor.log`.

## The player log

`CompanyName` and `ProductName` are whatever Player Settings says, spaces and all — on macOS the
directory really is spaced. Read them from `ProjectSettings/ProjectSettings.asset` rather than
guessing at the studio's own spelling.

| Platform | Player log |
|---|---|
| Windows | `%USERPROFILE%\AppData\LocalLow\CompanyName\ProductName\Player.log` |
| macOS | `~/Library/Logs/Company Name/Product Name/Player.log` |
| Linux | `~/.config/unity3d/CompanyName/ProductName/Player.log` |
| UWP | `%USERPROFILE%\AppData\Local\Packages\<productname>\TempState\UnityPlayer.log` |
| Android | `adb logcat`, or the Android Logcat package — `Window > Analysis > Android Logcat` |
| iOS | The device console through Xcode |
| Web | The browser's JavaScript console |

Player crash files: Windows only, at the path `CrashReporting.crashReportFolder` reports
(`%TMP%\CompanyName\ProductName\Crashes`). On other platforms use the OS's own crash reporting —
`~/Library/Logs/DiagnosticReports` on macOS, `adb bugreport` on Android.

## Player command-line arguments worth knowing

| Argument | Effect |
|---|---|
| `-logFile <path>` | Write the player log where you say. Quote paths with spaces. |
| `-nolog` | No player logging at all. |
| `-timestamps` | Prefix every message with a timestamp and thread id. |
| `-log-memory-performance-stats` | Append a memory report when the player closes. |

`-timestamps` is the one people forget and then want. A log with no clock cannot answer "did this
happen before or after the load", which is most of what an intermittent bug turns on.

The profiler arguments (`-profiler-enable`, `-profiler-log-file`, `-deepprofiling`) are in
[profiling.md](profiling.md), because they only do anything in a development build.

## Reading an editor log without drowning in it

The editor log is mostly import, shader and package noise. Cut to what matters:

```bash
grep -nE 'Exception|error CS|^  at |Fallback handler|is missing|Crash' "$LOG" | head -60
```

Three things to know about the file:

- **It is per editor session, not per play session.** A run you did an hour ago is still in
  there. Find the last `Entering Play Mode`-style boundary, or stamp your own marker with a
  `Debug.Log` at startup, before reading upward.
- **`Editor-prev.log` is the previous session**, which is where the evidence lives when the
  editor crashed and restarted.
- **Compile errors and runtime exceptions look alike in a grep.** `error CS…` means the project
  did not build, so nothing ran — a different bug from the one you were sent to find, and worth
  saying so rather than fixing past it.
