# unity-ai-skills

Skills for game development in Unity. Covers mostly code writing, file structure planning,
in-engine work and more.

A Claude Code plugin for working inside a Unity project: writing C# that fits the engine rather
than fighting it, keeping the project layout sane as it grows, and handling the parts of the job
that live in the editor. It is built to stay out of your way — the skills follow the project's own
conventions where it has them, and leave anything outward-facing to you.

## Install

```bash
claude plugin marketplace add Xenoneqq/unity-ai-skills
```

```bash
claude plugin install unity-ai-skills@unity-ai-skills
```

### For a whole project

Add `--scope project` to both commands to install it for a repo rather than for yourself:

```bash
claude plugin marketplace add Xenoneqq/unity-ai-skills --scope project
```

```bash
claude plugin install unity-ai-skills@unity-ai-skills --scope project
```

That writes the marketplace and the enabled plugin into the project's `.claude/settings.json`
and copies nothing. Commit that file and everyone who clones the repo gets the plugin, updated
with `claude plugin update` like any other.

## Skills

| Skill | What it does |
|---|---|
| `unity-scene-habits` | Prefab-first habits, driven through the Unity CLI. Group anything groupable into a prefab, edit prefab assets instead of scenes, never break an asset reference, keep the scene out of the diff, and flag it when another branch already edits the same scene. Works against a running editor on Unity 6+, or batch mode on older projects. |
| `unity-manage-work` | Run a task or a backlog as a manager: settle the base branch, cut one branch, order the work from a scene-and-prefab conflict map, delegate to workers one at a time, route every editor run through one shared editor agent, and close with a report and a draft PR file per task. Never pushes. |
| `unity-agent-worker` | Carry one task end to end in the user's checkout: project rules first, milestones, engine work through `unity-scene-habits`, editor runs through the shared editor agent, the gate before every commit. Spawned by `unity-manage-work`, or used on its own. |

| `unity-skill-package-setup` | Wire a Unity project up to these skills: check the repo's `.gitignore` and scene merging, install the plugin at project scope, scan what the project already is, write a `CLAUDE.md` and `AGENTS.md` that route work to the right skill and offer `unity-manage-work` for every handed-over task, generate a `STRUCTURE.md`, and scaffold the standard asset folders. |
| `unity-file-structure-habits` | Decide where a new file or asset goes and keep the layout from drifting: `STRUCTURE.md` is the authority, the project's own conventions win, assets move only through the editor so references survive, and a new category is added deliberately rather than dumped in the nearest folder. |

Run `unity-skill-package-setup` once on a project. After that the usual path is
`unity-manage-work` when there is a list to get through, `unity-agent-worker` for a single task,
and `unity-scene-habits` underneath both whenever the engine is involved.

More are being written; the table fills in as they land.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) covers the layout, the validation gate, and the rules a skill in here has
to follow.

## Status

Early. Five skills so far; more coming, and existing ones will keep changing.
