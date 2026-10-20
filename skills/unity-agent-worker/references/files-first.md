# Files first, one Unity pass

Unity is the slowest tool a worker has. A batch call costs about 10 s with a warm `Library/`, an
open editor pays 30-90 s per recompile, domain reload and Play mode entry, and an editor stuck
behind a dialog or a locked screen costs the whole session. Most of a task needs none of it:
write the task as files, then use Unity once.

## Everything is a file first

- **C#** is written as files.
- **Scene, prefab and asset changes** are written as builder scripts, per `unity-scene-habits`'
  `references/builders.md`, not clicked together in the editor. The builder runs in the Unity
  pass. Hand-editing `.unity`, `.prefab` or `.meta` YAML stays forbidden.
- **`.meta` files are never hand-written.** The Unity pass creates them for new assets, so you
  commit after the Unity pass, never before, and the meta-pairing check stays in the gate.

## A compile check outside the editor

Unity generates a `.csproj` per assembly, and the IDE package regenerates them. They reference
the DLLs in the project's warm `Library/`, so where it works, `dotnet build` against the generated
solution or one project compiles the code in seconds, with no domain reload:

```bash
dotnet build <Project>.sln
```

- **It is unproven per project.** Establish once whether it works, record the exact command in
  the project's notes, and fall back to a batch compile if it does not. Older generated
  projects may need `msbuild` rather than `dotnet`.
- **Regenerate the project files** when an assembly definition or a package changes. A new `.cs`
  file may be missing from an old `.csproj`, and the build then misses its errors.
- **It can differ from Unity's own compile**, in defines and analyzers, so the editor compile in
  the Unity pass stays the real gate. Any batch run is that compile: an `error CS` in its log
  means the code does not compile.

A speed-mode worktree (`unity-manage-work`) has no `Library/` and no generated project files.
Copying the main checkout's project files and pointing the worktree's `Library` at the main
checkout's is how the check can still run there; that is unproven too, so establish it once.

## Logic tests outside the editor, optional

Pure logic, such as rules, state, inventory or damage math, in an assembly definition with
`noEngineReferences` can run with `dotnet test` in seconds. It is a pattern a project can adopt,
not a requirement; `unity-coding-habits`' `references/testing.md` has the shape.

## One Unity pass per task

Use Unity only for:

- running builders,
- runtime and PlayMode tests, screenshot tests included,
- the final compile gate.

Batch them into one pass at the end of the task, or of a batch of small tasks, in batch mode with
the editor closed (`unity-scene-habits`, `references/batch-mode.md`):

```bash
unity run "$ROOT" --timeout 900 --no-tail -l "$LOG" -- -executeMethod Builders.All.Build
batch-tests.sh --mode EditMode InventoryTests DoorTests   # filtered, one call per name
batch-tests.sh --mode PlayMode DoorFlowTests
batch-tests.sh --mode EditMode; batch-tests.sh --mode PlayMode    # the full run, at the end
```

`batch-tests.sh` is `unity-scene-habits`' `references/batch-tests.sh`, or the copy your brief
names. No window opens and nothing needs focus. Then run the rung-0 checks and commit. The
connected runner (`unity-scene-habits`' `references/run-tests.sh`) is for when the brief chose a
live editor.

## Where files first gives nothing

Feel tasks, such as how movement or a weapon feels, are judged by playing. Files first saves them
nothing; the user plays them in the editor (`unity-manage-work`, "ask to test"). Looks, such as
lighting, UI layout or level dressing, are judged from screenshot tests, which render in batch
mode too. Open a live editor only when the job needs one, still one agent on it at a time.
