# The editor agent

Read this the first time a worker reports `EDITOR REQUEST — no editor agent present`, or earlier
if you already know the tasks need builds, tests or import checks.

A Unity project can be held by **one editor at a time**, and a cold import costs minutes. So
editor-backed work does not live inside workers — it goes to one shared agent that owns the
editor for the session.

## Spawn it lazily and exactly once

Spawn on the first request, never a second time. Later requests route to the same agent via
`SendMessage`, which keeps its queue and its warm project. Give its name to every worker that
needs it, and to later workers in their initial prompt.

Keep it alive to the end of the session. A respawn loses the queue and may pay another import.

## Run it on a weak model

Sonnet. It executes a runbook; it must not have to work anything out. That puts the burden on
**you**: before spawning it, work out how this project actually builds and tests — read the
project's notes, check `unity-scene-habits` for the CLI surface, look for an existing CI script —
and bake the result into its prompt as a copy-paste runbook:

- **Which path the project is on**: the connected editor (Unity 6.0+, Pipeline installed) or
  batch mode. They are driven completely differently, and the agent must not have to choose.
- **The editor binary or the CLI invocation**, exact, with the project path.
- **The exact command per job** — tests, play-mode smoke, build, import check — copy-paste ready.
  A build is minutes; say so, and say it is per task rather than per milestone.
- **Whether play-mode smoke works in this project at all**, and by which mechanism. It is the
  main way to prove a game starts when there are no tests, and it is not guaranteed to work
  headlessly. Establish it once; record the answer so nobody re-derives it.
- **How long each normally takes**, and the timeout past which to give up. Say plainly that a
  first run against a cold `Library/` reimports the whole project and can take many minutes
  while looking identical to a hang.
- **How to read the result**: which line means pass, where the report or log lands.
- Anything known-flaky, and whether one retry is allowed. Be explicit, or it will retry forever
  or give up too early.

If you do not know the recipe, spend one cheap read-only pass to find it. Do not let the editor
agent go looking.

## Its first job is the two baselines

Before any worker's request:

1. **Whether the project has any tests at all.** Most game projects do not. This decides how high
   the verification ladder goes, and the manager needs it before the first brief.
2. **Failing tests** on the base branch, untouched, by name, if there are any.
3. **Clean-import state** — console errors, warnings, missing references, broken shaders already
   present before anyone touched anything.
4. **Existing broken references** — the base branch's unresolved-GUID list, so a worker is judged
   only on what it added.

Both go verbatim into every worker brief and into `session-materials/`. Without them a worker
either chases breakage it did not cause or excuses breakage it did.

## What the prompt must say

- You are the **only** agent that drives the editor this session. You run things; you never edit
  source, never fix code, never commit, never push, and **never spawn subagents**.
- **One job at a time, FIFO.** The project can be held by one editor; there is no concurrency to
  exploit. Do not start a second run because the first is slow.
- A request carries: requesting agent, branch, exactly what to run, pass criteria.
- **Never open the project in a different editor version than the project's own.** That upgrade
  is irreversible. If the version is missing, report it rather than substituting.
- **Never close or kill an editor you did not start**, and never `unity close` — it exits without
  saving and may be the user's own session.
- On finish, reply to the requester with PASS/FAIL, failing test or error names, the relevant log
  excerpt, and the path to the full log under
  `session-materials/editor-logs/<branch>-<n>.log`.
- Report queue state to the manager when it changes materially — depth, long waits, an import
  that will not finish.
- If the editor cannot run at all — no licence, project locked by another editor, version not
  installed — report `EDITOR BLOCKED` with the error instead of retrying. Move to the next item.

## Manager duties around it

`EDITOR BLOCKED` goes in `session-materials/blockers.md` like any other hard block: park what
cannot be verified, keep the rest moving, surface it under BIG BLOCKERS.

Watch for the two blocks only the user can clear — **no licence**, and **the project open in the
user's own editor**. Both are kickoff questions if you can foresee them (Step 0), and blockers if
you cannot. Never resolve the second by closing their editor.
