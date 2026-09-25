# Tiling textures

A tiling texture repeats across a floor or wall without a visible seam. Drawing it on a torus
does that by construction: the canvas wraps (`new PixelCanvas(size, size, wrap: true)`), the noise
wraps (`TileNoise` periods that divide the size), and anything drawn over an edge continues on
the opposite side. Then a seam check proves it.

## A recipe

A dirt floor, 64 px, darker in the cracks, with pebbles:

```csharp
using UnityEditor;
using UnityEngine;

public static class DirtGroundBuilder
{
    const int Size = 64;
    const int Seed = 1234;
    const string AssetPath = "Assets/Art/Generated/Textures/DirtGround.png";

    [MenuItem("Tools/Builders/Dirt Ground")]
    public static void Build()
    {
        var soil = new[] { new TileNoise(4, Seed), new TileNoise(8, Seed + 1), new TileNoise(16, Seed + 2) };
        var cracks = new TileNoise(8, Seed + 3);
        var canvas = new PixelCanvas(Size, Size, wrap: true);

        for (var y = 0; y < Size; y++)
            for (var x = 0; x < Size; x++)
            {
                var value = TileNoise.Layered(soil, x, y, Size);
                var ridge = Mathf.Abs(cracks.Sample(x, y, Size) - 0.5f);
                if (ridge < 0.03f) value *= 0.35f;
                canvas.Set(x, y, Pixel.Shade(ArtPalette.Dirt, value, x, y));
            }

        var rng = new System.Random(Seed);
        for (var i = 0; i < 40; i++)
        {
            int x = rng.Next(Size), y = rng.Next(Size);
            canvas.Set(x, y, ArtPalette.Dirt[3]);
            canvas.Set(x, y - 1, ArtPalette.Dirt[0]);
        }

        if (!Seams.Tile(canvas)) throw new System.InvalidOperationException("DirtGround does not tile");
        canvas.SavePng(AssetPath);
        PixelImport.WorldTexture(AssetPath);
        canvas.Preview(3, 4).SavePng(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "DirtGround-preview.png"));
    }
}
```

Every knob is a named number in the recipe. "Darker in the cracks" is the `0.35f`, "more
pebbles" is the `40`, "coarser" is the octave periods. The pebble shadow at `y - 1` wraps to the
top row when `y` is 0, which is what keeps it seamless.

Other surfaces are the same shape with different layers:

- **Concrete:** fine noise at low contrast, a few long hairline cracks drawn with `Line`, stains
  from one coarse octave thresholded.
- **Brick or metal plates:** a regular grid of rects with mortar or seam lines, each brick
  shaded by its own noise sample, one highlight row on top and one shadow row below.
- **Grass:** a dark base, then short vertical strokes of two or three lighter shades at seeded
  positions.
- **Hazard stripes:** diagonal bands where `(x + y) % period < period / 2`, with `period`
  dividing the size so the diagonal lines up across the seam. Tileable along one axis only if it
  is trim, so say which.

## The seam check

Wrapping draws seamlessly, but a recipe can still break it: a stamp placed with plain
coordinates, a period that does not divide the size. Compare the change across the seam with the
change across the middle; a seam much sharper than the interior is visible.

```csharp
public static class Seams
{
    public static bool Tile(PixelCanvas c)
    {
        float seam = 0, inside = 0;
        for (var y = 0; y < c.Height; y++)
        {
            seam += Step(c, c.Width - 1, y, 0, y);
            inside += Step(c, c.Width / 2 - 1, y, c.Width / 2, y);
        }
        for (var x = 0; x < c.Width; x++)
        {
            seam += Step(c, x, c.Height - 1, x, 0);
            inside += Step(c, x, c.Height / 2 - 1, x, c.Height / 2);
        }
        return seam <= inside * 1.5f + c.Width;
    }

    static float Step(PixelCanvas c, int ax, int ay, int bx, int by)
    {
        Color32 p = c.Get(ax, ay), q = c.Get(bx, by);
        return Mathf.Abs(p.r - q.r) + Mathf.Abs(p.g - q.g) + Mathf.Abs(p.b - q.b);
    }
}
```

It catches a hard seam, not a repeat that is obvious because one feature is too distinctive. Only
the 3x3 preview shows that: look for a pebble or stain the eye finds in every tile, and tone it
down.

## A normal map, if the project lights its surfaces

Keep the height values the colours came from, then derive normals from their slope, wrapping at
the edges so the normal map tiles too:

```csharp
static PixelCanvas NormalMap(float[,] height, float strength)
{
    int w = height.GetLength(0), h = height.GetLength(1);
    var canvas = new PixelCanvas(w, h);
    for (var y = 0; y < h; y++)
        for (var x = 0; x < w; x++)
        {
            var dx = height[(x + w - 1) % w, y] - height[(x + 1) % w, y];
            var dy = height[x, (y + h - 1) % h] - height[x, (y + 1) % h];
            var n = new Vector3(dx * strength, dy * strength, 1f).normalized;
            canvas.Set(x, y, new Color(n.x * 0.5f + 0.5f, n.y * 0.5f + 0.5f, n.z * 0.5f + 0.5f, 1f));
        }
    return canvas;
}
```

Import it with the same point filtering, and `textureType` set to `NormalMap` instead of
`Default`. Most flat-shaded retro looks do not want one; ask before adding it.
