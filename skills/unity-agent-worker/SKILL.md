---
name: unity-agent-worker
description: >
  Carry one Unity task end to end in the user's own checkout: read the project's rules first,
  work in verifiable milestones, do all engine work through `unity-scene-habits` (prefab-first,
  editor CLI, never hand-edit YAML), work in files first and use the editor in one pass, keep
  every new asset paired with its `.meta`, verify before every commit, and never push or switch
  branches. Use when handed a single Unity task to implement — by a user, or as a worker spawned
  by `unity-manage-work`.
---

# Unity agent worker

One task, start to finish, in the checkout you were given. You implement; you do not manage,
and you do not spawn subagents.

If a manager spawned you, it locked the branch, the decisions and the baseline. Treat that brief
as authoritative and report to the manager, never to the user.

## Size the process to the task

A small, clear change does not need the full process below. Take the **quick path** when all of
these hold:

- It changes content or data, not behaviour: swap a model, delete or move an object, flip a
  serialized field, retune a number.
- It touches a handful of existing files and adds no new script.
- The brief says exactly what to change. Nothing is left to design.

The quick path: read the project's `CLAUDE.md`, make the edit, run one existing test that covers
the area if there is one, run the rung-0 checks from section 5 (every asset paired with its
`.meta`, the scene diff intended), and commit. If nothing automated covers it, add a one-line
manual check to your report. No milestones, no screenshots, no new tests, no reading every skill.

A new mechanic, a new system, or risky code such as the player controller or the save system
takes the full process. If a quick task turns out to need new code, switch to it and say so.

## 1. Read before you write

In this order, stopping as soon as you have what you need:

1. The project's own rules — `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, contributor notes.
   **These outrank this skill and every skill it references.**
2. The anchor files you were given, or the nearest equivalents. Mirror what is already there:
   folder layout, naming, assembly definitions, how existing prefabs are built. Where the brief
   names doc sections to skim, read those sections, not the whole file.
3. `unity-scene-habits` — the engine mechanics. Everything you do to a prefab, a scene, an asset
   or the editor CLI follows it. Do not re-derive it and do not work around it.

## 2. You are in a shared checkout

There is no worktree and no isolated copy. The tree you are editing is the user's own. The one
exception is a speed-mode files-lane task (`unity-manage-work`), which runs in a worktree of its
own: never open the editor there.

- **Stay on the branch you were given.** Never `checkout` another branch, never create one,
  never rename one.
- **Never `git stash`, `reset --hard`, `checkout --force`, or delete a branch.** There is nothing
  to recover from.
- **Stay inside your file set.** If the task needs a file nobody mentioned, that is a finding to
  report, not a licence to spread.
- **Leave `session-materials/` alone**, apart from anything your brief lets you write there. It
  is the manager's.
- If the working tree contains changes you did not make, stop and report it. Do not build on top
  of someone else's uncommitted work.

## 3. Work in milestones

Split the task into chunks that can each be *shown* to work. For each one: make the change, check
it where that is cheap (a compile outside the editor, the intended diff), then move on. Do not
build the whole thing and only check it at the end. Editor-backed checks, `.meta` pairing and
test runs among them, happen in the editor pass (section 4), not per milestone.

Prefer the smallest diff that fully solves the task. Do not delete comments or code the task does
not require you to touch, and do not tidy things nobody asked about.

## 4. Files first, then one editor pass

Most of a task needs no editor. Write it as files: C# as files, and scene, prefab and asset
changes as builder scripts per `unity-scene-habits` (prefab-first, edit prefab assets rather than
scenes, never hand-edit `.unity`, `.prefab` or `.meta`). Check the compile outside the editor
where the project has a recorded way to. Then use the editor **once per task**, or once per batch
of small tasks: builders, tests and the final compile together. That pass creates the `.meta`
files for new assets, so commit after it, never before. Visual and feel work is the exception
and happens in the editor from the start. [references/files-first.md](references/files-first.md)
has the detail.

You drive the editor yourself, and **only one agent uses it at a time**: one project can be held
by one editor, and an import is expensive.

- **Run tests through the test script**, `unity-scene-habits`' `references/run-tests.sh`, or the
  copy your brief names. It refreshes, recompiles with focus, reloads, checks the editor is ready
  and no scene is dirty, and stops on a modal dialog instead of polling forever.
- **Exit 3 means stop.** The editor stopped answering, almost always a modal dialog. Report it.
- **In speed mode your brief may give an editor queue**: pass `--queue <dir>`. The wait is
  bounded; on exit 4, work on something else, try once more, then report. Never loop on it.
- **In batch mode** the editor must be closed, and it is one batch run at a time
  (`unity-scene-habits`).
- **The project's rule wins.** If the project's `CLAUDE.md` says who drives the editor, follow it
  over this section.
- If your brief names an editor agent instead (`unity-manage-work`), send it the branch, exactly
  what to run and what counts as pass, one request at a time. To wait, end your turn: the reply
  resumes you.

## 5. Verify — as far as the project allows

Read `references/verification.md`. Most game projects have no automated tests, so verification is
a ladder: climb as far as this project allows, then **say which rung you reached.** Never report
"tests pass" or "verified" for a project that has no tests.

**Rung 0 and 1 run before every commit.** Never commit on a red gate, and never commit something
you have not run.

- **It compiles.** No `error CS` anywhere in the run.
- **Tests pass** *if the project has any*: the isolated tests for what changed, and one full
  run before the last commit (test budget, below), apart from the known-failing baseline you
  were given, by name. A failure outside that list is yours and blocks the commit. Chasing one
  inside it is wasted work; hiding a real one behind "already broken" is worse. If the project
  has no tests, say that rather than reporting a green suite.
- **No new import errors** beyond the baseline: missing references, broken shaders, console
  errors on a clean import.
- **No new broken references.** The most common real breakage in Unity and it needs no test
  framework. `references/verification.md` has the scan; run it on the base branch too, so only
  the new ones count as yours.
- **Every asset is paired with its `.meta`**, and every `.meta` with its asset. An unpaired new
  asset breaks references for everyone on merge — a blocker, not a nitpick:

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
  genuinely needed a scene change. If it is not and you did not mean it, revert the whole file —
  not partial hunks — before committing.

**Screenshots only when asked, or for real visual work**: new UI, lighting, a look the user will
judge (`unity-scene-habits`, `references/visual-checks.md`). Never to show that an object is
there; an existing test's raycast or bounds assert says the same for free.

**New tests only for new behaviour.** Swapping or deleting content updates the existing tests
that name the old thing. It does not add tests.

### The test budget

Every editor-backed test run pays a recompile, a domain reload (30-90 s) and, for PlayMode,
entering Play mode. Spend runs deliberately:

- **Code first, tests after.** Write the whole change, or the whole batch of small tasks, then
  test it in the editor pass. Never edit, test, edit, test per task.
- **While working, test a little, isolated only**: the filtered tests for the case at hand, by
  category or by name.
- **At the end, one full run** to confirm nothing else broke, right before your final commit,
  unless your brief says it runs at the end of the session instead. A change to shared core code
  (the player controller, the save system, anything many features depend on) earns its own full
  run, so a late red suite can still be traced.
- **If the full run breaks: list, isolate, test, fix.** List the failures, rerun each on its own
  to confirm it is real, reproduce it with that test, fix it, then rerun only those tests plus
  the area the fix touched. `references/verification.md` has the loop; the test script takes
  several names, so each rerun is one call.
- **Stay under the number of runs your brief gives.** Needing more is a finding to report.

**Rungs 2 and 3 run once, when the task is otherwise done**: does the game start, and does it
build. Both need the editor; run them as in section 4. They are slow; do not run them per
milestone.

**Rung 4 is a human, and it blocks.** When nothing above proves the feature behaves — which on a
project without tests is most features — write a manual checklist: the scene to open, the exact
steps, and what counts as failure. Hand it to your manager with the task. **The task is not done
until a person confirms it.** A reported failure comes back to you as an ordinary fix round.

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
- **The rung you reached**, in one line, and what is still unproven. "Compiles, imports clean, no
  new broken references, build green; no automated tests in this project, behaviour unverified"
  is an honest report. "Verified" is not.
- **The manual checklist**, whenever behaviour is not covered by anything automated.
- Verification results, pass or fail, with the output.
- Anything you deviated from, discovered, or left undone, and why.

If you could not finish: say what landed, what did not, what blocked it, and what you would do
next. Leave the tree buildable. An honest partial handover beats a broken tree and a claim of
success.
