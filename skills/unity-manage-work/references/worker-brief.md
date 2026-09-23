# The worker brief

Read this before spawning any worker. Every worker prompt is built from it.

Agent tool, `subagent_type: "general-purpose"`, model from Step 4, and **no `isolation`** — the
worker works in the user's own checkout on the branch you already cut. There is no worktree and
no second copy, which is why only one writer runs at a time.

## Open with the skill

Tell it to invoke `unity-agent-worker` and follow it for the whole task. That skill already
carries the process: project rules first, milestones, engine work through `unity-scene-habits`,
editor runs through the editor agent, the gate before every commit, never push. Your prompt
supplies what it cannot know and pre-answers what it would otherwise stop on.

## What every prompt must contain

- **Repo path**, **the branch it is on** (already created — it does not cut one), and "read the
  project's CLAUDE.md / AGENTS.md / contributor notes and follow them exactly; they outrank every
  skill."
- The **task in full**, plus **every locked decision verbatim**.
- The **anchor files to mirror** — paths, and what each one demonstrates. A worker prompt is only
  as good as the files it points at. Where prefabs of this kind live, which assembly definition
  the code belongs to, what the existing manager or UI screen looks like.
- **The baselines, verbatim**: whether this project has tests at all, the tests already failing
  on the base branch by name, the import errors and broken shaders already present on a clean
  checkout, and the base branch's existing broken-reference list. Everything outside those lists
  is the worker's own regression and blocks its commit.
- **How high the verification ladder goes in this project** — can it run tests, can it be
  smoke-tested in play mode, is a build affordable per task. The worker must not have to discover
  this. Say explicitly that it reports the rung it reached and never claims "verified".
- **That a manual checklist is required** whenever nothing automated proves the behaviour, and
  that the task is not done until a person confirms it.
- **Which scenes and prefabs this task is allowed to touch**, and which it must not. This is the
  conflict map, handed down. If it needs something outside that set, it reports rather than
  spreading.
- **Whether a scene change is expected at all.** Most tasks should come back with an empty
  `git diff -- '*.unity'`. Say so explicitly, so an unexpected scene diff is visibly wrong rather
  than quietly accepted.
- The **editor agent's name** if one already exists, so it does not have to ask.
- **The shared-checkout rules, verbatim** (next section).
- **You must NOT spawn subagents.** Do all the work yourself.
- KISS: the smallest diff that fully solves the task; do not delete comments or code the task
  does not require touching.
- "Report back: the branch, every file created or edited with full paths, the scenes and prefabs
  you touched and why, verification results with output, and anything you deviated from,
  discovered or left undone."

## Shared-checkout rules, verbatim

- You are working in the user's own checkout. There is no worktree and no isolated copy, so
  there is nothing to recover from if you destroy something.
- **Stay on the branch named in this brief.** Do not create, rename, switch or delete a branch.
- **Never `git stash`, `reset --hard`, `checkout --force`, or delete a branch.**
- If the working tree has changes you did not make, **stop and report it**. Do not build on
  someone else's uncommitted work.
- Leave `session-materials/` alone; it is not yours.
- Commit **rarely**, only a coherent finished chunk, and **never on a red gate**.
- **A pure move lands first** — a rename, a file split, or converting loose scene objects into
  prefabs is its own first commit with no behaviour change. New behaviour comes after.
- Commit **subject only**, empty body, matched to the project's own commit style.
- **Never push, never open a PR, never touch a remote.**
- Every new asset is committed **with its `.meta`**. An asset without its meta gives everyone
  else a fresh GUID on import and silently breaks every reference to it.

## Editor work, verbatim

Anything needing the editor — a batch run, a build, a test suite, an import check — is serialized
through one shared editor agent, because a Unity project can be held by one editor at a time and
an import is expensive. Never drive the editor yourself.

1. Check whether an editor agent exists (`ListAgents`, or the name in this brief).
2. If none exists, report `EDITOR REQUEST — no editor agent present` to the manager, with the
   request below.
3. Send it: the branch, exactly what to run, and what counts as pass.
4. **One outstanding request at a time.** Wait for the verdict; keep working on anything that
   does not depend on it.
