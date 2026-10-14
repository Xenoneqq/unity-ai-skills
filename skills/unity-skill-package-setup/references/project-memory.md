# What the generated files say

Two files at the **repo root**: `CLAUDE.md` with the content, `AGENTS.md` pointing at it.

Write them for the project in front of you. The template below is a shape, not text to paste —
fill in the real editor version, the real paths, the real scene names, and drop any row whose
skill the project will not use.

## CLAUDE.md

````markdown
# <project name>

<One paragraph: what the game is, and anything a newcomer would get wrong.>

Unity <version>. The Unity project is at `<path>` — the repo root is one level above it.
Where things go is recorded in [STRUCTURE.md](STRUCTURE.md); read it before creating an asset.
How the game's systems fit together is in `Docs/GameStructure.md` once it exists; read it before
changing a system, and update it when you add a system, event, builder or scene.

## When the user hands over a task

Before starting any task of real size, **offer to run it through the `unity-manage-work`
skill** — it settles the base branch, orders the work around scene and prefab conflicts,
delegates to a worker, and writes a draft PR. Ask once, in one line. If the user declines, or
the task is a quick fix, do it directly and follow the rules below anyway.

## Which skill covers what

| Work | Skill |
|---|---|
| A scene, a prefab, an asset, or driving the editor | `unity-scene-habits` |
| Writing or changing C# under `Assets/`, tests included | `unity-coding-habits` |
| Anything networked | `unity-multiplayer-habits` |
| Designing or restyling a HUD, menu or any in-game screen | `unity-ui-design` |
| Designing, blocking out or dressing a level | `unity-level-design` |
| Generated textures, sprites or icons, or blurry pixel art | `unity-pixel-art` |
| Where a new file or asset belongs | `unity-file-structure-habits`, against [STRUCTURE.md](STRUCTURE.md) |
| A backlog, a list of tasks, anything worth delegating | `unity-manage-work` |
| One task carried end to end | `unity-agent-worker` |
| Reviewing a change, a branch or a PR | `unity-review-change` |
| The game runs wrong — crash, exception, stutter | `unity-debug-runtime` |
| Bringing old code onto current conventions | `unity-legacy-migration` |

Drop any row whose skill this project will not use, and add a row when a new one lands. A row
pointing at a skill nobody has installed sends the reader nowhere.

## Driving the editor

<How agents drive Unity here, so nobody has to rediscover it:>

- **Default: batch mode, editor closed.** No Unity window opens or takes focus. Builders:
  `unity run "<ROOT>" --timeout 900 --no-tail -l <log> -- -executeMethod Type.Method` (the CLI
  adds `-batchmode` and `-quit`). Tests: `unity test "<ROOT>" --mode EditMode|PlayMode --filter
  <name> --output <file>.xml`, or `batch-tests.sh`. A compile error shows as `error CS` in the
  log. <Without the Unity CLI: the raw editor binary with `-batchmode -executeMethod`.>
- **Connected, only when needed** <6.0+ with the Pipeline package>: `unity open`, the job through
  `unity command`, `unity close`. Never while the user is in the editor. A stalled editor:
  `editor-recover.sh` (`unity-scene-habits`).
- **The user tests in the editor.** When work is done, agents ask whether the user wants to test,
  open the project on the right branch, and send a short checklist. While the user has the editor
  open, agents do no Unity work; batch cannot run against the project lock.
- **Batch runs are muted** by `<path to BatchModeMute.cs>`, or <not installed>.
- **Tests** — whether this project has any at all. It decides how far verification can go and
  what a report is allowed to claim. Say whether a PlayMode test assembly exists or was declined.
- **Who drives Unity**: the agent doing the task, one agent at a time, unless this project wants
  a dedicated editor agent. This line overrides the skills' default.
- **Saving the open scene**: whether agents may save it through the editor. A test run's reload
  marks the scene dirty, and a dirty scene makes the run open a modal save dialog; without
  permission, agents stop and ask.
- **Packages settled at setup** — Pipeline and ProBuilder: installed, already there, or declined.
  A declined package is not offered again.

## How agents work here

Pointers only; the skills carry the procedure.

- **Files first.** C# and builder scripts are written as files, and Unity is used in one batch
  pass per task (`unity-agent-worker`). Compile check outside the editor: <the exact command
  once it is established, or "none, use a batch compile">.
- **Tests.** Isolated tests while working, one full run at the end, and list, isolate, test, fix
  when it breaks (`unity-agent-worker`).
- **One writer at a time.** Parallel writers in worktrees are speed mode, only on request
  (`unity-manage-work`).
- **Branches.** <one session branch per body of work, or stacked branches, one per task; leave
  it out and the manager asks at kickoff>. Agents never push or merge.

## Hard rules

- **Prefab first.** Anything groupable is a prefab. Scenes change only when nothing else will do.
- **Never hand-edit `.unity`, `.prefab` or `.meta`.** They are YAML full of ids and GUIDs; the
  editor is the only safe writer.
- **Every asset is committed with its `.meta`.** An asset without its meta gives everyone else a
  fresh GUID and silently breaks every reference to it.
- **Never move or rename an asset with `mv` or `git mv`** — use `AssetDatabase.MoveAsset`.
- **Generated assets come from committed builders** in `<builders folder>`. Change the builder
  and rerun it, never the output.
- **Never push, never open a PR** without being asked.

<Anything else true of this project: naming, assembly definitions, the render pipeline,
multiplayer constraints, which scenes are contested, the art style's import rules (filtering,
pixels per unit).>
````

## AGENTS.md

Some tools read `AGENTS.md` rather than `CLAUDE.md`. Point, do not duplicate — two copies of the
same rules drift within a month and the reader cannot tell which is current.

````markdown
# AGENTS.md

This project's instructions for coding agents live in [CLAUDE.md](CLAUDE.md). Read that file.

The short version: prefab-first, never hand-edit `.unity` / `.prefab` / `.meta`, commit every
asset together with its `.meta`, and check [STRUCTURE.md](STRUCTURE.md) before creating anything.
Work in files first, one writer at a time, and use Unity once per task, in batch mode with the
editor closed.
````

## Rules for writing them

- **Never overwrite a file someone wrote by hand.** Read it first. If it already has content,
  show the user the sections you would add and let them choose.
- **Keep it short.** This file is loaded into every session in the project. Long house rules are
  paid for on every single message; anything that only matters sometimes belongs in a skill or in
  `STRUCTURE.md`.
- **Do not restate the skills.** The routing table says which skill to use; the skill itself
  carries the procedure. Copying the procedure into `CLAUDE.md` doubles the cost and goes stale.
- **Only list skills that exist.** A routing row pointing at a skill nobody has installed sends
  the reader nowhere. Add rows as skills land.
- Say the editor version explicitly. It decides whether other skills can drive a running editor
  or must use batch mode.
