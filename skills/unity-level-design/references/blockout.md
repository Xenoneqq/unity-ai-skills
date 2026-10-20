# Blockout in Unity

A blockout answers one question: does this space play? Everything in it is cheap to move, and
nothing in it tries to look finished. Where the files go is `unity-file-structure-habits`' call,
and every scene and prefab change goes through the editor per `unity-scene-habits`.

## What to build with

Use what the project already uses. If it has nothing:

- **ProBuilder**, if installed, is the best greybox tool: faces can be pushed and pulled later,
  and its default UVs are in world units, so a grid texture shows true metres on every piece
  whatever its scale.
- **Primitives** (`GameObject.CreatePrimitive`) work in any project. Their UVs stretch with
  scale, so a grid texture lies about size on them; set the material tiling per piece, or use a
  world-space grid shader if the project has one. They are the fallback when ProBuilder is not
  installed and the developer would rather not add it.
- **Tilemaps** for 2D. The tile grid is the level grid. Keep ground, collision and decoration on
  separate tilemaps so dressing never touches collision.
- **Terrain** for large outdoor ground. Its data is one binary asset that cannot be merged, so
  only one person edits a given terrain at a time.

Give greybox materials meaning, and keep the set small: walkable, wall, climbable or
interactive, hazard, goal. If the game already has a colour language for these, use it.

## Structure

- **One prefab per area.** A room, a courtyard, a stretch of road. Pivot on a grid corner, so
  placing it in the scene is placing it on the grid.
- **The scene places areas** and holds what only a scene can: lighting, environment settings,
  the spawn point.
- **Markers.** Empty objects tagged `EditorOnly` (stripped from builds) for the spawn, each beat,
  the exit, and each jump the level expects: `Beat_01_FirstEnemy`, `Jump_03_From`,
  `Jump_03_To`. The checks in [verification.md](verification.md) read them.
- **The spawn faces the first goal**, never a wall.

## Constructed, natural or both

Decide per part before building it:

- **Constructed** (buildings, corridors, machinery rooms): clean geometry on the grid, straight
  edges, one wall thickness. Blocks and ProBuilder shapes are right.
- **Broken or natural** (terrain, rock, ruins, collapsed areas, anything grown or damaged):
  uneven silhouettes, rounded masses, irregular edges. Boxes with jitter still read as a
  blockout. Use a generated mesh (for example a signed-distance volume meshed in code) or a
  modelled asset, exempt from the grid.
- **Mixed** (a built room inside a cave): build each part its own way and make the seam
  deliberate, with a frame, a wall or a threshold.

Organic walls are fine; an organic floor is not. The walkable surface keeps the step height,
slope limit and navigation agent from `LEVEL_METRICS.md`, so the controller and agents can
actually walk it.

## Snap everything constructed

In the blockout every constructed position and size is a multiple of the grid unit: the kit's
module size if there is a kit, otherwise 0.5 or 1 m in 3D and one tile in 2D. Round in the
builder script rather than trusting typed numbers. A blockout on the grid is easy to measure,
easy to read in a top-down capture, and easy for a kit to replace later.

## Building it from a script

Areas are built by editor scripts, run through `unity-scene-habits`. Describing an area as a list
of blocks keeps the layout readable in a diff and cheap to regenerate:

```csharp
static readonly (string name, Vector3 min, Vector3 max, string role)[] Courtyard =
{
    ("Floor",      new Vector3(0, -0.5f, 0),  new Vector3(24, 0, 18),   "walkable"),
    ("WallNorth",  new Vector3(0, 0, 17.5f),  new Vector3(24, 4, 18),   "wall"),
    ("LedgeEast",  new Vector3(20, 0, 4),     new Vector3(24, 1.2f, 8), "climbable"),
};
```

Each block becomes a snapped, scaled cube with the material for its role, under one root saved
as the area prefab.

With ProBuilder, the builder makes ProBuilder shapes instead of cubes, through its scripting API
(`ShapeGenerator` for shapes, `ProBuilderMesh` for faces, `MeshOperations` for extrusions and
merges). The API moved between major versions, so check the installed one before writing
against it. What that buys over primitives:

- **Textures line up.** World-space UVs tile a texture across walls and floors of any length,
  where scaled cubes stretch it differently on each. `unity-pixel-art` makes tiling textures if
  the project has none.
- **Real openings.** A wall with a doorway is one mesh with a hole, not four cubes around a gap.
  Stairs, ramps and arches are single shapes too.
- **Fewer objects.** Faces merge per area, so a room is a handful of meshes, not hundreds.
- **People can edit it.** The developer pushes faces around in the editor, which is the normal
  level-design loop.

The cost is size: ProBuilder mesh data serializes into the prefab, so its YAML grows. When
merging, drop the faces nobody can see and keep UVs anchored in world or area units, so a
texture runs on across the merged blocks. Keep ProBuilder only for shells people will edit by
hand; generated organic meshes are plain mesh assets, regenerated from code.

### Builders the developer can still edit after

Each area is a builder function, and the prefab is its output. The builder creates the areas
that are missing and rebuilds one only when asked for it by name, updating that prefab in place
rather than deleting and recreating it (`unity-scene-habits`, `references/builders.md`).

- **Never rebuild what someone edited by hand.** Change it surgically instead: open the prefab
  contents, add or replace only a group the builder owns, save, then compare the prefab object
  by object. A raw diff of a prefab with new nested instances looks like mass deletion. Mirror
  the change in the builder so a later rebuild keeps it.
- **Shell apart from details.** Structural geometry under one root, props, decoration and
  markers in their own groups. People edit shells by hand, and loose details mixed in make that
  miserable.
- **One connection contract.** If areas join, define the joint once (opening size, where it sits
  on the bounds, floor height tolerance, open or closed) and test every area against it.
- **Seeded rolls shift.** When variation is rolled in hierarchy order, a new rolled component
  shifts every roll after it. Add decoration as plain objects, or inside existing variation,
  unless reshuffling the level is acceptable.

## Keep it cheap from the start

- Mark geometry that never moves as static: `GameObjectUtility.SetStaticEditorFlags` with
  `ContributeGI`, `OccluderStatic`, `OccludeeStatic` and `BatchingStatic` as the project needs.
- Colliders are primitives wherever possible. A mesh collider on a crate costs far more than a
  box and buys nothing. Mesh colliders on moving objects must be convex.
- Large meshes get LOD groups once they are real art, not in greybox.
- Navigation: with the AI Navigation package, bake with a `NavMeshSurface` whose agent radius,
  height, step height and max slope come from `LEVEL_METRICS.md`. Older editors use the built-in
  navigation window; check the version.
- Baked lighting writes large binary files per scene that cannot be merged. Do not bake unless
  the developer asks, and say in the report that the bake is still to do.
