# Getting the diff, and reading it

Everything here is read-only. Nothing checks out, stages, fetches into the working tree, or
writes a ref you did not already have.

## The three shapes a review arrives in

**Uncommitted work in the tree.** What the user means by "review my change" when they have not
committed yet:

```bash
git status --short
git diff                 # unstaged
git diff --staged        # staged
git diff HEAD            # both, against the last commit
```

**A branch.** Set `BASE` to the branch it will merge into and use three-dot syntax, which
compares against the merge base rather than the tip — so unrelated commits on `BASE` stay out of
your review:

```bash
BASE=${BASE:-main}
git fetch --quiet --all
git log --oneline "$BASE...HEAD"
git diff --stat "$BASE...HEAD"
```

**A pull request.** Never `gh pr checkout` — it moves the user's working tree. Read it instead:

```bash
gh pr view <n> --json title,body,baseRefName,headRefName,author,isDraft
gh pr diff <n> --name-only
gh pr diff <n> --patch > /tmp/pr.diff
```

`gh pr diff` gives you the patch but not the objects, so none of the scene-aware commands below
work on it. To get those, fetch the head ref without creating a branch and diff against
`FETCH_HEAD`:

```bash
git fetch origin "refs/pull/<n>/head"      # GitHub; the ref name differs on other hosts
BASE=$(gh pr view <n> --json baseRefName -q .baseRefName)
git diff --stat "origin/$BASE...FETCH_HEAD"
```

Substitute `FETCH_HEAD` for `HEAD` everywhere below.

## The census

Extensions first, contents second:

```bash
git diff --no-renames --name-status "$BASE...HEAD" | sed -n 's/.*\.\([A-Za-z0-9]*\)$/\1/p' |
  sort | uniq -c | sort -rn
git diff --no-renames --name-status "$BASE...HEAD" -- 'ProjectSettings' 'Packages'
```

**`--no-renames` is not optional.** With rename detection on — the default — an asset moved
without its `.meta` shows as a clean `R100` and the pairing scan below sees nothing wrong.

## Pairing, over a commit range

The scans in
[`unity-agent-worker/references/verification.md`](../../unity-agent-worker/references/verification.md)
read the working tree, which is empty once the work is committed. This is the same check over a
range. Silence is a pass; any line is a `[BLOCKER]`:

```bash
BASE=${BASE:-main}
git diff --no-renames --diff-filter=A --name-only -z "$BASE...HEAD" | while IFS= read -r -d '' f; do
  case "$f" in
    *.meta) git cat-file -e "HEAD:${f%.meta}" 2>/dev/null || echo "meta without its asset  : $f" ;;
    *)      git cat-file -e "HEAD:$f.meta"    2>/dev/null || echo "asset without its .meta : $f" ;;
  esac
done
git diff --no-renames --diff-filter=D --name-only -z "$BASE...HEAD" | while IFS= read -r -d '' f; do
  case "$f" in
    *.meta) ;;
    *) git cat-file -e "HEAD:$f.meta" 2>/dev/null && echo "asset gone, meta kept   : $f.meta" ;;
  esac
done
```

For breakage the pairing check cannot see — a reference to a GUID nothing declares — run the
unresolved-GUID scan from that same file, **on the base branch as well**, so only the new
unresolved GUIDs count against this change.

## Scenes and prefabs

**Is the diff proportionate?** A file that changed almost everywhere was re-serialized, not
edited:

```bash
git diff --numstat "$BASE...HEAD" -- '*.unity' '*.prefab' | while read -r add del f; do
  [ "$add" = "-" ] && { echo "binary: $f"; continue; }
  total=$(git show "HEAD:$f" 2>/dev/null | wc -l | tr -d ' ')
  echo "+$add -$del of ${total:-0} lines   $f"
done
```

**Which objects did it touch?** Scene and prefab YAML is keyed by file id, so a hunk tells you
nothing by itself. Map each hunk back to the nearest `m_Name:` above it:

```bash
F=Assets/Scenes/Example.unity
L=$(git diff -U0 "$BASE...HEAD" -- "$F" | awk '/^@@/{split($3,a,","); print substr(a[1],2)}' | tr '\n' ' ')
git show "HEAD:$F" | awk -v L="$L" '
  BEGIN { n = split(L, ls, " "); for (i = 1; i <= n; i++) want[ls[i] + 0] = 1 }
  /^ *m_Name:/ { name = substr($0, index($0, ":") + 2) }
  want[NR] { printf "%8d  %s\n", NR, (name == "" ? "(no m_Name above)" : name) }'
```

A hunk that only deletes lines reports the line above itself — close enough to identify the
object, one off as a line number.

**What does it now reference?** Every GUID in the added lines, then what each one is:

```bash
git diff -U0 "$BASE...HEAD" -- '*.unity' '*.prefab' |
  grep -E '^\+' | grep -oE 'guid: [0-9a-f]{32}' | sort -u
grep -rl '<the guid>' --include='*.meta' Assets | head
```

A GUID that no `.meta` under `Assets/` declares is either a package asset — those declare under
`Library/PackageCache`, which needs a warm `Library/` — or a broken reference.

**What components were added?** A new `m_Script:` line is a component attached to a scene or
prefab object:

```bash
git diff -U0 "$BASE...HEAD" -- '*.unity' '*.prefab' | grep -E '^\+.*m_Script: '
```

## C#

Diff with whole-function context, so you can see which method a hunk landed in rather than
guessing from three lines either side:

```bash
git diff -W "$BASE...HEAD" -- '*.cs'
```

Serialized fields added, removed or renamed — a `-` line with no matching `+` and no
`FormerlySerializedAs` is a dropped value:

```bash
git diff -U0 "$BASE...HEAD" -- '*.cs' | grep -E '^[-+].*(SerializeField|FormerlySerializedAs)'
```

Event subscriptions in the added lines. The trailing `;` keeps arithmetic like
`position += velocity * dt;` out of the results; check each `+=` has its `-=`:

```bash
git diff -U0 "$BASE...HEAD" -- '*.cs' | grep -nE '^\+.*[+-]= *[A-Za-z_][A-Za-z0-9_.]*; *$'
```
