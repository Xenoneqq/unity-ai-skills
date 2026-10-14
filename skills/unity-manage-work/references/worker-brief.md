# The worker brief

Read this before spawning any worker. Every worker prompt is built from it.

Agent tool, `subagent_type: "general-purpose"`, model from Step 4, and **no `isolation`** outside
speed mode (Step 5b): the worker works in the user's own checkout on the branch you already cut.
There is no worktree and no second copy, which is why only one writer runs at a time.

Write it as two files, a common brief and a task brief, and keep the prompt itself short;
[brief-templates.md](brief-templates.md) has both templates.

## Open with the skill

Tell it to invoke `unity-agent-worker` and follow it for the whole task. That skill already
carries the process: project rules first, milestones, engine work through `unity-scene-habits`,
files first and one batch Unity pass, the gate before every commit, never push. Your prompt
supplies what it cannot know and pre-answers what it would otherwise stop on.

## What every prompt must contain

**Keep it short.** The task, the locked decisions, the files to touch and which doc sections to
skim, by heading. Never "read X, Y and every skill in full": the worker reads the project's
CLAUDE.md anyway, and its skill says what else it needs. A quick-path task (Step 5) needs a
few lines on top of the common brief.

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
  that the task is not done until a person confirms it. Under unattended mode (Step 6b) add that
  every deliverable also needs a test that fails if the behaviour breaks, driven through test
  seams and deterministic (`unity-coding-habits`, `references/testing.md`), and that the
  checklist is still written, for the combined sign-off at the end of the session.
- **A hard test budget**: "at most N full runs", the filter to use for the cheap filtered runs
  (a category or test names), whether this worker runs the full suite, and the known-flake list.
- **Which scenes and prefabs this task is allowed to touch**, and which it must not. This is the
  conflict map, handed down. If it needs something outside that set, it reports rather than
  spreading.
- **Whether a scene change is expected at all.** Most tasks should come back with an empty
  `git diff -- '*.unity'`. Say so explicitly, so an unexpected scene diff is visibly wrong rather
  than quietly accepted.
- **The editor mode and where the scripts are** (`session-materials/batch-tests.sh`, and for the
  connected path `run-tests.sh` and `editor-recover.sh`), and the compile check outside the
  editor if one works in this project. In speed mode, the lane (files or editor) and the
  editor queue, `session-materials/editor-queue/`.
- **The shared-checkout rules, verbatim** (next section).
- **You must NOT spawn subagents.** Do all the work yourself.
- KISS: the smallest diff that fully solves the task; do not delete comments or code the task
  does not require touching.
- "Report back: the branch, every file created or edited with full paths, the scenes and prefabs
  you touched and why, verification results with output, anything you deviated from,
  discovered or left undone, and a Tooling / skill friction list: anything in the skills that
  was missing, wrong or awkward."
- **How memory-driven preferences are handled.** Subagents inherit the user's auto-memory. Where
  a memory asks for something this brief forbids, such as writing into `session-materials/`,
  the brief wins and the worker puts it in its report instead.

## Shared-checkout rules, verbatim

- You are working in the user's own checkout. There is no worktree and no isolated copy, so
  there is nothing to recover from if you destroy something.
- **Screenshots only when the brief asks, or for real visual work**: new UI, lighting, a look the
  user will judge (`unity-scene-habits`, `references/visual-checks.md`). Never to show that an
  object is there; an existing test's raycast or bounds assert says that for free. Write the
  PNGs to `session-materials/screenshots/task<N>/`, the one place in `session-materials/` you
  may write. The manager opens every one.
- **Stay on the branch named in this brief.** Do not create, rename, switch or delete a branch.
- **Never `git stash`, `reset --hard`, `checkout --force`, or delete a branch.**
- If the working tree has changes you did not make, **stop and report it**. Do not build on
  someone else's uncommitted work.
- Leave `session-materials/` alone apart from `screenshots/` and the editor queue; it is not
  yours.
- **When a command's output decides something**, such as a grep that finds nothing or a count,
  put anything beyond a one-liner in a script file and send the output to a file before reading
  it. Shell hooks can rewrite commands and trim their output, and a missed match looks exactly
  like a clean result.
- Commit **rarely**, only a coherent finished chunk, and **never on a red gate**.
- **A pure move lands first** — a rename, a file split, or converting loose scene objects into
  prefabs is its own first commit with no behaviour change. New behaviour comes after.
- Commit **subject only**, empty body, matched to the project's own commit style.
- **Never push, never open a PR, never touch a remote.**
- Every new asset is committed **with its `.meta`**. An asset without its meta gives everyone
  else a fresh GUID on import and silently breaks every reference to it.

## Editor mode: BATCH, verbatim

The default. A Unity project can be held by one editor at a time, batch included, and an import
is expensive, so only one agent uses Unity at a time. You run it yourself, with the editor
closed.

1. Work in files first. Use Unity in one pass at the end of the task (`unity-agent-worker`,
   `references/files-first.md`): one `unity run "$ROOT" --timeout 900 --no-tail -l <log> --
   -executeMethod <Type.Method>` per group of builders, filtered tests, then the full run if it is
   yours.
2. Run tests with `session-materials/batch-tests.sh --mode EditMode|PlayMode [names]`. No window
   opens and nothing needs focus.
3. **Exit 2, "an editor holds the project"**: the user is probably testing. Never close their
   editor. Do the non-Unity part of the task, then report.
4. A build or an import check runs in the same pass, one at a time.
5. If the task needs a live editor (interactive inspection, something the user asked to watch),
   say so in your report rather than opening one, unless this brief allows it.

## Editor mode: CONNECTED, verbatim

Only when the user chose it at kickoff, or this brief allows a live editor for one job.

1. Open the editor only if it is not open, do the job, close it again (`unity-scene-habits`,
   `references/connected-editor.md`, "On demand, then close"). Never drive an editor the user is
   working in.
2. Run tests with `session-materials/run-tests.sh`. It refreshes, recompiles, reloads, checks
   the editor is ready and no scene is dirty, then runs.
3. **Exit 3**: the editor stopped answering. Run `session-materials/editor-recover.sh` once and
   retry once. Its exit 6 means the screen is locked and the editor was closed: carry on in batch
   mode. Exit 5, or a second exit 3: stop and report.
4. If this brief names an editor agent instead, send it the branch, exactly what to run and what
   counts as pass, one request at a time. To wait, end your turn: the reply resumes you.
