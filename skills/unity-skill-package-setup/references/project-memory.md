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

<Which path this project is on, so nobody has to rediscover it:>

- **Unity CLI** — `unity` on `PATH`, or not installed. It resolves editors, licences and builds.
- **Editor 6.0+ with the Pipeline package** → C# runs against a *running* editor via
  `unity command eval`, with no recompile. Otherwise it is `-batchmode -executeMethod`, which
  needs the editor closed. `unity-scene-habits` has both paths; say here which one applies.
- **The user's editor while agents work** — on the connected path it is look-only while a task
  runs: no saving scenes or prefabs, no Play mode. Never change a scene or prefab on disk that
  the editor has open.
- **Tests** — whether this project has any at all. It decides how far verification can go and
  what a report is allowed to claim.
- **Packages settled at setup** — Pipeline and ProBuilder: installed, already there, or declined.
  A declined package is not offered again.

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
