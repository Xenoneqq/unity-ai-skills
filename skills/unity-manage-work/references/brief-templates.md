# Brief templates

Write the brief as two files in `session-materials/`, not as one long prompt per worker. The
common part is written once and patched when something changes for everyone; the task part is
written per task. The worker prompt itself is then about ten lines: invoke `unity-agent-worker`,
read both files, follow them.

Patch `brief-common.md` whenever the environment changes: unattended mode switched on, the editor
opened or closed, Pipeline installed, the editor agent respawned. A task brief that contradicts
a stale common brief leaves the worker guessing which one is current.

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
<sign-off mode: manual checklist for a person, or a test per deliverable (unattended)>

## Editor agent
Id: <current id>. Path: <connected or batch>. Send one request at a time; to wait, end your turn.

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

## Tests
<what each deliverable is proven by; screenshot tests for anything visual>

## Notes from task <N-1>
<what this worker must know: layers or tags added, API shapes, which test areas are taken,
builders and the order they run in>

## Also fix (from task <M> review)
<SHOULD-FIX findings on already-accepted work in files this task touches; add tests for them>

## Structure map
Update `Docs/GameStructure.md` if you add a system, event, builder or scene.
```

Leave out a section that has nothing in it rather than writing "none".
