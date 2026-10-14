# Generated assets

Models and props can come from code the same way textures do in `unity-pixel-art`. That suits
agents far better than hand-made art: "make it darker" or "rounder rocks" is a parameter change
and a rerun, reviewable in a diff.

## Generators are code

- **One script per family** (rocks, crates, pipes), committed outside `Assets/` in the project's
  tools folder, so Unity never imports it. Review it like any other code.
- **Run it headless.** For Blender, `blender -b --python <script> -- <args>`; arguments after
  `--` reach the script in `sys.argv`. Check the installed version before writing against its
  API, which moves between releases.
- **Fixed seeds.** Every random choice goes through a seeded generator, never global state.
- **Export to the project's model and texture folders**, per `unity-file-structure-habits`.
  Commit the output too, so a clone without the tool still opens.

## Reruns change nothing

- **Byte-identical.** Running a generator twice gives the same files. If the exporter stamps a
  date or a path into the file, turn that off or use a format that does not.
- **One family at a time.** The run takes a family name, and adding a family never re-exports
  the others. Skip writing a file whose bytes have not changed, or Unity reimports it.

## Into prefabs

A committed editor builder ([builders.md](builders.md)) turns each exported model into a prefab
from a table: the model, its pivot, its collider and its scale. It also sets the model's import
settings, and edits existing prefabs in place, so tuning a row keeps every GUID.

```csharp
static readonly (string model, string collider, float scale)[] Props =
{
    ("Rocks/Boulder_A",    "convex", 1f),
    ("Crates/Crate_Small", "box",    1f),
};
```

Put the pivot where the prefab sits (at the base, for anything placed on a floor) in the
generator rather than with a wrapper object in the builder. A hand-made fix to a generated file
means the generator no longer owns it, as with any builder output.
