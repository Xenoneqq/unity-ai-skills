---
name: unity-pixel-art
description: >
  Generate pixel-art textures, sprites, sprite sheets and icons for a Unity project from code
  instead of drawing them: a fixed palette, a small drawing canvas, seeded noise, tileable
  textures that wrap without seams, pose-based character frames, and import settings that keep
  every pixel sharp. The generator is a committed editor builder with a fixed seed, so "make it
  darker" is a code change and a rerun. Use when: "make a dirt texture", "create a repeating
  ground texture", "generate a sprite", "make a walk cycle", "draw an ammo icon", "we have no
  art", "placeholder art that looks decent", "pixel art", "tileable texture", "my pixel textures
  look blurry", "/unity-pixel-art".
---

# Unity pixel art

When a project has no art and nothing may be downloaded, generated pixel art is the fastest way
to something readable and on-style. The rule that makes it work: **the code is the art source.**
A PNG is output. Every asset comes from a committed builder with a fixed seed, so it can be
regenerated from a fresh clone, and every change ("darker", "more pebbles", "fatter outline")
is an edit to the recipe and a rerun, never a hand-painted fix that the next run erases.

**The project outranks this file.** If it already has art, a palette, a pixels-per-unit value or
an art folder, match them. If a person wants to hand-paint over a generated file, the builder
stops owning that file (`unity-scene-habits`, `references/builders.md`).

This skill makes the pixels and their import settings. Making them render crisp on screen, such
as a pixel-perfect camera or matching the camera's resolution to the art, is camera and pipeline
work, not this skill's.

## 1. Probe the project

```bash
PV=$(find . -path '*/ProjectSettings/ProjectVersion.txt' -not -path '*/Library/*' -print -quit)
ROOT=$(dirname "$(dirname "$PV")")
echo "pngs: $(find "$ROOT/Assets" -iname '*.png' | wc -l)"
grep -rhoE 'filterMode: [0-9]|spritePixelsToUnits: [0-9.]+' "$ROOT/Assets" --include='*.png.meta' \
  | sort | uniq -c | sort -rn | head
find "$ROOT/Assets" -type d \( -iname 'Builders' -o -iname 'Generated' \) -not -path '*/Library/*'
ls "$ROOT"/UI_STYLE.md 2>/dev/null
```

- **Existing art.** Its resolution per tile or character, its palette, and its settings.
  `filterMode: 0` is Point; anything else in a pixel-art project is already a bug to report.
- **Pixels per unit.** Use the project's. With none, pick one that makes a character's height
  in pixels match its height in units sensibly (32 PPU for a 1-unit tile of 32 px), and write it
  down.
- **2D or 3D.** Sprites for 2D and for billboards in 3D; tiling textures for 3D surfaces.
- **Where builders live**, per `unity-scene-habits`' `references/builders.md`, and where art goes,
  per `unity-file-structure-habits`.
- **A UI style plan** (`UI_STYLE.md` from `unity-ui-design`). If it exists, its palette is the
  starting point for icons.

## 2. Palette first

One palette for the whole game, as ramps: 3 to 5 shades of each material or colour, dark to
light, 16 to 32 colours in all. Every generator draws from it, which is what makes a dirt floor,
a janitor and a keycard icon look like one game. Keep it in one committed class, beside the
builders:

```csharp
public static class ArtPalette
{
    public static readonly Color32[] Dirt  = Ramp("241a12", "3d2b1d", "5e432c", "80613f");
    public static readonly Color32[] Steel = Ramp("1e2328", "3a434c", "5f6d78", "95a3ad");
    public static readonly Color32 Ink = Hex("120d0a");

    static Color32[] Ramp(params string[] hex) => System.Array.ConvertAll(hex, Hex);

    static Color32 Hex(string hex)
    {
        ColorUtility.TryParseHtmlString("#" + hex, out var c);
        return c;
    }
}
```

Shade ramps shift hue as well as value (warmer light, cooler shadow) or they look flat. A new
subject adds a ramp here rather than inventing colours inline.

## 3. The canvas

Generators draw on a small canvas class with pixel-level tools, then write a PNG and set its
import settings. [references/pixel-canvas.md](references/pixel-canvas.md) has the canvas, the
dithering, the tileable noise and the import helper, ready to drop into the builders folder.
Scaffold it once per project; later assets reuse it.

Every random choice goes through `System.Random` with a fixed seed. `UnityEngine.Random` is
shared global state, so its output depends on whatever else ran first.

## 4. Make the asset

- **A tiling texture** (ground, wall, trim): read
  [references/tileable.md](references/tileable.md). Everything is drawn on a torus, so it tiles
  by construction, and a seam check proves it.
- **A sprite, a sheet or an animation** (characters, pickups, props): read
  [references/sprites.md](references/sprites.md). Looks, poses, sheet layout, pivots and
  slicing.
- **An icon** (HUD, inventory): a sprite at the UI's size, from the same palette, with the same
  outline as the world sprites, so the key on the HUD is recognisably the key on the floor.

Keep sizes to powers of two and to the project's grid: 16, 32 or 64 px per tile or character.
A size that tiles also dithers cleanly when it is a multiple of 4.

## 5. Import settings are part of the output

A generated PNG left on Unity's defaults is blurred: bilinear filtering, mipmaps, anisotropic
filtering and compression all smear pixel art. The builder sets them every run:

| Setting | Sprites and icons | Tiling world textures |
|---|---|---|
| Filter mode | Point | Point |
| Mipmaps | Off | On (avoids shimmer at distance) |
| Anisotropic level | 0 | 0 |
| Compression | None | None |
| Wrap mode | Clamp | Repeat |
| Pixels per unit | The project's value | n/a |

Then protect it with the settings test from `unity-scene-habits`' `references/builders.md`, so
a texture that any later worker adds by hand cannot silently fall back to bilinear.

## 6. Look at it

The generator also writes an enlarged preview: the texture tiled 3x3, or the sheet over a
checkerboard, scaled up 4x with no smoothing. Write it to the system temp folder, or to
`session-materials/screenshots/` under `unity-manage-work`, and open it. Judge:

- **Seams.** In the 3x3 tile, can you find the edges? A visible grid of repeats is a failure
  even when the seam check passes.
- **Readability.** At 1x, does the silhouette read? Does each pickup say what it is before
  anyone is told?
- **Fit.** Beside the existing art, same palette, same outline weight, same light direction
  (top-left, unless the project says otherwise).

Then check it in the game, with a screenshot test (`unity-scene-habits`,
`references/visual-checks.md`). A texture that looks right alone can still be too busy on a
floor that fills half the screen.

Iterate on the recipe, not the pixels, and look again after every change.

## 7. Report

- Each asset made: path, size, seed, and the builder and method that makes it.
- The palette ramps added.
- The import settings applied and the settings test, if added.
- The preview paths, and what was checked in the game and what was not.
