---
name: unity-manage-work
description: >
  Run a Unity task or backlog end to end as a MANAGER: settle the base branch with the user, cut
  one branch, plan the order from a scene-and-prefab conflict map, delegate implementation to
  worker subagents that follow `unity-agent-worker`, route all editor-backed work through one
  shared editor agent, review what comes back, and close with a report and a draft PR file per
  task. Work happens in the user's own checkout — no worktrees — so writers run one at a time.
  You never write game code yourself. Nothing is ever pushed. Use when: "/unity-manage-work",
  "manage this Unity work", "here is a list of Unity tasks, get them done", "delegate these to
  agents", or the user hands over Unity work and wants it delivered, not investigated.
---

# Unity manage work

You are the **MANAGER**. Planning, delegation, quality gating, reporting. Workers implement.
You do not write game code.

Flow: **base branch → intake → conflict map → order → delegate → review → report + draft PRs**.

| File | Read it when |
|---|---|
| `references/worker-brief.md` | Spawning a worker (Step 5). Everything the prompt must carry. |
| `references/editor-agent.md` | Any task needs the editor (Step 5a). Runbook, queue rules, prompt. |

Engine mechanics — prefabs, scenes, the Unity CLI — are the `unity-scene-habits` skill. Workers
follow it. You do not need to re-derive it here.

---

## Step 0 — One checkout, one branch, one writer

This skill does **not** use worktrees. Everything happens in the user's own checkout. That is a
deliberate trade and it sets the rules for everything below:

- **A Unity project's `Library/` is gigabytes and git-ignored.** A fresh worktree has none, so
  every parallel worker would pay a full asset reimport before doing any work. One shared
  checkout keeps one warm `Library`, and that is the single biggest speed-up available here.
- **One checkout holds one branch.** Two writers cannot hold two branches at once, so
  **implementation workers run strictly one at a time.** Never spawn two writers.
- **Read-only agents may run in parallel** — scouting, research, review. Up to three at once,
  and never while they could be confused for a writer.
- **Nobody switches branches mid-session.** Not you, not a worker. The branch is cut once in
  Step 0 and everything lands on it.
- **Never `stash`, `reset --hard`, `checkout --force`, or delete a branch.** There is no
  isolated copy to fall back on. The user's working tree is the only one.

Then settle the base with the user, before anything else:

1. Show recent activity:

```bash
git branch --sort=-committerdate --format='%(refname:short) %(committerdate:relative)' | head -12
git status --short
```

2. Ask with `AskUserQuestion`: the current branch (recommended), two or three plausible others
   by recency and naming, or Other.
3. **The working tree must be clean before you cut the branch.** If it is dirty, show what is
   uncommitted and let the user decide. Never clean it yourself.
4. **If an editor has the project open, say so now.** Batch-mode work will fail against a locked
   project, and a running editor can overwrite files underneath a worker. Ask whether to close
   it or to work through the connected-editor path.
5. Cut one branch off the locked base, named for the whole body of work in kebab-case.

---

## Step 1 — Intake

1. Fetch anything remote; read every link and file given.
2. Split into **discrete tasks**. One task = one deliverable = one worker = one commit range.
3. If the user gave explicit steps, keep their order and wording. Distribute them, do not
   redesign them.
4. Resolve open decisions **now**. Kickoff is the one moment the user is expected to be present;
   batch every genuine ambiguity into the same `AskUserQuestion` as the base branch. Capture
   answers verbatim — they go into worker prompts.
5. If the project is unfamiliar, run one cheap scouting pass (read-only agents, in parallel) to
   get exact anchor files: where prefabs live, which assembly definitions exist, what the
   managers are called, which scenes are the contested ones.

Restate the task list to the user, one line each, before spawning anything.

---

## Step 2 — Session materials

```bash
mkdir -p session-materials && grep -qxF 'session-materials/' .git/info/exclude || echo 'session-materials/' >> .git/info/exclude
```

Plan, tracking table, decisions, blockers, draft PRs and the final report all live there. Being
in `.git/info/exclude` keeps them out of `git status` and out of every commit — which matters
more here than usual, because workers are committing into the user's real checkout.

---

## Step 3 — The conflict map

For every task write down what it touches, in this order of danger:

| Touches | Why it matters |
|---|---|
| A **scene** (`.unity`) | One shared file. Two tasks in one scene will conflict, and the conflict is ugly. |
| A **prefab** (`.prefab`) | Mergeable in practice only because prefabs are small and many. Two tasks in one prefab still collide. |
| Assets, `.meta`, `ProjectSettings` | Binary or structurally unmergeable. Treat any overlap as a hard conflict. |
| C# only | Ordinary text. Normal merge rules apply. |

Because writers are sequential, this map decides **order**, not parallelism:

- Tasks touching the same scene or prefab go **adjacent and ordered**, never interleaved, so a
  half-finished change never sits under the next one.
- A task that only changes C# can go anywhere.
- A task that **converts loose scene objects into prefabs** goes first. It shrinks the scene for
  everything after it. Its own commit, per `unity-scene-habits`.

Run the branch scan from `unity-scene-habits` before planning, not after. If another branch
already edits a scene on your list, that is a planning input — say it to the user at kickoff
rather than discovering it at merge time.

Show the user the order before starting.

---

## Step 4 — Pick the model per agent

| You (manager) | Worker — implementation | Worker — small/mechanical | Research / review | Editor agent |
|---|---|---|---|---|
| Fable 5 | Opus 5 | Opus 5 | Opus 5 | Sonnet |
| Opus 5 | Opus 5 | Opus 4.8 | Sonnet | Sonnet |

The editor agent runs a weak model on purpose: it executes a runbook, it does not reason about
the project. That only works if **you** hand it exact commands (Step 5a).

Running below Opus yourself → match your own tier rather than reaching upward; you review every
returned task and cannot meaningfully review work from a stronger model.

---

## Step 4a — You decide; you do not block on the user

Once a worker is running, the session is non-blocking. Answer its questions yourself,
immediately: pick the option that is simple now and still right in six months, mirror what the
project already does, prefer the smallest change that will not need undoing. Send a decision,
not a discussion. Log it in `session-materials/decisions.md` — question, choice, one-line why.

Do **not** ask the user mid-session about naming, approach, scope edges or trade-offs.

The exceptions are narrow, and two of them are Unity-specific:

- Something destructive, unsafe or irreversible.
- **An editor upgrade.** If the only way forward opens the project in a newer editor, stop. That
  is irreversible and it is the user's call, always.
- **Installing a package** — `unity pipeline install`, or anything else that edits the package
  manifest. That is a project-wide dependency decision.
- A hard external block: no licence, no editor, an unavailable service.
- A discovery that invalidates the task list.

Even then, prefer to log it in `session-materials/blockers.md`, mark that task **BLOCKED**, keep
the rest moving, and surface it under **BIG BLOCKERS** in the report.

---

## Step 5 — Spawn the worker

Read `references/worker-brief.md` and build every prompt from it. The short version:

- Agent tool, `subagent_type: "general-purpose"`, model from Step 4. **No `isolation`** — the
  worker works in the user's checkout, on the branch you already cut.
- Every worker follows the `unity-agent-worker` skill, which follows `unity-scene-habits` for
  anything touching the engine.
- The prompt carries: the task in full, every locked decision verbatim, anchor files to mirror,
  the branch it is on, the baseline (below), the git rules verbatim, "never spawn subagents",
  "never switch branches", and what to report back.
- **One writer at a time.** Wait for the current worker to finish and pass review before
  spawning the next.

### The baseline, before any worker starts

Unity needs two baselines, and a worker without them will chase breakage it did not cause:

1. **Tests** — the failing tests on the base branch, by name.
2. **Clean import** — the console errors, warnings, missing references and broken shaders that
   are *already* there on an untouched checkout.

Get both from the editor agent's first job (Step 5a) and put them verbatim into every brief and
into `session-materials/`.

## Step 5a — The editor agent (singleton, queued)

A Unity project can be held by one editor at a time, and an import is expensive. So editor-backed
work does not live inside workers — it goes to **one shared editor agent**, spawned lazily and
exactly once, on a weak model, kept alive to the end of the session. Read
`references/editor-agent.md` the first time a worker reports `EDITOR REQUEST — no editor agent
present`.

---

## Step 6 — Review each returned task

1. Read the diff yourself: `git diff <base>...HEAD` and `git status --short`.
2. **Look at what changed, not just how much.** In this project the file extensions are the
   review:
   - A `.unity` diff on a task that should not have touched a scene is a finding.
   - A new `.prefab` without its `.meta`, or a `.meta` without its asset, is a blocker — it
     breaks references for everyone on merge.
   - A scene diff far larger than the task means the editor re-serialized the file. Do not
     accept it without an explanation.
3. Judge: does it do the task, honour the locked decisions, follow the project's conventions,
   pass its own verification?
4. **If quality is good, accept and move on.** Do not manufacture change requests.
5. If something is genuinely wrong, send a numbered, precise fix list to the SAME worker via
   `SendMessage` — it keeps its context.
6. **Two fix rounds by default**, a third only when the worker is clearly converging. If it is
   not converging, have it wrap up cleanly — buildable tree, honest handover — and mark the task
   **PARTIAL**. Never loop blindly, and never escalate to the user instead of deciding.

A check-in or a "which way next" is not a fix round; answer it (Step 4a).

For a high-risk or large task, spawn one separate read-only reviewer agent rather than eyeballing
it yourself, so the review stays adversarial: verdict **SHIP** or **FIX-FIRST**, findings tagged
`[BLOCKER] / [SHOULD-FIX] / [NITPICK]` with `file:line`.

---

## Step 7 — Track as you go

Keep `session-materials/tracking.md` from the first spawn; you cannot reconstruct it later.

| task | agent id | model | scenes/prefabs touched | started | finished | tokens | status |

Give the editor agent its own row, plus a line per run (what ran, verdict, duration). Fill tokens
and timing from each completion notification; write `n/a` when a number was not reported, never
invent one.

---

## Step 8 — Draft PRs, as files

When a task is accepted, write `session-materials/pr-<task-slug>.md`: base branch, head branch,
title, body, and the verification that ran — including the editor agent's verdict.

Follow the project's own PR template and contributing rules where it has them; a plain
Summary-and-Changes body where it does not.

**Nothing is pushed. No remote is touched. No `gh pr create`.** The draft files are the
deliverable; the user opens the PRs.

---

## Step 9 — Final report

`session-materials/report.md`, summarized in chat:

0. **BIG BLOCKERS** — from `blockers.md`, first, in plain language. Omit the heading if none.
1. **Scene and prefab impact** — every scene touched, every prefab added or changed, and any
   other branch that also touches those scenes. This is the section the user acts on.
2. **Token & time accounting** — per agent, then session totals. Say plainly which were
   unavailable.
3. **Implementations** — per task: what it covers, verification status, and for any **PARTIAL**:
   what landed, what did not, the blocker, the suggested next step.
4. **Decisions you made on the user's behalf** — the ones that shape the result, so they can be
   overruled.
5. **Workflow improvements** — what to change next run: mis-ordered tasks, wrong model tier,
   missing anchor files, conflicts you did not predict.
6. **Draft PRs** — path to each file.

---

## Rules

- You manage; agents implement. Never write game code as the manager — branch setup, session
  files and mechanical housekeeping are yours.
- **No worktrees. One checkout, one branch, one writer at a time.** Read-only agents may run in
  parallel, up to three.
- **Nobody switches branches, stashes, resets, force-checks-out or deletes a branch.** There is
  no isolated copy.
- Base branch and genuine ambiguities are settled with the user at kickoff — the only sanctioned
  blocking ask, plus editor upgrades and package installs mid-session.
- **Subagents never spawn subagents.** Say it in every prompt.
- **Every worker follows `unity-agent-worker`**, which follows `unity-scene-habits`.
- **Exactly one editor agent**, weak model, spawned on demand, given a copy-paste runbook. Workers
  never drive the editor themselves.
- Order tasks by the conflict map. Scene-touching tasks are adjacent and ordered; prefabizing
  goes first.
- **Two baselines before any worker starts**: failing tests, and existing import errors.
- Workers commit rarely, subject-only messages, never on a red gate.
- **Never push, never open a remote PR — manager included.**
- Good enough is done: two fix rounds, a third only if clearly converging.
- Don't spawn an agent for work cheaper done inline; don't do work inline that a worker should own.
