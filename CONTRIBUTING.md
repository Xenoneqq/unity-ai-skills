# Working on this repo

This repo *is* a Claude Code plugin. People install it; the skills in `skills/` are the product.
It is not a Unity project and never contains one. No `Assets/`, no `ProjectSettings/`, no
`.meta` files. Anything Unity-specific in here is text a skill reads.

## Layout

```
.claude-plugin/plugin.json       plugin manifest
.claude-plugin/marketplace.json  marketplace entry (single plugin, source ".")
skills/<name>/SKILL.md           one directory per skill
skills/<name>/references/*.md    optional detail a skill reads on demand
```

A plugin only loads `commands/`, `agents/`, `skills/`, `hooks/` and `.mcp.json`. **This file is
not shipped to anyone who installs the plugin.** It only guides work in this checkout. Anything
users need to reach belongs in a skill.

These notes live in `CONTRIBUTING.md` rather than `CLAUDE.md` on purpose: `claude plugin validate`
warns about a `CLAUDE.md` at a plugin root, because it is never loaded as context and reads like
an attempt to ship one. Keep the plugin root free of it.

Commit messages, branch names and PR descriptions follow [CONVENTIONS.md](CONVENTIONS.md).

## The gate

Run all three after any change, and never commit a red one:

```bash
claude plugin validate . && claude plugin validate .claude-plugin/plugin.json && claude plugin validate skills
```

To prove a change end to end, install into a throwaway config directory so your own setup is
untouched, and check the inventory:

```bash
CLAUDE_CONFIG_DIR=$(mktemp -d) sh -c 'claude plugin marketplace add "$PWD" >/dev/null && claude plugin install unity-ai-skills@unity-ai-skills >/dev/null && claude plugin details unity-ai-skills'
```

## Adding or editing a skill

- One directory under `skills/`, one `SKILL.md`, frontmatter `name` matching the directory.
- The `description` decides when the skill fires. Write it as trigger phrases a user would
  actually say, not as a summary of the contents.
- Add it to the README, in whichever of its tables matches what the skill is for.
- Keep `SKILL.md` to what every run needs. Detail that only some runs need, such as a prompt
  template, a runbook or a per-case spec, goes in `references/<topic>.md`, and `SKILL.md` says
  which step reads it. A reference under about 30 lines is not worth the extra read; keep it
  inline.

## House rules for skill content

- **Nothing private.** No real names, employers, product names, repo names, ticket ids, URLs, or
  paths from a specific project. Examples must be invented and generic.
- **The user's project outranks the skill.** Where a Unity project documents its own layout,
  assembly definitions, naming or commit conventions, the skill says to follow those and treats
  its own defaults as the fallback.
- **Works across Unity versions.** Do not pin behaviour to one editor release. Where a version
  matters, such as a package, an API that moved or a render pipeline, the skill says to check
  the project's version rather than assuming one.
- **Never touches generated or engine-owned state.** No editing `.meta` files by hand, no
  hand-writing scene or prefab YAML, no `Library/` surgery. A skill that needs those says to do
  it through the editor.
- **Nothing goes out without being asked.** No skill here pushes, merges, opens a PR, or files an
  issue. Drafts are written to files the user publishes themselves.
- **Cross-references stay inside the plugin.** A skill may point at another skill in `skills/`.
  It must not depend on a skill that only exists in someone's personal skills directory.
- Keep prose wrapped near 96 columns to match the existing files.
