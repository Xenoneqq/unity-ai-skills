# Commits, branches and pull requests

How changes to this repo are named and described. It applies to people and to skills alike: a
skill in here that writes a commit or a PR reads this file and follows it over its own defaults.

## Branches

One branch per change, named for the whole change in kebab-case. Name what it all adds up to,
not the first step you happen to take. No ticket ids, no author prefixes.

Good: `scene-structure-skill-and-references`. Not: `fix`, `mp/docs-2`, `wip`.

## Commits

A commit is one finished chunk of work that passes the gate. Not one per file, not one per
step, not one giant commit at the end. Never commit with the gate red.

The subject is a short plain sentence in lowercase, saying what changed. Write it the way you
would tell a teammate, not the way the diff reads.

- Plain words, no scope prefixes, no ticket ids, no file names, no mechanics.
- Start with the verb: add, move, handle, document, fix.
- One line. If it needs an "and" to cover everything, it is probably two commits.

The body is optional. Add one only when the subject does not tell the whole story: several
things landed together, or the reason is not obvious. Keep it to a few short bullets in the same
plain register. No paragraphs.

Trailers such as `Signed-off-by` or `Co-Authored-By` go after a blank line at the end. They
are metadata, not part of the message.

Two examples:

```
turn the repo into an installable plugin
- the manifests and the contributor notes land together, since neither is useful alone
- skills come next, so the readme table is empty on purpose
```

```
add a skill that plans where new scripts and assets go in a project
```

## Pull requests

The title is a concise imperative or noun phrase that says what the branch does. No ticket ids,
no PR numbers.

The body is short. Most PRs need ten to twenty-five lines, a trivial one needs four. It has
two sections, in this order:

| Section | What goes in it |
|---|---|
| Summary | One or two plain sentences: what the branch adds or fixes and why it matters. |
| Changes | A few bullets, one per important change, written for a reviewer skimming on a phone. Not a tour of the diff. |

There is no testing section. This repo is skills and notes; the gate in CONTRIBUTING.md is the
whole verification and every PR is expected to have passed it.

Describe what the branch does for a person, not how it is wired. Cover the branch, not the
conversation that produced it. Never sign the body as AI-written and never add a "generated
with" footer; a trailer the repo requires is metadata, not attribution.

Nothing in this repo pushes, merges or opens a PR on its own. The skills write the draft to a
file and the author opens the PR.
