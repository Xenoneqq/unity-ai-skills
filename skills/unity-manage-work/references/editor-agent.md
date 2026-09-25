# The editor agent

Read this the first time a worker reports `EDITOR REQUEST — no editor agent present`, or earlier
if you already know the tasks need builds, tests or import checks.

A Unity project can be held by **one editor at a time**, and a cold import costs minutes. So
editor-backed work does not live inside workers — it goes to one shared agent that owns the
editor for the session.

## Spawn it lazily, address it by id

Spawn on the first request, never a second time while it still answers. It is a resumable agent,
not a running one: it finishes after every job and wakes when someone sends it a message. Later
requests route to it via `SendMessage`, which resumes it with its queue and notes intact. Give
its name to every worker that needs it, and to later workers in their initial prompt.

Keep two things in `session-materials/` so replacing it is one edit:

- **Its spawn prompt**, in `editor-agent-prompt.md`, so a respawn is identical.
- **Its current id, in one place** that workers read it from, so a respawn changes one line
  rather than every brief.

After a pause or a restart the old id is gone, and stopping it reports no such task. Respawn from
the stored prompt, update the id, and make its first job an import check.

## Run it on a weak model

Sonnet. It executes a runbook; it must not have to work anything out. That puts the burden on
**you**: before spawning it, work out how this project actually builds and tests — read the
project's notes, check `unity-scene-habits` for the CLI surface, look for an existing CI script —
and bake the result into its prompt as a copy-paste runbook:

- **Which path the project is on**: the connected editor (Unity 6.0+, Pipeline installed) or
  batch mode. They are driven completely differently, so give the agent both recipes and a
  mechanical rule, not a judgement call: connected when `unity pipeline list` shows this project
  reachable, batch when no editor holds the project. A connected command that exits 6 or times
  out is retried in batch only if no editor holds the project; otherwise it is reported.
- **The editor binary or the CLI invocation**, exact, with the project path.
- **The exact command per job** — tests, play-mode smoke, build, import check — copy-paste ready.
  A build is minutes; say so, and say it is per task rather than per milestone.
- **Whether play-mode smoke works in this project at all**, and by which mechanism. It is the
  main way to prove a game starts when there are no tests, and it is not guaranteed to work
  headlessly. Establish it once; record the answer so nobody re-derives it.
- **How long each normally takes**, and the timeout past which to give up. Say plainly that a
  first run against a cold `Library/` reimports the whole project and can take many minutes
  while looking identical to a hang.
- **How to read the result**: which line means pass, where the report or log lands. For batch
  tests: totals from the `<test-run>` attributes of the results XML, failing names from
  `<test-case result="Failed">`.
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
- **Every message is a new request** unless it quotes a job number. A pending notification
  about an earlier job answers nothing new; never let it stand in for a reply. Acknowledge each
  request with the log number you will write, so the requester can match your reply to it.
- **Wait on the job, never on a search.** Start the editor with Bash `run_in_background` and act
  on its completion notification, or capture `$!` and wait on that PID. Never poll with
  `pgrep -f` or `ps | grep` on a pattern that also appears in your own command: it matches the
  loop itself, which then never exits. No loop outlives its job.
- **On the connected path, run only connected-safe methods.** A method that may call
  `EditorApplication.Exit` without an `Application.isBatchMode` guard closes the user's editor
  and their unsaved work. If you cannot tell, report back instead of running it.
- **Timeouts plus an idle editor mean a dialog.** If requests time out on the editor's main
  thread while its CPU sits idle and its log is quiet, a modal dialog is waiting for a click.
  Stop retrying and tell the manager the user needs to look at the editor.
- **Never open the project in a different editor version than the project's own.** That upgrade
  is irreversible. If the version is missing, report it rather than substituting.
- **Never close or kill an editor you did not start**, and never `unity close` — it exits without
  saving and may be the user's own session.
- On finish, reply to the sender of the request (a worker cannot know its own id, so never wait
  to be given one) with PASS/FAIL, failing test or error names, the relevant log
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
