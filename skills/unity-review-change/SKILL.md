---
name: unity-review-change
description: >
  Review a change to a Unity project — a working tree, a branch or a pull request — read-only,
  with the triage a general code reviewer cannot do: an asset committed without its `.meta`, a
  scene that had no business changing, a scene the editor re-serialized, project-wide settings
  nobody asked for, a renamed serialized field that silently drops every stored value. Reports
  tagged findings and a SHIP or FIX-FIRST verdict; it never edits, stages, commits or pushes. Use
  when: "review this change", "review this diff", "is this PR ok", "check this branch before I
  merge", "look over these changes", "review my Unity code", "/unity-review-change", or as the
  review step inside `unity-manage-work`.
---

# Unity review change

You read; you do not write. **No edits, no staging, no commits, no branch switching, no pushing,
no `gh pr checkout`, no `gh pr review`.** The output is a message. If something is worth fixing,
name it and let the author fix it.

A Unity diff is not a normal diff. The expensive failures do not look like bugs in any hunk —
they look like a missing file, a file that should not be there, or a rename that compiles
perfectly and quietly empties a value in every scene and prefab that used it. **Extension drives
triage.** Read the file list before you read a line of code.

This skill owns none of the rules it applies; it points a diff at the skills that do —
[`unity-coding-habits`](../unity-coding-habits/SKILL.md) for the C#,
[`unity-scene-habits`](../unity-scene-habits/SKILL.md) for whether a scene should have changed,
[`unity-file-structure-habits`](../unity-file-structure-habits/SKILL.md) for where files belong,
[`unity-multiplayer-habits`](../unity-multiplayer-habits/SKILL.md) for networking, and
[`unity-agent-worker`](../unity-agent-worker/SKILL.md) for whether a claimed verification is
honest. [references/getting-the-diff.md](references/getting-the-diff.md) has the commands and the
greps; [references/by-extension.md](references/by-extension.md) has the per-extension checklist.
**The project outranks all of it** — where the repo documents its own conventions in `CLAUDE.md`,
`CONTRIBUTING.md`, `STRUCTURE.md` or contributor notes, review against those.

## 1. Get the change, and fix the base

Settle one thing first: **what is this being compared against?** Guess wrong and you review
someone else's work. `BASE` is the branch the change merges into — not always `main` — and
three-dot syntax compares against the merge base, so drift underneath stays out of the review.

```bash
BASE=${BASE:-main}
git diff --stat "$BASE...HEAD"
git diff --no-renames --name-status "$BASE...HEAD" | sed -n 's/.*\.\([A-Za-z0-9]*\)$/\1/p' |
  sort | uniq -c | sort -rn
```

That census is the whole reason this skill exists — take it before reading anything. Uncommitted
work, a pull request, and everything scene-aware are in
[references/getting-the-diff.md](references/getting-the-diff.md).

## 2. Triage, in this order — each row costs more when it is wrong than the one below

| In the census | Why it is first | Where |
|---|---|---|
| A `.meta` or asset without its pair | Breaks references for everyone on merge | Step 3 |
| `ProjectSettings/`, `Packages/` | Project-wide, and usually nobody asked | Step 4 |
| `.unity` | One shared file, often untouched by the task | Step 5 |
| `.prefab`, `.asset`, `.mat`, `.controller` | Serialized state — read as data, not code | [references/by-extension.md](references/by-extension.md) |
| `.cs` | Ordinary code review, plus the Unity traps | Step 6 |
| New files anywhere | Placement, before content | Step 7 |

## 3. Pairing — the one that must never ship

Every asset under `Assets/` carries its GUID in a sibling `.meta`. Commit one without the other
and every reference to it becomes `None` on the next person's import — across every scene and
prefab, silently, with nothing in the console pointing here. **Mechanical to detect, and always a
`[BLOCKER]`.** The pairing scan over a commit range is in
[references/getting-the-diff.md](references/getting-the-diff.md); it and the unresolved-GUID scan
belong to
[`unity-agent-worker/references/verification.md`](../unity-agent-worker/references/verification.md).
Do not re-derive them. A hand `mv` or `git mv` of an asset lands here too and is the same
blocker — assets move through `AssetDatabase.MoveAsset`, per `unity-file-structure-habits`.

## 4. Project-wide files

A `ProjectSettings/` change is every branch's change. Ask what in the task required it, and expect
a real answer. Three are blockers on sight: **`ProjectVersion.txt` bumped**, an irreversible
editor upgrade everyone is dragged to; a **`.gitignore`** that starts ignoring `*.meta` or stops
ignoring `Library/`; and **generated files** — `Library/`, `Temp/`, `*.csproj`.
`Packages/manifest.json` is a dependency decision, and tags, layers, input and physics are edited
by index, so inserting a row renumbers what scenes already reference. File by file:
[references/by-extension.md](references/by-extension.md).

## 5. Scenes — two findings, two different answers

**A scene changed at all.** `unity-scene-habits` has the short list of what genuinely needs one —
a new top-level instance, lighting, wiring two instances, the build scene list. Anything else
belongs in a prefab asset, and a scene diff that appeared because a prefab was edited through an
instance is a `[SHOULD-FIX]` with a concrete alternative.

**A scene diff far larger than the change.** That is the editor re-serializing the file, not the
author editing it. The three usual causes — a different editor version opened the project,
lighting or navmesh rebaked, objects nudged by a pixel — and how to tell them apart are in
[`unity-scene-habits/references/scene-scan.md`](../unity-scene-habits/references/scene-scan.md).
Name the one you believe it is; do not accept the file without a cause. Run the cross-branch scan
from that same reference while you are there — **another branch already editing a scene this
change touches goes in the report every time**, not as a finding against the author but because
the reader needs it before merging.

## 6. C#

Review it as code first. Then the Unity reads, by what they cost when missed — the greps for the
first three are in [references/getting-the-diff.md](references/getting-the-diff.md):

- **A renamed serialized field.** `speed` where the base had `moveSpeed`, with no
  `[FormerlySerializedAs("moveSpeed")]`, resets the stored value in every prefab and scene that
  set it — no error, no warning. `[BLOCKER]` when the field is tuned data; same for a retype.
- **New per-frame cost** — a lookup, an allocation, a string compare added inside `Update`,
  `FixedUpdate` or `LateUpdate`. Diff with function context to see which method a hunk is in.
- **A subscribe with no matching unsubscribe.** Count `+=` against `-=` in the added lines; a
  static event never detached outlives the scene.
- **Networked code** — authority and direction: who may call this, does the server re-validate it,
  is a late joiner served by a SyncVar rather than an RPC. Defer to `unity-multiplayer-habits`;
  these fail silently and only with two clients.
- **Drive-by restyling** in code the task merely passed through makes a diff unreviewable. Say so
  rather than reviewing those hunks.

## 7. Placement

For every added file: does it sit where this project puts that kind of thing? `STRUCTURE.md` is
the authority, a sibling of the same kind is the next answer, and `Editor/`, `Resources/`,
`StreamingAssets/` and `Plugins/` change what compiles and ships — `unity-file-structure-habits`
has all three. A new folder missing from `STRUCTURE.md` is a `[SHOULD-FIX]`: that is how a layout
drifts.

## 8. Write the findings

If the session offers a structured findings or review tool, use it. Otherwise plain text, in this
shape — the tags `unity-manage-work` already reviews with:


```
[BLOCKER] Assets/Prefabs/Crate.prefab — committed without Crate.prefab.meta. Every reference
  to it resolves to a new GUID on everyone else's import.
[SHOULD-FIX] Assets/Scripts/Inventory/Slot.cs:42 — `stackSize` was `count` on the base; no
  [FormerlySerializedAs("count")], so values tuned in prefabs reset to the default.
[NITPICK] Assets/Scripts/Inventory/Slot.cs:88 — `Awake` could hold this lookup.

Verdict: FIX-FIRST
Not verified: nothing was run — behaviour, play mode and the build are unchecked.
```

**`file:line` on everything that has a line**, the file alone when it does not: a finding without
a location is not actionable, and one without a fix you would accept — "move this to a prefab
edit" rather than "this should not be here" — is barely better.

**`[BLOCKER]`** breaks the project for other people on merge or destroys data silently, and forces
**FIX-FIRST**. **`[SHOULD-FIX]`** is a real bug or cost contained to this change; on its own the
verdict is a judgement call, so say which findings decided it. **`[NITPICK]`** is preference,
never decides the verdict, and stops at two or three — a long tail buries what mattered.

## 9. Do not manufacture findings

A clean change gets **SHIP** and a short list of what you checked. Say it plainly — a reviewer
that always finds something is one people learn to skim, and then the blocker goes through too.
`unity-manage-work` puts it the same way: if quality is good, accept and move on. Padding takes
three forms and they are one mistake: promoting a nitpick to get a `[SHOULD-FIX]` on the board,
reviewing code the change only passed through, and restating a rule the change already follows.
Something checked and fine is a line in "what I checked", not a finding.

## 10. Say what you did not verify

A review reads text. On a project with no automated tests — most game projects — that proves
nothing about behaviour, and a confident verdict reads as though it did. Close with the limits:

- **Nothing was run** — no editor, no play mode, no build — and scenes and prefabs were read as
  YAML rather than opened, so anything that only shows in the inspector is unchecked.
- **The pairing scan covers this diff**, not pre-existing breakage; the unresolved-GUID scan needs
  a warm `Library/` and reports candidates, not a verdict.
- **Never write "verified" or "tested"** for a project with no tests. State the rung reached per
  [`unity-agent-worker/references/verification.md`](../unity-agent-worker/references/verification.md)
  and what is still unproven.

**SHIP is not sign-off.** Inside `unity-manage-work` this is Step 6; a person still runs the
manual checklist in Step 6a, and that gate blocks whatever the verdict was. Standalone, say the
same to the user: what a reviewer can see is fine, and someone still has to play it.
