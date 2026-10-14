# Brief templates

Write the brief as two files in `session-materials/`, not as one long prompt per worker. The
common part is written once and patched when something changes for everyone; the task part is
written per task. The worker prompt itself is then about ten lines: invoke `unity-agent-worker`,
read both files, follow them.

Patch `brief-common.md` whenever the environment changes: the autonomy mode switched, the
editor mode changed, Pipeline installed, the editor agent respawned, a new flake found. A task
brief that contradicts a stale common brief leaves the worker guessing which one is current.

## `brief-common.md`

```markdown
# Common brief

## Rules
Invoke `unity-agent-worker` and follow it. Read the project's CLAUDE.md / AGENTS.md first; they
outrank every skill. Never spawn subagents. Smallest diff that fully solves the task.

## Shared-checkout rules
<verbatim from worker-brief.md>

## Locked decisions
<every decision from kickoff, verbatim, plus later ones from decisions.md>

## Baselines
- Tests in this project: <yes/no, which assemblies>
- Failing on the base branch: <names, or none>
- Clean-import errors and warnings: <list>
- Existing broken references: <list>

## Verification ladder
<how high it goes: tests, play-mode smoke, build per task or not>
<sign-off, from the autonomy mode: per task, batched at the end, or deferred (full automatic: a
test per deliverable, checklists signed off together at the end)>

## Autonomy mode: <FULL AUTOMATIC, SEMI AUTOMATIC or HUMAN ASSISTED>
Live editor: <open and close it yourself when a job needs one (full) / ask the manager first and
carry on with the rest while you wait (semi, human assisted)>. Questions: <the manager answers
them / the manager may take decision moments to the user>.

## Editor mode: <BATCH or CONNECTED>
<the matching block from worker-brief.md, verbatim>
Project path: <ROOT>. Tests: `session-materials/batch-tests.sh` (connected: `run-tests.sh`,
`editor-recover.sh`). Compile check outside the editor: <the recorded command, or none>.
Speed mode: <off, or on with queue `session-materials/editor-queue/`>.

## Known flakes
<tests that fail in a full run and pass alone, by name; leave them to their own task>

## Report back
Branch, every file created or edited with full paths, scenes and prefabs touched and why,
verification results with output, anything deviated from, discovered or left undone, and a
"Tooling / skill friction" list: anything in the skills that was missing, wrong or awkward.
```

## `brief-task<N>.md`

```markdown
# Task <N>: <title>

## Deliver
<the task in full, one line per deliverable>

## Files
- Allowed scenes and prefabs: <list>
- Must not touch: <list>
- Scene change expected: <yes, which / no, `git diff -- '*.unity'` stays empty>

## Anchor files
<path: what it demonstrates>

## Skim
<doc sections worth reading, by file and heading; never "read everything">

## Tests
<what each deliverable is proven by; screenshot tests only for real visual work; new tests
only for new behaviour>
Filtered runs by <category or names>, as needed. At most <N> full runs. Full suite: <before your
last commit / at the end of the session, not yours>.

## Notes from task <N-1>
<what this worker must know: layers or tags added, API shapes, which test areas are taken,
builders and the order they run in>

## Also fix (from task <M> review)
<SHOULD-FIX findings on already-accepted work in files this task touches; add tests for them>

## Structure map
Update `Docs/GameStructure.md` if you add a system, event, builder or scene.
```

Leave out a section that has nothing in it rather than writing "none".
