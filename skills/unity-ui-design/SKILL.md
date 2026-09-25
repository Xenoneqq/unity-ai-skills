---
name: unity-ui-design
description: >
  Design and build game UI in Unity that belongs to this game, not to a template or to its
  genre's clichés: ground the look in the game's art and fiction, plan a small token system,
  check it against the usual tells, prove it in an HTML mockup the developer approves, then build
  it in the toolkit the project already uses and capture it at several aspect ratios. Use when:
  designing or restyling a HUD, main menu, pause menu, inventory, shop, dialogue box or any
  in-game screen; "design the UI", "make the menus look better", "our HUD looks generic", "mock
  up the inventory", "restyle this screen", "/unity-ui-design".
---

# Unity UI design

Approach this as the UI lead on a game whose art director has already sent two passes back:
one for looking like a Unity template, one for looking like every other game in its genre. They
want a UI a player would recognise from a single cropped screenshot. Make deliberate choices
about palette, type, layout and motion that come from this game, and take a risk where it earns
its place.

Two things outrank everything in this file. **The project's existing UI and art direction**: if
the game already has a look, extend it, do not replace it. **The developer's brief**: where it
pins a direction, follow it exactly, including when it asks for something this file calls a
cliché.

One principle is specific to games. **Be distinctive in look, conventional in behaviour.**
Players carry habits between games: the minimap in a corner, cancel on the east face button,
confirm where the platform puts it, health where the genre puts it. Moving those costs the
player, and it buys nothing. Spend the originality on how things look and feel, not on where
they are or which button does what.

## 1. Probe the project

```bash
PV=$(find . -path '*/ProjectSettings/ProjectVersion.txt' -not -path '*/Library/*' -print -quit)
ROOT=$(dirname "$(dirname "$PV")")
REPO=$(git rev-parse --show-toplevel)
awk '/^m_EditorVersion:/{print "editor        : "$2}' "$PV"
awk '/activeInputHandler/{print "input handler : "$2"  (0 legacy, 1 Input System, 2 both)"}' \
  "$ROOT/ProjectSettings/ProjectSettings.asset"
grep -oE '"com\.unity\.(ugui|textmeshpro|inputsystem|localization)"' "$ROOT/Packages/manifest.json"
echo "uGUI canvases:"; grep -rl '^--- !u!223 ' "$ROOT/Assets" --include=*.prefab --include=*.unity | head
echo "UI Toolkit:";    find "$ROOT/Assets" \( -name '*.uxml' -o -name '*.uss' -o -name '*.tss' \) | head
echo "fonts:";         find "$ROOT/Assets" \( -iname '*.ttf' -o -iname '*.otf' -o -name '*SDF*.asset' \) | head
ls "$REPO/UI_STYLE.md" "$REPO/ui-mockups" 2>/dev/null
```

Grepping `!u!223` (the Canvas class id) only reads the files. Never edit scene or prefab YAML by
hand; see `unity-scene-habits`. `com.unity.ugui` sits in most manifests whether or not anything
uses it, so the canvases are the signal, not the package. From Unity 6, TextMeshPro ships inside
`com.unity.ugui` rather than as its own package.

**Pick the toolkit.**

| What the probe found | Build with |
|---|---|
| Only uGUI canvases | uGUI |
| Only UXML and USS | UI Toolkit |
| Both | Whatever the neighbouring screens use. Never migrate a screen as a side effect. |
| Neither, editor 6.0 or newer | UI Toolkit |
| Neither, older editor | uGUI |

UI Toolkit is the default for new projects because its tokens are real (USS variables), its
screens are text files an agent can write and a reviewer can read, and it keeps UI out of the
prefab and scene YAML that conflicts. Runtime UI Toolkit exists from 2021.2, but it matured in
6.x, and on older LTS editors uGUI's ecosystem is the safer bet. Other Unity skills, Unity's own
among them, may default to uGUI instead; this one chooses UI Toolkit on purpose, and a developer
who prefers uGUI outranks both.

Reach for uGUI even in a UI Toolkit project for diegetic or world-space UI when the project's
editor has no world-space panels (recent 6.x releases add them, so check the version), and for UI
that must be driven by Animator or Timeline or needs custom shaders or particles inside it. Mixed
is normal: UI Toolkit menus with uGUI name plates over characters.

**`UI_STYLE.md` exists?** It is the plan. Read it, build to it, and skip to step 5. Change it only
when the brief asks for a new direction, and say so.

## 2. Ground it in the game

Before any colour, know what the UI is for. If the brief or the project does not say, propose it
and confirm with the developer:

- **The game.** Genre, fiction, art style, camera, pacing. Is the player reading this mid-combat
  or sitting in a menu with a coffee?
- **The platforms and inputs.** PC with mouse, gamepad, touch, TV at couch distance, handheld.
  Each one changes minimum sizes and how focus works.
- **The screen's one job.** A HUD tells the player one or two things at a glance. An inventory
  lets them compare and decide. A title screen sets the tone.
- **Where it sits in the fiction.** For each element: diegetic (exists in the world, like an ammo
  counter on the gun), spatial (in the world, not in the fiction, like a waypoint), meta (on
  screen, in the fiction, like blood on the lens) or plain overlay. Deciding this per element is
  where much of a game UI's character comes from.

Distinct choices come from the game's own material: the objects in its world, its core mechanic,
the palette and brushwork of its key art, the way its characters would write things down. A
cooking game's order queue can be kitchen tickets. A heist game's map can be a blueprint. Ask
for key art or a gameplay screenshot; if there is one, it is the backdrop for everything below.

## 3. Plan, then check the plan

Write the plan as `UI_STYLE.md` at the repo root, beside `STRUCTURE.md` if the project has one.
It outlives this task: every later screen reads it first, which is what keeps forty screens
looking like one game. Keep it short:

- **Palette.** 4 to 6 named hex values with roles (ink, surface, accent, danger, highlight). Say
  how text stays readable over the game world: outline, backplate, shadow or a darkened region.
  The background is not a page colour, it is the game, and it moves.
- **Icons.** Where they come from and one style for all of them. If the game's sprites are
  generated, make the icons the same way, in the same palette (`unity-pixel-art` for pixel art),
  so a key or a health pack on the HUD looks like the one in the world.
- **Type.** One or two families, with roles. A size scale in pixels at the reference resolution,
  and the smallest size allowed on each target platform. Console and TV guidelines set a minimum
  text size; look up the platform's current number rather than guessing one.
- **Layout.** Reference resolution and match mode, safe-zone margins, and an ASCII wireframe of
  the HUD and each major screen. Say which corner owns what and why.
- **Motion and sound.** The feedback vocabulary: what a press, a confirm, a back, an error and a
  reward look and sound like, with durations. Menus stay fast and never block input while
  animating.
- **The signature.** The one bold thing. See step 7.
- **Principles.** Two or three sentences on what makes this game's UI its own.

Then review the plan before building. Read [references/tells.md](references/tells.md) and hold
the plan against it. Then run the swap test: replace the game's name with another game in the
same genre. If the plan still fits, it is the genre default, not a choice. Revise those parts
and tell the developer what you changed and why. The brief's own words still win: if it asks for
parchment and gold, that is a choice, not a tell.

## 4. Mock it up and get a go-ahead

Before touching Unity, build the screen as a single self-contained HTML file in `ui-mockups/` at
the repo root, outside `Assets/` so Unity never imports it. It iterates in seconds where the
editor takes minutes, and it lets the developer react to the look before anything is wired.
[references/mockup.md](references/mockup.md) has how to build it so it translates straight into
the toolkit: reference-resolution stage, aspect and backdrop toggles, the element states side by
side, and only what the toolkit can actually render.

Open it for the developer, ask for a go-ahead or changes, and iterate there. Look at it yourself
too, taking a screenshot if the environment can. Do not start step 5 until the developer has
said the mockup is the direction. Once approved, the mockup is the spec: the build matches it,
and a deviation the toolkit forces gets said out loud.

## 5. Build it

Tokens first, screens second. Put the palette, type and spacing in the toolkit's own theme
before the first screen, so no screen hard-codes a colour.

- **UI Toolkit:** [references/ui-toolkit-build.md](references/ui-toolkit-build.md)
- **uGUI:** [references/ugui-build.md](references/ugui-build.md)

Either way, `unity-scene-habits` governs the editor work: every screen and widget is a prefab,
the scene stays out of the diff, and the editor is the only writer of scene, prefab and `.meta`
files. `unity-file-structure-habits` decides where the files go. `unity-coding-habits` covers the
controller scripts, notably not rebuilding a label's string every frame.

Build to the quality floor without announcing it. The full checklist is in
[references/readability.md](references/readability.md). The parts most often missed:

- Every interactive element has designed normal, hover, selected, pressed and disabled states,
  and selected is obvious from across a room.
- The screen works with a gamepad alone: something is focused when it opens, navigation goes
  where the eye expects, and back always backs out.
- Real data at the extremes: 0 and 9,999,999 gold, the longest item name, an empty inventory, a
  full one, a German translation 30% longer than the English.
- Anchored to the edges it belongs to, inside the safe area, at every aspect ratio the game
  ships on.
- Pause menus animate on unscaled time, or they freeze with the game.

## 6. Capture and critique

Capture the built screen at several aspect ratios over a bright and a dark backdrop, then look
at the images against the mockup and the plan. [references/capture.md](references/capture.md) has
the matrix and the recipes.

Capturing needs a working editor, a licence and sometimes Play mode, so it will not always be
possible. That is fine. When you cannot capture, say so plainly, and hand the developer the
short checklist in [references/capture.md](references/capture.md) so they know exactly what to
look at. Never describe a screen as looking right when you have not seen it.

## 7. Restraint

Spend the boldness in one place. On most games that is the title screen or one signature element
tied to the core mechanic. The HUD is where restraint pays most: the player is looking at the
game, not at the UI, and every always-on element taxes their attention. Show information when it
becomes relevant and let it recede after.

Motion in games is expected where it answers the player: a press, a hit, a reward, a level-up.
Idle motion is not. A HUD that pulses, glows or bobs while nothing is happening competes with the
game for the player's eye. One orchestrated moment on the title screen lands better than an
entrance animation on every panel.

Before calling it done, take one thing away.

## 8. Words

Words on screen exist to help the player understand and act. Two voices, never mixed:

- **The fiction's voice** where the player is reading the world: item descriptions, lore, NPC
  lines, quest text.
- **Plain voice** everywhere the player is operating the game: menus, settings, save and load,
  purchases, errors. "Quit to Title", not "Abandon Your Quest".

A button says what happens: "Load Game", not "OK". The action keeps its name through the flow, so
"Craft" produces "Crafted". Anything irreversible names its consequence before it happens:
"Overwrite Slot 2? The old save is lost." Button prompts use the input glyph of the active
device, not the word "Press A". Where a platform's certification rules dictate wording, such as
for a disconnected controller or corrupt save data, those rules win.

## 9. Report

End with:

- What was built, in which toolkit, and where the files are.
- Where the tokens live, and whether `UI_STYLE.md` was created or changed.
- The mockup's path, and anything in the build that differs from it and why.
- Which checks were captured and looked at, and which are left for the developer. Name them.
- Anything loose in a scene the task touched, and any other branch editing the same scene, per
  `unity-scene-habits`.
