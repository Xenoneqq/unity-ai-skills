# Files first, one editor pass

The editor is the slowest tool a worker has. Every recompile, domain reload and Play mode entry
costs 30-90 s, and an editor stuck behind a dialog costs the whole session. Most of a task needs
none of it: write the task as files, then use the editor once.

## Everything is a file first

- **C#** is written as files.
- **Scene, prefab and asset changes** are written as builder scripts, per `unity-scene-habits`'
  `references/builders.md`, not clicked together in the editor. The builder runs in the editor
  pass. Hand-editing `.unity`, `.prefab` or `.meta` YAML stays forbidden.
- **`.meta` files are never hand-written.** The editor pass creates them for new assets, so you
  commit after the editor pass, never before, and the meta-pairing check stays in the gate.

## A compile check outside the editor

Unity generates a `.csproj` per assembly, and the IDE package regenerates them. They reference
the DLLs in the project's warm `Library/`, so where it works, `dotnet build` against the generated
solution or one project compiles the code in seconds, with no domain reload:

```bash
dotnet build <Project>.sln
```

- **It is unproven per project.** Establish once whether it works, record the exact command in
  the project's notes, and fall back to the editor recompile if it does not. Older generated
  projects may need `msbuild` rather than `dotnet`.
- **Regenerate the project files** when an assembly definition or a package changes. A new `.cs`
  file may be missing from an old `.csproj`, and the build then misses its errors.
- **It can differ from Unity's own compile**, in defines and analyzers, so the editor compile in
  the editor pass stays the real gate.

A speed-mode worktree (`unity-manage-work`) has no `Library/` and no generated project files.
Copying the main checkout's project files and pointing the worktree's `Library` at the main
checkout's is how the check can still run there; that is unproven too, so establish it once.

## Logic tests outside the editor, optional

Pure logic, such as rules, state, inventory or damage math, in an assembly definition with
`noEngineReferences` can run with `dotnet test` in seconds. It is a pattern a project can adopt,
not a requirement; `unity-coding-habits`' `references/testing.md` has the shape.

## One editor pass per task

Use the editor only for:

- running builders,
- runtime and PlayMode tests,
- visual work: the look, lighting, UI, level dressing, feel,
- the final compile gate.

Batch them into one pass at the end of the task, or of a batch of small tasks, with tests through
the test script (`unity-scene-habits`, `references/run-tests.sh`). Then run the rung-0 checks and
commit.

## Where files first gives nothing

Visual and feel tasks, such as lighting, UI layout, level dressing or how movement feels, are
judged in the editor. Files first saves them nothing: work them in the editor from the start,
still one agent on it at a time.
