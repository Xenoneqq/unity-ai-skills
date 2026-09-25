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

## Snap everything

In the blockout every position and size is a multiple of the grid unit: the kit's module size if
there is a kit, otherwise 0.5 or 1 m in 3D and one tile in 2D. Round in the builder script
rather than trusting typed numbers. A blockout on the grid is easy to measure, easy to read in a
top-down capture, and easy for a kit to replace later.

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

The cost is size: ProBuilder mesh data serializes into the prefab, so its YAML grows. While greyboxing, the script is the source and re-running it rebuilds the
prefab. Once someone starts adjusting the prefab by hand in the editor, the prefab becomes the
source; stop regenerating it, or the next run erases their work.

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
