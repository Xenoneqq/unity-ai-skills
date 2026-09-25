# Dressing: build on the grid, dress off it

Generated levels give themselves away by being too regular: every crate square to the world,
every rock the same size, every lamp the same distance from the last. Real places are shaped by
people, weather and time, and none of them work on a grid. This file is how to get from a
correct blockout to a place that looks lived in, without breaking what the blockout proved.

## What stays on the grid

- **Architecture and modular kit pieces.** Walls, floors, stairs, frames. Snapping keeps seams
  closed and metrics exact.
- **Gameplay geometry.** Cover, jump platforms, ledges and doorways keep their metric sizes and
  positions.
- **Things people put in order on purpose.** Shelving, warehouse racking, pews, a parade ground,
  a formal garden. Even there, what sits on the shelves is not in order.
- **Games where the grid is the design.** Tile, puzzle and grid tactics games, and tidy,
  maintained, functional spaces where a clean look is the point. Built and maintained spaces lean
  orderly; nature, decay and inhabited spaces lean irregular.

Where modules meet at an angle the grid does not like, hide the join with something that belongs
there: a pillar, a rock, a pile of crates.

## Everything else asks "why is this here?"

Every placed thing should have an answer. The answers decide where it goes and what state it is
in:

- **Use.** Chairs pulled out, a mug left mid-task, tools near the work, not a museum display.
- **Wear.** Grime where hands touch and water collects, scuffs along the routes people walk,
  damage where things hit.
- **Story.** What happened here last: a fight, an evacuation, years of neglect. The disorder
  tells it.

An object with no answer is decoration, and decoration spread everywhere reads as noise.

## Clusters, not scatter

Uniform random placement is not the fix for a grid. It reads as noise, the opposite failure.
Group things the way they accumulate:

- **Build a cluster by hand.** Place one object, duplicate it, shrink it, turn it, offset it, and
  repeat. The group comes out lopsided but related.
- **Big, medium and small together**, and odd numbers of a thing within a group. Borrowed from
  interior design rather than game practice, but a dependable rule of thumb.
- **Density follows use.** Clutter collects along walls, in corners and around work. Walked
  routes stay clear. Leave empty space between clusters so the eye has somewhere to rest.
- **Spend detail where the player looks.** Scatter the bulk by script, then place by hand what
  sits at each beat, along the critical path, and in the frame of each sightline capture.

## Small irregularities

Starting ranges, not rules. No strong source gives numbers, and the right amount depends on the
art style and on how orderly the place is:

- **Placed by a person** (crates, furniture, bins): a few degrees off square to the wall or to
  its neighbours, a few centimetres off any line.
- **Natural** (rocks, debris, fallen branches): any rotation around the vertical, tilted up to
  about 10°, partly sunk into the ground so it does not sit on it like a shelf.
- **Scale.** Vary natural things, about 0.85 to 1.15, more for foliage. Do not scale
  manufactured things: a chair at 1.1 looks wrong. Vary them with different models, rotation,
  damage and material instead.
- **Repeated modular pieces.** Mirror, rotate and add decals or vertex colour so the repetition
  stops showing.

## Grounding

Nothing floats, nothing sinks through a floor. Every prop rests on the surface below it, leans
against something, or hangs from something. Where it meets the ground, add the contact the world
would leave: dirt, a shadow gap filled, a decal. Piles (rubble, sacks, boxes knocked over) look
best dropped with physics and left where they settled.

## Doing it from a script

Seeded, so the same script run twice gives the same level and the diff stays reviewable. Record
the seed in the level plan.

```csharp
static void Settle(Transform t, System.Random rng, float maxYaw, float maxTilt, float maxOffset)
{
    float R(float max) => (float)(rng.NextDouble() * 2 - 1) * max;
    var colliders = t.GetComponentsInChildren<Collider>();
    foreach (var c in colliders) c.enabled = false;

    t.position += new Vector3(R(maxOffset), 0, R(maxOffset));
    t.rotation = Quaternion.Euler(R(maxTilt), R(maxYaw), R(maxTilt)) * t.rotation;
    Physics.SyncTransforms();
    if (Physics.Raycast(t.position + Vector3.up * 2f, Vector3.down, out var hit, 10f))
        t.position = new Vector3(t.position.x, hit.point.y, t.position.z);

    foreach (var c in colliders) c.enabled = true;
}
```

It assumes the prop's pivot is at its base. It disables the prop's own colliders so the ray does
not hit itself. Inside a prefab being edited through `EditPrefabContentsScope`, the contents live
in a preview scene; raycast against that scene's own `PhysicsScene` rather than the default one.

For physics-settled piles, give the pieces temporary rigidbodies, step the simulation by hand in
the editor (`Physics.simulationMode = SimulationMode.Script` and `Physics.Simulate` on current
editors; `Physics.autoSimulation = false` on older ones), then remove the rigidbodies and restore
the setting. Check the project's version for which API it has.

## Colour and readability

- **One meaning per gameplay colour.** If red means explosive, only explosive things are red.
- **Keep saturation back** so lighting has room to work, and keep base colours out of the very
  dark range, which bakes into weak bounce light.
- **Readable from a distance.** Materials and silhouettes still make sense 50 m away.

## Dressing never changes gameplay

- No dressing in doorways, on jump take-offs or landings, in cover positions, or on the critical
  path's walking line.
- Small clutter gets no collider, or a simple one, so it never snags the player.
- After dressing, run the checks in [verification.md](verification.md) again. A proven blockout
  most often breaks by a prop nudged into a doorway.
