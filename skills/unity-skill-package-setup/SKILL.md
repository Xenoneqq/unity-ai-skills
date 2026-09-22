---
name: unity-skill-package-setup
description: >
  Wire a Unity project up to these skills: install the plugin at project scope, write a CLAUDE.md
  and AGENTS.md that route each kind of work to the right skill and make every handed-over task
  offer to run through `unity-manage-work`, check the repo's .gitignore and scene merge setup,
  scan what is already there, generate a STRUCTURE.md describing the real project layout, and
  scaffold the standard asset folders. Use when: "/unity-skill-package-setup", "set this
  project up for Claude", "link these skills to my Unity project", "add a CLAUDE.md for this
  Unity project", "scaffold the asset folders", or opening a Unity project that has no CLAUDE.md.
---

# Unity skill package setup

Run once per project. Everything it writes lives in the user's Unity repo, so **nothing here
happens without asking** — you are creating tracked files and a folder layout the whole team
inherits.

Safe to re-run: every step checks what is already there and adds only what is missing.

| File | Read it when |
|---|---|
| `references/git-hygiene.md` | Checking `.gitignore` and scene merging (Step 3). |
| `references/folder-scaffold.md` | Creating the asset folders (Step 5). |
| `references/first-run-scan.md` | Reading what the project already is (Step 6). |
| `references/project-memory.md` | Writing `CLAUDE.md` and `AGENTS.md` (Step 8). |

## 1. Find the project and see what already exists

```bash
PV=$(find . -path '*/ProjectSettings/ProjectVersion.txt' -not -path '*/Library/*' -print -quit)
ROOT=$(dirname "$(dirname "$PV")")           # the Unity project
REPO=$(git rev-parse --show-toplevel)        # the repo — often one level up
echo "unity project: $ROOT"
echo "repo root    : $REPO"
ls "$REPO/CLAUDE.md" "$REPO/AGENTS.md" "$REPO/STRUCTURE.md" "$REPO/.claude/settings.json" 2>/dev/null
ls -d "$ROOT/Assets"/*/ 2>/dev/null
```

`CLAUDE.md`, `AGENTS.md` and `STRUCTURE.md` go at the **repo root**, not the Unity project root,
because that is where Claude Code reads them. They often differ — a Unity project frequently sits
one directory down.

**If any of those files already exist, read them before writing anything.** Never overwrite a
file someone wrote by hand. Show the user what you would add and let them choose: merge the new
sections in, or leave it alone.

## 2. Preflight the project

Check, report, and let the user decide. Do not fix these silently — each one rewrites or
reconfigures their project:

- **Serialization mode.** `m_SerializationMode: 2` in `ProjectSettings/EditorSettings.asset`.
  Anything else and scenes and prefabs are unmergeable binary. This is the single most valuable
  thing to fix at setup time — but flipping it re-serializes every asset in the project, so it is
  the user's call and it wants its own commit.
- **Editor version**, from `ProjectVersion.txt`. It decides which path the other skills use:
  6.0+ can drive a running editor, older is batch mode only.
- **Render pipeline** — Built-in, URP or HDRP. It changes what a material or a shader asset
  fundamentally is, so it belongs in the generated `CLAUDE.md`. Read the graphics settings and
  the package manifest.
- **Assembly definitions.** Count the `.asmdef` files. None means every script change recompiles
  the whole project, which is the difference between a two-second and a forty-second edit loop
  and taxes every batch run and every worker. Report it — adding them restructures compilation
  and is a task of its own, not a setup step.

Report all of it in one message rather than asking four times.

## 3. Git hygiene

Read `references/git-hygiene.md`. Two things decide whether this repo is workable at all.

**`.gitignore`** — check what git actually does, with `git check-ignore`, not what the file says.
`Library/`, `Temp/`, `Obj/`, `Logs/`, `Build/`, `MemoryCaptures/` and `UserSettings/` must be
ignored; every asset and **every `.meta` under `Assets/`, at any depth** must be tracked.

An ignored `.meta` is the highest-priority finding this skill can produce: assets arrive without
their GUIDs on a fresh clone and every reference to them silently breaks. Say so plainly and
before anything else.

Show additions to an existing `.gitignore`; never replace one. Offer Unity's standard template
only when the file is missing entirely.

**Scene merging** — offer to wire up Unity's YAML-aware merge tool via `.gitattributes`. Ask
first: it adds a tracked file and changes git config. Note that the `.gitattributes` half is
shared but the `git config` half is per-clone, so each teammate runs it themselves.

## 4. Install the plugin at project scope

Ask first — it writes `.claude/settings.json`, a tracked file everyone who clones inherits.

```bash
claude plugin marketplace add Xenoneqq/unity-ai-skills --scope project
claude plugin install unity-ai-skills@unity-ai-skills --scope project
```

That commits the marketplace and the enabled plugin to the repo and copies nothing, so the whole
team gets the skills and `claude plugin update` keeps them current. Say that the resulting
`.claude/settings.json` should be committed.

If the user would rather keep it personal, drop `--scope project` — then the skills are theirs
alone and the generated `CLAUDE.md` still documents the routing for everyone else.

## 5. Scaffold the asset folders

Read `references/folder-scaffold.md` for the default tree, what each folder is for, and the
mechanics. The two that matter:

- **Create only what is missing.** Never move or rename an existing folder here — that breaks
  references. Restructuring an existing project is a task in its own right, not a setup step.
- **Empty folders do not survive git.** Mark each one with a `.gitkeep`. Files and folders
  starting with `.` are ignored by Unity's importer, so a `.gitkeep` needs no `.meta` and never
  appears in the project window — which makes it the only scaffold marker that does not create
  asset churn.

Show the user the tree you propose before creating any of it. A project with its own established
layout keeps its own layout; adopt their names rather than imposing these.

## 6. Scan what is already there

Read `references/first-run-scan.md` and run it before writing `STRUCTURE.md`. A project adopting
these skills has years of decisions in it; the scan reads them so the generated files describe
the project rather than an ideal.

It is **read-only** — it changes nothing. Run the independent lookups as parallel read-only
agents, and exclude third-party folders first or imported packages will dominate every ranking.

It produces three things: findings ordered by what hurts soonest, a backlog the user can hand
straight to `unity-manage-work`, and the folder list `STRUCTURE.md` has to cover.

## 7. Write STRUCTURE.md

The structure file is the project's record of where things go, the thing `CLAUDE.md` points at
when deciding where a new asset belongs, and the file `unity-file-structure-habits` checks the
tree against. Generate it from the scan in Step 6 and what is actually on disk — never from the
template — so it describes the project, including the folders that do not fit the scaffold.

**Keep the folder list as a table, one row per folder, path first.** That is the contract: it
stays readable for a person and parseable for a drift check. Prose paragraphs describing the
layout cannot be checked against anything.

| Path | What belongs there |
|---|---|
| `Assets/Prefabs/` | Prefab assets, grouped by kind |
| `Assets/Scripts/<Feature>/` | Runtime C# for one feature |

Around the table: where scenes live and which are contested, the assembly definitions and what
each covers, and the third-party folders that are off-limits.

Say in the file that it is expected to grow, that new categories are added as the project gains
them rather than invented up front, and that a folder missing from the table is a gap in the
table rather than a misplaced folder.

## 8. Write CLAUDE.md and AGENTS.md

Read `references/project-memory.md` for the content. In short, the generated `CLAUDE.md` carries:

- A one-paragraph description of the project, the editor version, and the path to the Unity
  project if it is not the repo root.
- **The routing table** — which skill covers which kind of work, so the right one fires without
  the user naming it.
- **The task rule**: when the user hands over a task, offer to run it through
  `unity-manage-work` before starting, and only proceed directly if they decline.
- The project's own hard rules: prefab-first, never hand-edit `.unity`/`.prefab`/`.meta`, every
  asset committed with its meta, and a pointer to `STRUCTURE.md` for where things go.

`AGENTS.md` covers the same ground for tools that read that filename instead. Write it as a short
file that points at `CLAUDE.md` rather than duplicating it — two copies of the same rules drift.

## 9. Verify and report

```bash
ls "$REPO/CLAUDE.md" "$REPO/AGENTS.md" "$REPO/STRUCTURE.md"
git -C "$REPO" status --short
```

Then tell the user, in this order:

1. **Anything broken that they must decide on**, first: an ignored `.meta`, serialization not
   set to Force Text, `UserSettings/` committed, a missing editor version, no licence.
2. What you created, and what you left alone because it already existed.
3. **The backlog from the scan** — the real work the project needs, ordered, and the offer to run
   it through `unity-manage-work`.
4. That nothing is committed. Suggest it as its own commit — setup is not a feature change and
   should not ride along with one.

Never commit and never push from this skill.
