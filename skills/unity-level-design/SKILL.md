---
name: unity-level-design
description: >
  Design and build game levels in Unity that play well and look lived-in rather than generated:
  measure the player's real metrics first, give the level a job and a beat structure, offer a
  top-down HTML paper map when it would help, block it out in greybox as prefabs, prove the
  critical path is reachable, then dress it with deliberate irregularity instead of perfect grids
  and uniform spacing. Use when: designing, blocking out, greyboxing or dressing a level, map,
  arena, room, dungeon or encounter space; "make a level", "build a test map", "block out this
  area", "the level feels empty", "this looks too clean", "place props around", "set dress this",
  "/unity-level-design".
---

# Unity level design

Approach this as a level designer whose lead has already sent back one pass because it looked
like the output of a generator: every crate square to the grid, rooms as boxes joined by
identical corridors, props spaced like fence posts, the goal visible from the spawn. They want a
space that teaches the player something, leads them without a single sign, and looks like
people, weather or time have been through it.

Two things outrank everything in this file. **The project's existing levels, kit and metrics**:
if the game already has a way of building spaces, extend it. **The developer's brief**: where
it pins something down, follow it exactly, including a perfectly regular layout if that is what
it asks for.

One principle carries most of the visual quality. **Build on the grid, dress off it.**
Architecture and modular kit pieces snap to the grid: that is what keeps seams closed, floors
walkable and metrics exact. Everything that lives in the space afterwards (props, debris,
foliage, furniture, decals, lights) is placed the way a person or the world would have left it:
slightly turned, clustered, leaning, worn, never in rows unless someone put it in rows.
[references/dressing.md](references/dressing.md) has the rules and the ranges.

How much disorder is right depends on the game. A Sokoban puzzle, a grid tactics map, a tiled
2D platformer, a military depot or a temple are meant to be orderly, and the grid is the design.
Decide which kind of game this is in step 3 and write it down, so dressing does not fight it.

## 1. Probe the project

```bash
PV=$(find . -path '*/ProjectSettings/ProjectVersion.txt' -not -path '*/Library/*' -print -quit)
ROOT=$(dirname "$(dirname "$PV")")
REPO=$(git rev-parse --show-toplevel)
awk '/^m_EditorVersion:/{print "editor : "$2}' "$PV"
grep -oE '"com\.unity\.(probuilder|ai\.navigation|splines|terrain-tools|2d\.tilemap[a-z.]*|render-pipelines\.[a-z]+)"' \
  "$ROOT/Packages/manifest.json"
echo "scenes:";  find "$ROOT/Assets" -name '*.unity' -not -path '*/ThirdParty/*' | head -20
echo "player:";  grep -rlE 'CharacterController|Rigidbody2?D?' "$ROOT/Assets" --include=*.prefab | grep -i player | head
ls "$REPO/LEVEL_METRICS.md" "$REPO/level-plans" 2>/dev/null
```

Reading prefab and scene files with `grep` is fine; editing them by hand is not. Everything that
changes a scene or prefab goes through the editor, per `unity-scene-habits`.

Find out, and ask where the project does not say:

- **2D or 3D, and the camera.** First person, third person, top-down, side-on, isometric. The
  camera decides what the player can see, which decides almost every layout rule.
- **The player controller.** Its prefab, collider and movement script. Step 2 reads the numbers
  from it.
- **Existing levels.** How they are built (a modular kit, ProBuilder, Terrain, Tilemaps, bespoke
  meshes) and how they are split into scenes and prefabs. A new level matches them.
- **Tools installed.** ProBuilder for blockout, AI Navigation for reachability, Splines for roads
  and rivers, Tilemap for 2D. Adding a package is the developer's decision; ask first. For a 3D
  blockout without ProBuilder, offer it once unless the user already declined it at setup, in
  one line: textures that line up, real doorways
  and fewer objects, against larger prefab files.

## 2. Metrics before geometry

A level built at the wrong scale cannot be fixed by dressing. Before placing anything, write down
the player's real numbers in `LEVEL_METRICS.md` at the repo root, next to `STRUCTURE.md` if there
is one. Every level reads it; a level that disagrees with it is the bug.

Read them from the game, not from memory of other games: the collider's height and radius, step
offset and slope limit, move and sprint speed, and jump height and distance from the movement
script. When the script gives a jump velocity and gravity, compute the apex as `v² / (2g)` and
show the working. Derive the rest (door and corridor widths, cover heights, the longest gap the
player can clear, the highest ledge they can reach) as ratios of those. Every jump and ledge is
either clearly makeable or clearly not; nothing sits at the edge of what the player can do.
[references/metrics.md](references/metrics.md) has the ratios and what changes per camera.

If the game has no player yet, say so, propose metrics for its genre, and mark them as
provisional in the file.

## 3. Give the level a job

Before any layout, know what the level is for. Answer these for yourself from the brief and the
project:

- **Its place in the game.** What the player can do on arrival, what they can do on leaving, and
  what the level exists to teach, test, reveal or let them rest from.
- **One idea.** The mechanic or situation the level is built around. Beats are usually that idea
  introduced safely, developed, twisted, then tested in a conclusion. A beat chart of intensity
  over time shows whether the level breathes or only escalates.
- **The critical path and what hangs off it.** The one route to the exit, the optional spaces
  and what rewards them, the loops and shortcuts that bring the player back.
- **The place.** What this location is in the fiction, who built it, what happened here and what
  is happening now. The answers decide the dressing in step 7.
- **Order or disorder.** How regular this place should look, from the list above.
- **Duration and size.** Minutes of play, and roughly how big, checked against the metrics.
  Start smaller than feels right. Growing a space later is easy; a space too big to fill is the
  commonest layout problem.

Write it as `level-plans/<level>.md` at the repo root. It is the brief every later pass is
checked against.

**How much to ask depends on how the developer asked.** "Just make the level" means make it:
fill the gaps with your own best answers, write them in the plan so they can be changed later,
and go. Stop to ask only when an answer would change the level so much that guessing wrong
wastes the work, such as the camera or the player's scale when neither exists yet. When the
developer wants a say in the design, walk them through the plan before building.

## 4. Check the plan, and offer a map

Whatever the developer asked for, review the layout idea against
[references/tells.md](references/tells.md) before building. Run the swap test: if this layout
would work unchanged for any other level of the same genre, it has no idea of its own yet.
Revise it. When you are working with the developer, tell them what you changed and why.

Then, unless they asked you to just build it, offer a **paper map**: a top-down layout as a
single HTML file in `level-plans/<level>.html`, outside `Assets/` so Unity never imports it.
It changes in seconds, and it lets the developer redirect the layout before any blockout
exists. Offer it in one line and move on if they decline. It pays off most for levels built
around a route, beats or encounters. It pays off least for very large or open maps, where one
drawing cannot hold the whole thing; there, offer to map just the area being built.
[references/paper-map.md](references/paper-map.md) has what the map shows and how to build it.

A map can also help you even when nobody asked for one: laying out the critical path and the
beats at scale is a fast way to catch a layout that does not work. Draw it for yourself when it
helps, and mention it in the report. When the developer did accept the map, wait for their
go-ahead before step 5.

## 5. Block it out

Build the map in greybox: untextured geometry at exact metric scale, a grid material that shows
metres, and simple colours for meaning (walkable, climbable, hazard, goal). No props, no dressing,
and only rough lighting: enough to see, and a first pass at lighting the way on (step 8).
[references/blockout.md](references/blockout.md) has the Unity side.

The level is a scene, but the scene should hold as little as possible, per `unity-scene-habits`:
each area of the level is a prefab, the scene places them and holds the lighting and environment
settings, which have nowhere else to go. Two people can then work on two areas without touching
the same file. Split into additive scenes only when there is a concrete reason, such as streaming
or genuinely parallel work, because the loading code that comes with it tends to grow.

Snap everything in the blockout to the grid. Irregularity comes later, in dressing, and never
changes a metric.

## 6. Prove it plays

Before any dressing, check the blockout:

- **Reachability.** Every beat, pickup and the exit can be reached from the spawn, and nothing
  the level expects the player to cross is wider or higher than the metrics allow.
- **Sightlines.** Captures from the player's eye height at the spawn and at each beat show the
  next goal or landmark, and hide what the level means to reveal later.
- **The top-down view** matches the plan, and the paper map if there is one.
- **The critical path stands alone.** Take the optional areas away in your head: the level still
  works, and nothing on the path is a long dead end.
- **It can be finished.** Where the game has a player controller that tests can drive, an
  autopilot plays the level from spawn to exit with the real controller and the real doors,
  keys and triggers. It catches what a navmesh query cannot: a ledge the controller will not
  climb, a trigger that never fires.

[references/verification.md](references/verification.md) has the automated reachability check
and the capture recipes. When something cannot be checked from here, say so and give the
developer the playtest checklist from that file. A blockout is proven by someone walking it in
Play mode, at the player's height, with the real controller, never by flying round the editor
camera. Say plainly that it has not been played yet if it has not.

## 7. Dress it

Only once the blockout plays. Swap greybox for the project's kit, then dress according to the
place from step 3: who was here, what they did, what broke. Follow
[references/dressing.md](references/dressing.md):

- Clusters with a reason, not scatter. Big, medium and small together; odd numbers; a gap for the
  eye to rest in.
- Every prop rests on something. Nothing floats, nothing sinks through a floor.
- Small, varied offsets in rotation, position and scale on anything a person or the world placed.
  Seeded, so re-running the script gives the same level.
- Density follows use: paths are clear where people walk, clutter collects in corners, along
  walls and where work happens.
- Dressing never changes gameplay. Cover heights, jump gaps, doorways and the critical path keep
  their metric values; rerun step 6 after dressing to prove it.

## 8. Light and guide

Light is the strongest guide the level has, so start it in the blockout rather than after the
art. Work in passes: overall light, then the way on, then encounters, then mood.

- **The way on is the brightest thing in view**, lit from a source the player can see: a
  window, a lamp, a fire. Never light a dead end brighter than the exit.
- **Show the goal before the path.** Let the player see where they are going, lose sight of it,
  then find it again closer and from a new angle.
- **Landmarks** stay visible from far away and give the player something to steer by. A big
  level needs one in view almost everywhere.
- **Players rarely look up.** Anything above eye level needs movement, sound or light to be
  noticed.
- **Enemies and pickups are breadcrumbs.** Where they sit tells the player where to go.
- **Lines in the architecture help, but only as support.** Players look elsewhere more than a
  screenshot suggests; the layout itself has to lead.
- **Colour language stays consistent**: whatever the game uses for climbable, breakable or
  interactive surfaces means only that.

Lighting is scene data, so it is one of the few things that belong in the scene rather than a
prefab.

## 9. Keep it cheap to run

A level that plays well and runs badly is not done. Mark non-moving geometry static, use simple
primitive colliders on props instead of mesh colliders, give large meshes LODs, and bake
navigation and lighting when the level changes. Details are in
[references/blockout.md](references/blockout.md). `unity-debug-runtime` covers profiling when a
level is slow.

## 10. Report

End with:

- The level's job and beats in two or three lines, and where the plan is, and the map if one
  was made.
- Any gap in the brief you filled with your own answer, so the developer can change it.
- What was built: scenes, area prefabs, and whether `LEVEL_METRICS.md` was created or changed.
- Which checks ran and passed, which ran and failed, and which are left for a playtest. Name
  them.
- Anything in the dressing that knowingly departs from the plan, and why.
- Any other branch editing the same scene, per `unity-scene-habits`.
