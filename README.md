# Unity AI Skills

A Claude Code plugin for making games in Unity. It covers writing C# that fits the engine, keeping the project layout sane as it grows, the parts of the job that happen in the editor, and designing the UI, levels and art.

Unity projects break in ways a general coding assistant does not see coming. A scene is one shared file that everybody edits, so two people working in the same one conflict every time. An asset committed without its meta file silently breaks every reference to it. Most game projects have no automated tests, so nothing catches either problem before merge day. These skills exist to keep an agent from walking into all three.

## Install

```bash
claude plugin marketplace add Xenoneqq/unity-ai-skills
claude plugin install unity-ai-skills@unity-ai-skills
```

To install for a repo rather than for yourself, add `--scope project` to both commands. That writes the marketplace and the enabled plugin into the project's `.claude/settings.json` and copies nothing. Commit that file and everyone who clones the repo gets the plugin.

### The experimental branch

`main` is the stable version and the default. Changes are tried on the `experimental` branch first, on real projects, before they reach `main`. To follow it, add the marketplace at that branch instead:

```bash
claude plugin marketplace add Xenoneqq/unity-ai-skills#experimental
claude plugin install unity-ai-skills@unity-ai-skills
```

To switch between the two, remove the marketplace and add it again at the other branch, then reinstall. Removing a marketplace uninstalls its plugins, which is why the install runs again. Start a new session afterwards.

```bash
claude plugin marketplace remove unity-ai-skills
```

`unity-skill-package-setup` asks which branch a project should follow and can do the switch for you.

## Skills

These cover the craft of working in Unity.

| Skill                         | What it does                                                                |
| ----------------------------- | --------------------------------------------------------------------------- |
| `unity-scene-habits`          | Prefab-first work through the editor CLI. Keeps the scene out of your diff. |
| `unity-coding-habits`         | Everyday C# habits that hold in any project, tests included.                |
| `unity-multiplayer-habits`    | Multiplayer with Mirror. Asks the framework and who owns movement first.    |
| `unity-file-structure-habits` | Where a new file or asset belongs, and keeping the layout from drifting.    |
| `unity-ui-design`             | Game UI that fits this game, mocked up in HTML before it is built.          |
| `unity-level-design`          | Levels at the player's real scale, proven playable, dressed off the grid.   |
| `unity-pixel-art`             | Pixel-art textures, sprites and icons generated from code, kept sharp.      |

These run the work.

| Skill                       | What it does                                                             |
| --------------------------- | ------------------------------------------------------------------------ |
| `unity-skill-package-setup` | Wires a project up to these skills and the editor packages. Run it once. |
| `unity-manage-work`         | Plans a backlog around scene conflicts and delegates it. Never pushes.   |
| `unity-agent-worker`        | Carries one task end to end, verifying as it goes.                       |

These check and repair.

| Skill                    | What it does                                                         |
| ------------------------ | -------------------------------------------------------------------- |
| `unity-review-change`    | Reviews a diff, a branch or a PR. Read-only.                         |
| `unity-debug-runtime`    | Works out why a running game is wrong when no test will tell you.    |
| `unity-legacy-migration` | Moves old code onto current conventions without breaking references. |

## How they fit

Run `unity-skill-package-setup` once on a project. It writes a `CLAUDE.md` that routes each kind of work to the right skill, so the rest fire on their own.

After that, reach for `unity-manage-work` when there is a list to get through and `unity-agent-worker` for a single task. `unity-scene-habits` sits underneath both whenever the engine is involved. Work runs one writer at a time in your own checkout, written as files first with one Unity pass per task, and small edits skip most of the process. Parallel writers are an opt-in speed mode.

Agents run Unity in batch mode by default, with the editor closed. Builders and tests run headless, so no window opens, nothing steals your focus, and a locked screen should not stall the work (not yet verified; a sleeping machine stops everything, so keep it awake). The editor is yours: agents open it only for the few jobs that need a live one and close it again, and when work is done they ask whether you want to test, open the project on the right branch and tell you what to try. While you have it open they leave Unity alone and keep doing everything else.

You choose how much the manager does on its own, and can change it mid-session in plain words. Full automatic opens and closes the editor itself and saves every sign-off for the end. Semi automatic, the default, works without stopping but asks before anything that takes over your machine, without waiting on the answer. Human assisted also brings you the real decisions, a few at a time. Whenever it needs you, it says so in the conversation and on your phone, up to three times, 15 minutes apart, and then carries on with what it can.

The same rules run through all of them. Prefer prefabs to scenes. Never hand-edit Unity's YAML or meta files, because the editor is the only safe writer. Never claim a change is verified further than it actually was.

## License

MIT, see [LICENSE](LICENSE).
