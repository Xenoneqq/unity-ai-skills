# Tracking, draft PRs and the report

Read this at the first spawn — the tracking table cannot be reconstructed afterwards — and again
when tasks start coming back accepted.

## Step 7 — Track as you go

Keep `session-materials/tracking.md` from the first spawn; you cannot reconstruct it later.

| task | agent id | model | scenes/prefabs touched | started | finished | tokens | status |

Give the editor agent its own row, plus a line per run (what ran, verdict, duration). Fill tokens
and timing from each completion notification; write `n/a` when a number was not reported, never
invent one.

---

## Step 8 — Draft PRs, as files

When a task is accepted, write `session-materials/pr-<task-slug>.md`: base branch, head branch,
title, body, and the verification that actually ran — the rung reached, what is still unproven,
and that a person signed the behaviour off. Never write "tested" or "verified" for a project with
no tests; say what was checked and what was not.

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
3. **Implementations** — per task: what it covers, **the verification rung it reached and what
   remains unproven**, who signed it off, and for any **PARTIAL**: what landed, what did not, the
   blocker, the suggested next step.
   State once, up front, whether this project has automated tests at all. A reader who assumes it
   does will misread every line under this heading.
4. **Decisions you made on the user's behalf** — the ones that shape the result, so they can be
   overruled.
5. **Workflow improvements** — what to change next run: mis-ordered tasks, wrong model tier,
   missing anchor files, conflicts you did not predict.
6. **Draft PRs** — path to each file.

## What the report is for

The user was not watching. They come back to a branch with commits on it and need to answer three
questions without reading the diff: what landed, what is going to bite me, and what did you decide
on my behalf. Sections 1, 0 and 4 answer those; everything else is supporting detail.

Write it as you go, not at the end. A report assembled from memory after the last task is the one
that quietly drops a blocker.
