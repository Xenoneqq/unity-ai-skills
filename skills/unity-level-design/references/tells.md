# Tells

Generated and rushed levels cluster around a few looks. Each is legitimate for some brief;
they are listed because they appear regardless of the level, which makes them defaults rather
than choices.

## Too regular

- Every prop on the grid, rotated at 0 or 90°, in rows, at the same spacing.
- Every copy of a thing at the same scale and the same facing.
- A layout mirrored left to right. Symmetry also costs orientation: the player cannot tell which
  way they came in.
- Rooms as boxes of one or two sizes, joined by corridors of one width.
- Cover blocks at equal spacing, or cover that is just boxes.
- Enemies in a line, all facing the entrance. Pickups spaced evenly along a straight line.
- Lights of the same colour and brightness at the same interval.

## Too random

The overcorrection. Uniform scatter across the whole floor, with no clusters and no reason. It
reads as noise, and it hides whatever the player should notice.

## Layout problems

A layout goes wrong in the same few ways. Each has a fix:

| Problem | What it looks like |
|---|---|
| Too big | Long walks with nothing in them. Start small; growing a space later is easy. |
| Too flat | Everything at one floor height, no overlook, no descent. |
| Too open | No cover, no pinch points, no sense of where to go. |
| Too empty | Space with no purpose. |
| Too linear | One corridor, no choice, no loop. |
| Too similar | Every room the same size and density, no tight-then-open contrast. |
| Too generic | Nothing tells you which game, place or story this is. |

Variation on paper is not variation to the player. Twenty rooms that are technically different
but feel the same are one room twenty times.

## Guidance problems

- The goal visible and reachable in a straight line from the spawn, so nothing is left to find.
- Or the opposite: no landmark anywhere, so the player navigates by the wall.
- The spawn facing a wall.
- Dead ends with nothing at the end.
- Invisible walls, or boundaries the level does not show.
- The brightest thing in the room is not the way on.

## Unity defaults left in

- The default skybox and one untouched directional light.
- Grey default material on final geometry. Primitive cubes shipped as art.
- The whole level on one flat plane at height 0.
- Props floating above the floor or sunk into it, with no contact where they meet it.
- Doors, stairs and corridors that do not match the player's metrics: a staircase the controller
  cannot climb, a door the camera clips through.

## Where the alternative comes from

Not from randomness. From:

- **The place's story.** Who built it, who used it, what happened, what time has done since.
- **The level's one idea.** A level built around one mechanic, introduced, developed, twisted
  and tested, has a shape of its own.
- **Contrast.** Tight then open, dark then light, low then high. The change is what the player
  feels.
- **The player's eye height.** A layout that looks fine from above can be a wall of sameness from
  inside. Judge it from where it will be seen.
