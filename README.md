# unity-ai-skills

A Claude Code plugin for making games in Unity. It covers writing C# that fits the engine,
keeping the project layout sane as it grows, and the parts of the job that happen in the editor.

Unity projects break in ways a general coding assistant does not see coming. A scene is one
shared file that everybody edits, so two people working in the same one conflict every time. An
asset committed without its meta file silently breaks every reference to it. Most game projects
have no automated tests, so nothing catches either problem before merge day. These skills exist
to keep an agent from walking into all three.

## Install

```bash
claude plugin marketplace add Xenoneqq/unity-ai-skills
claude plugin install unity-ai-skills@unity-ai-skills
```

To install for a repo rather than for yourself, add `--scope project` to both commands. That
writes the marketplace and the enabled plugin into the project's `.claude/settings.json` and
copies nothing. Commit that file and everyone who clones the repo gets the plugin.

## Skills

Four cover the craft of working in Unity.

| Skill | What it does |
|---|---|
| `unity-scene-habits` | Prefab-first work through the editor CLI. Keeps the scene out of your diff. |
| `unity-coding-habits` | Everyday C# habits that hold in any project. |
| `unity-multiplayer-habits` | Multiplayer with Mirror, starting with which framework the project uses. |
| `unity-file-structure-habits` | Where a new file or asset belongs, and keeping the layout from drifting. |

Three run the work.

| Skill | What it does |
|---|---|
| `unity-skill-package-setup` | Wires a project up to these skills. Run it once. |
| `unity-manage-work` | Plans a backlog around scene conflicts and delegates it. Never pushes. |
| `unity-agent-worker` | Carries one task end to end, verifying as it goes. |

Three check and repair.

| Skill | What it does |
|---|---|
| `unity-review-change` | Reviews a diff, a branch or a PR. Read-only. |
| `unity-debug-runtime` | Works out why a running game is wrong when no test will tell you. |
| `unity-legacy-migration` | Moves old code onto current conventions without breaking references. |

## How they fit

Run `unity-skill-package-setup` once on a project. It writes a `CLAUDE.md` that routes each kind
of work to the right skill, so the rest fire on their own.

After that, reach for `unity-manage-work` when there is a list to get through and
`unity-agent-worker` for a single task. `unity-scene-habits` sits underneath both whenever the
engine is involved.

Three rules run through all of them. Prefer prefabs to scenes. Never hand-edit Unity's YAML or
meta files, because the editor is the only safe writer. Never claim a change is verified further
than it actually was.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) covers the layout, the validation gate, and the rules a skill
in here has to follow.

## Status

Early. Ten skills so far, and the existing ones will keep changing.
