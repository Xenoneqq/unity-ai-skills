# The canvas

Four small pieces, scaffolded once into the project's builders folder (an editor-only assembly)
and shared by every generator. Adjust namespaces to the project's.

Coordinates follow Unity textures: `(0, 0)` is the bottom-left pixel and `y` goes up.

## `PixelCanvas`

```csharp
using System.IO;
using UnityEngine;

public sealed class PixelCanvas
{
    public readonly int Width, Height;
    public readonly bool Wrap;
    readonly Color32[] pixels;

    // wrap: true makes every coordinate wrap around, so anything drawn over an edge continues
    // on the opposite side. Tileable textures are drawn this way.
    public PixelCanvas(int width, int height, bool wrap = false)
    {
        Width = width;
        Height = height;
        Wrap = wrap;
        pixels = new Color32[width * height];
    }

    public Color32 Get(int x, int y) => Index(x, y, out var i) ? pixels[i] : default;

    public void Set(int x, int y, Color32 c)
    {
        if (Index(x, y, out var i)) pixels[i] = c;
    }

    public void Fill(Color32 c)
    {
        for (var i = 0; i < pixels.Length; i++) pixels[i] = c;
    }

    public void Rect(int x, int y, int w, int h, Color32 c)
    {
        for (var j = y; j < y + h; j++)
            for (var i = x; i < x + w; i++)
                Set(i, j, c);
    }

    public void Line(int x0, int y0, int x1, int y1, Color32 c)
    {
        int dx = Mathf.Abs(x1 - x0), dy = -Mathf.Abs(y1 - y0);
        int sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, err = dx + dy;
        while (true)
        {
            Set(x0, y0, c);
            if (x0 == x1 && y0 == y1) return;
            var e2 = 2 * err;
            if (e2 >= dy) { err += dy; x0 += sx; }
            if (e2 <= dx) { err += dx; y0 += sy; }
        }
    }

    public void Disc(int cx, int cy, int r, Color32 c)
    {
        for (var y = -r; y <= r; y++)
            for (var x = -r; x <= r; x++)
                if (x * x + y * y <= r * r + r) Set(cx + x, cy + y, c);
    }

    // Draws ink on every transparent pixel that touches an opaque one. Run it last.
    public void Outline(Color32 ink)
    {
        var before = (Color32[])pixels.Clone();
        for (var y = 0; y < Height; y++)
            for (var x = 0; x < Width; x++)
            {
                if (before[y * Width + x].a != 0) continue;
                if (Opaque(before, x + 1, y) || Opaque(before, x - 1, y) ||
                    Opaque(before, x, y + 1) || Opaque(before, x, y - 1))
                    pixels[y * Width + x] = ink;
            }
    }

    // The canvas repeated tiles x tiles times and scaled up with no smoothing, for looking at.
    public PixelCanvas Preview(int tiles, int scale)
    {
        var p = new PixelCanvas(Width * tiles * scale, Height * tiles * scale);
        for (var y = 0; y < p.Height; y++)
            for (var x = 0; x < p.Width; x++)
                p.pixels[y * p.Width + x] = pixels[(y / scale % Height) * Width + x / scale % Width];
        return p;
    }

    public void SavePng(string path)
    {
        var tex = new Texture2D(Width, Height, TextureFormat.RGBA32, false);
        tex.SetPixels32(pixels);
        tex.Apply();
        File.WriteAllBytes(path, tex.EncodeToPNG());
        Object.DestroyImmediate(tex);
    }

    bool Opaque(Color32[] source, int x, int y) => Index(x, y, out var i) && source[i].a != 0;

    bool Index(int x, int y, out int i)
    {
        if (Wrap)
        {
            x = (x % Width + Width) % Width;
            y = (y % Height + Height) % Height;
        }
        else if (x < 0 || y < 0 || x >= Width || y >= Height)
        {
            i = -1;
            return false;
        }
        i = y * Width + x;
        return true;
    }
}
```

## `Shade`: a value to a palette colour, dithered

Noise and lighting produce a value from 0 to 1. `Shade` maps it onto a ramp from `ArtPalette`,
dithering between neighbouring shades with a 4x4 Bayer pattern instead of blending, so the
result stays inside the palette.

```csharp
public static class Pixel
{
    static readonly int[] Bayer4 = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };

    public static Color32 Shade(Color32[] ramp, float value, int x, int y)
    {
        var t = Mathf.Clamp01(value) * (ramp.Length - 1);
        var i = Mathf.FloorToInt(t);
        var threshold = (Bayer4[(y & 3) * 4 + (x & 3)] + 0.5f) / 16f;
        if (i < ramp.Length - 1 && t - i > threshold) i++;
        return ramp[i];
    }
}
```

The pattern repeats every 4 pixels, so a tileable texture keeps it seamless only when its size is
a multiple of 4. For a flatter look, drop the dither and use `ramp[Mathf.RoundToInt(t)]`.

## `TileNoise`: smooth noise that wraps

Value noise on a lattice that repeats every `Period` cells. Sampled across a texture with exactly
`Period` cells per texture width, it tiles.

```csharp
public sealed class TileNoise
{
    public readonly int Period;
    readonly float[] lattice;

    public TileNoise(int period, int seed)
    {
        Period = period;
        var rng = new System.Random(seed);
        lattice = new float[period * period];
        for (var i = 0; i < lattice.Length; i++) lattice[i] = (float)rng.NextDouble();
    }

    // x, y in texture pixels; size is the texture's width and height.
    public float Sample(int x, int y, int size)
    {
        var u = x * Period / (float)size;
        var v = y * Period / (float)size;
        int x0 = Mathf.FloorToInt(u), y0 = Mathf.FloorToInt(v);
        float fx = Smooth(u - x0), fy = Smooth(v - y0);
        var bottom = Mathf.Lerp(At(x0, y0), At(x0 + 1, y0), fx);
        var top = Mathf.Lerp(At(x0, y0 + 1), At(x0 + 1, y0 + 1), fx);
        return Mathf.Lerp(bottom, top, fy);
    }

    // Several octaves summed, each twice as fine and half as strong as the last.
    public static float Layered(TileNoise[] octaves, int x, int y, int size)
    {
        float sum = 0, weight = 0, amplitude = 1;
        foreach (var octave in octaves)
        {
            sum += amplitude * octave.Sample(x, y, size);
            weight += amplitude;
            amplitude *= 0.5f;
        }
        return sum / weight;
    }

    float At(int x, int y) => lattice[(y % Period + Period) % Period * Period + (x % Period + Period) % Period];

    static float Smooth(float t) => t * t * (3 - 2 * t);
}
```

Build octaves with periods that double (4, 8, 16) and different seeds (`seed`, `seed + 1`, ...).
Every period must divide the texture size.

## `PixelImport`: settings, every run

```csharp
using UnityEditor;
using UnityEngine;

public static class PixelImport
{
    public static void WorldTexture(string path) => Apply(path, importer =>
    {
        importer.textureType = TextureImporterType.Default;
        importer.mipmapEnabled = true;
        importer.wrapMode = TextureWrapMode.Repeat;
    });

    public static void Sprite(string path, float pixelsPerUnit) => Apply(path, importer =>
    {
        importer.textureType = TextureImporterType.Sprite;
        importer.spritePixelsPerUnit = pixelsPerUnit;
        importer.mipmapEnabled = false;
        importer.wrapMode = TextureWrapMode.Clamp;
    });

    static void Apply(string path, System.Action<TextureImporter> configure)
    {
        AssetDatabase.ImportAsset(path);
        var importer = (TextureImporter)AssetImporter.GetAtPath(path);
        importer.filterMode = FilterMode.Point;
        importer.anisoLevel = 0;
        importer.textureCompression = TextureImporterCompression.Uncompressed;
        configure(importer);
        importer.SaveAndReimport();
    }
}
```

Rewriting a PNG at the same path keeps its `.meta` and GUID, so references survive a rerun. With a
fixed seed the bytes come out the same, and a rerun with no recipe change shows nothing in
`git status`.
