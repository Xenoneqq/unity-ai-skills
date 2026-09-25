# Player metrics

Metrics are the sizes the whole level is built from. They come from the game's own player, not
from habit, and they live in `LEVEL_METRICS.md` so every level uses the same ones.

## Reading them from the project

- **Collider.** A `CharacterController` gives `height`, `radius`, `stepOffset` and `slopeLimit`
  directly. A capsule on a `Rigidbody` gives height and radius; step and slope handling then
  live in the movement script. Player width `W` is twice the radius; height `H` is the collider
  height.
- **Movement.** Read walk and sprint speed, jump velocity or jump height, gravity, and any air
  control from the movement script's serialized fields, and from the prefab's values for them,
  which win over the script defaults.
- **Jump apex.** From a jump velocity `v` and gravity `g`: `h = v² / (2g)`. From a jump height,
  the velocity is `v = √(2gh)`. Remember `Physics.gravity` is negative, and some controllers
  multiply it.
- **Jump distance on the flat.** Air time is `2v / g`, and distance is horizontal speed times air
  time. Air control, coyote time and jump buffering change what players actually manage, so when
  the numbers matter, measure a real jump in Play mode rather than trusting the formula.
- **Camera.** Eye height and field of view for first person; boom length, offset and collision
  for third person; the visible area in world units for top-down and 2D.

Show the working in the file, so the next person can see where each number came from.

## Deriving the rest

Ratios of the player's width `W` and height `H`. Use the project's kit where it already sets a
size; use these where it does not.

| Thing | Rule of thumb | For a 1.8 m tall, 1.0 m wide player |
|---|---|---|
| Eye height | about 0.85 to 0.93 `H` | 1.5 to 1.7 m |
| Door | 1.25 to 1.8 `W` wide, about 1.2 to 1.4 `H` high | 1.25 to 1.8 m by 2.2 to 2.5 m |
| Corridor | at least 2 `W`, and even that feels tight | 2 m minimum |
| Blockout wall or ceiling | 1.5 to 2 `H` | 2.7 to 3.6 m |
| Stair step | rise below the controller's step offset; about 0.15 to 0.18 m rise, 0.28 to 0.30 m deep | a 30 to 35° flight |
| Stair landing | every 12 to 16 steps | |
| Low cover | about 0.55 to 0.7 `H` | 1.0 to 1.25 m |
| High cover | at least about 0.97 `H` | 1.75 m and up |
| Not cover | below about 0.28 `H` | 0.5 m or less |

Corridors meant for fighting need more than the minimum: room to strafe, and for two combatants
to pass. That is a judgement to test, not a number to copy. If the game snaps the player into
cover, every piece of cover of a kind has exactly the same height.

## Clearly possible or clearly not

A jump, climb or gap is either obviously makeable or obviously not. Nothing sits at the edge of
the player's ability, where a correct attempt sometimes fails and the player cannot tell whether
the level means it. A useful margin: gaps the level expects are no more than about 80% of the
maximum jump, and gaps it forbids are at least about 120% of it. The same goes for ledges: one
the player must not reach sits well above the jump apex, not level with it.

Record both numbers in `LEVEL_METRICS.md`: the comfortable jump the level may ask for, and the
limit it must stay clear of.

## What the camera changes

- **First person.** Eye height and field of view set how big and fast the world feels; a wide
  field of view makes rooms feel larger. Leave enough collision that the camera never clips into
  walls.
- **Third person.** The camera sits behind the character and needs space too. Passages and
  ceilings need room for the character plus the camera on either side, or the camera collides
  and swings. Size from the real camera rig and test it; there is no reliable universal number.
- **Top-down and isometric.** The screen is the constraint: size rooms by how much of them is on
  screen at once. Tall walls on the camera side hide the player, so they are cut away, kept low,
  or faded by the game.
- **2D side-on.** Work in tiles. Jump arcs in tiles are the whole metric set, and the level must
  show far enough ahead at the game's camera size for the player to react.

## The metrics gallery

When the project has no reference space, offer to build one: a small area holding a door, a
corridor, a flight of stairs, each cover height, and a row of gaps and ledges at 80%, 100% and
120% of the jump. Walking it in Play mode settles arguments that numbers cannot, and it shows
when the metrics drift after a change to the controller. It is a prefab like any other area, and
it is the developer's call whether it becomes a permanent part of the project.

## LEVEL_METRICS.md

Short, with the source of every number:

```markdown
# Level metrics

Player: `Assets/Prefabs/Player.prefab`, CharacterController height 1.8, radius 0.4 (W = 0.8)
Jump: velocity 6.2, gravity -18.6 -> apex 6.2² / (2 x 18.6) = 1.03 m
Comfortable jump: 0.8 m up, 3.2 m across. Must stay clear of: 1.25 m up, 4.8 m across.
Grid unit: 0.5 m. Kit module: 2 m.

| Thing | Size | Why |
|---|---|---|
| Door | 1.2 x 2.3 m | 1.5 W, 1.28 H |
...
```
