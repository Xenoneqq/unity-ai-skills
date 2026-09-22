---
name: unity-agent-worker
description: >
  Carry one Unity task end to end in the user's own checkout: read the project's rules first,
  work in verifiable milestones, do all engine work through `unity-scene-habits` (prefab-first,
  editor CLI, never hand-edit YAML), send editor-backed runs to the shared editor agent, keep
  every new asset paired with its `.meta`, verify before every commit, and never push or switch
  branches. Use when handed a single Unity task to implement — by a user, or as a worker spawned
  by `unity-manage-work`.
---

# Unity agent worker

One task, start to finish, in the checkout you were given. You implement; you do not manage,
and you do not spawn subagents.

If a manager spawned you, it locked the branch, the decisions and the baseline. Treat that brief
as authoritative and report to the manager, never to the user.

## 1. Read before you write

In this order, stopping as soon as you have what you need:

1. The project's own rules — `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, contributor notes.
   **These outrank this skill and every skill it references.**
2. The anchor files you were given, or the nearest equivalents. Mirror what is already there:
   folder layout, naming, assembly definitions, how existing prefabs are built.
3. `unity-scene-habits` — the engine mechanics. Everything you do to a prefab, a scene, an asset
   or the editor CLI follows it. Do not re-derive it and do not work around it.

## 2. You are in a shared checkout

There is no worktree and no isolated copy. The tree you are editing is the user's own.

- **Stay on the branch you were given.** Never `checkout` another branch, never create one,
  never rename one.
- **Never `git stash`, `reset --hard`, `checkout --force`, or delete a branch.** There is nothing
  to recover from.
- **Stay inside your file set.** If the task needs a file nobody mentioned, that is a finding to
  report, not a licence to spread.
- **Leave `session-materials/` alone.** It is the manager's.
- If the working tree contains changes you did not make, stop and report it. Do not build on top
  of someone else's uncommitted work.

## 3. Work in milestones

Split the task into chunks that can each be *shown* to work. For each one: make the change, run
the gate, then move on. Do not build the whole thing and verify at the end.

Prefer the smallest diff that fully solves the task. Do not delete comments or code the task does
not require you to touch, and do not tidy things nobody asked about.

## 4. Engine work goes through the CLI, editor runs go through the editor agent

Prefab and asset edits you drive yourself, per `unity-scene-habits` — prefab-first, edit prefab
assets rather than scenes, never hand-edit `.unity`, `.prefab` or `.meta`.

Anything needing the editor itself — a batch run, a build, a test suite, an import check — is
**serialized centrally**, because one project can be held by one editor at a time and an import
is expensive. Never drive it yourself:

1. Check whether an editor agent exists (`ListAgents`, or the name your manager gave you).
2. If none exists, report `EDITOR REQUEST — no editor agent present` to your manager, with the
   request below. The manager spawns it and hands you its name.
3. Send it: the branch, exactly what to run, and what counts as pass.
4. **One outstanding request at a time.** Wait for the verdict before sending another, and keep
   working on anything that does not depend on it.

## 5. The gate, before every commit

Never commit on a red gate. Never commit something you have not run.

- **It compiles.** No `error CS` anywhere in the run.
- **Tests pass**, apart from the known-failing baseline you were given, by name. A failure
  outside that list is yours and blocks the commit. Chasing one inside it is wasted work;
  hiding a real one behind "already broken" is worse.
- **No new import errors** beyond the baseline: missing references, broken shaders, console
  errors on a clean import.
- **Every asset is paired with its `.meta`**, and every `.meta` with its asset. An unpaired new
  asset breaks references for everyone on merge — this is a blocker, not a nitpick:

```bash
git status --porcelain -z -- Assets | while IFS= read -r -d '' e; do
  f=${e#???}
  case "$f" in
    *.meta) [ -e "${f%.meta}" ] || echo "orphan meta: $f" ;;
    */)     ;;
    *)      [ -e "$f.meta" ]    || echo "missing meta: $f" ;;
  esac
done
```

- **The scene diff is intended.** `git diff --stat -- '*.unity'` should be empty unless the task
  genuinely needed a scene change. If it is not empty and you did not mean it, revert it before
  committing — whole file, not partial hunks.

## 6. Commits

- Commit **rarely** — one coherent finished chunk, not one per file and not one at the end.
- **A pure move lands first.** If the task needs a rename, a split, or converting loose scene
  objects into prefabs to make room, that is its own first commit with no behaviour change.
- Subject only, empty body, matching the project's own style. Check what the repo actually does:

```bash
git log --author="$(git config user.name)" -15 --format='%s'
```

- **Never push. Never open a PR. Never touch a remote.**

## 7. Report back

- The branch, and every file created or edited, with full paths.
- **Scenes and prefabs specifically** — what scene diffs exist and why, what prefabs you added
  or changed. Your manager needs this for the conflict report; bury it and merge day gets worse.
- Verification results, pass or fail, with the output.
- Anything you deviated from, discovered, or left undone, and why.

If you could not finish: say what landed, what did not, what blocked it, and what you would do
next. Leave the tree buildable. An honest partial handover beats a broken tree and a claim of
success.
