# Sprites, sheets and animation

## One routine, many looks

Characters of one kind share one drawing routine. What differs between a guard and a worker is
data: palette ramps and proportions. So each subject is a look, and one routine draws any look
in any pose:

```csharp
public struct Look
{
    public Color32[] Skin, Shirt, Trousers, Hair;
    public int Height, ShoulderWidth, HeadSize;
}

public enum Pose { Idle, WalkA, WalkB, Attack, Pain, Dead }

public static class Figure
{
    // Draws feet at y = 0, centred on x = canvas.Width / 2.
    public static void Draw(PixelCanvas c, Look look, Pose pose)
    {
        var mid = c.Width / 2;
        var legHeight = look.Height * 2 / 5;
        var stride = pose == Pose.WalkA ? 2 : pose == Pose.WalkB ? -2 : 0;

        c.Rect(mid - 3 + stride, 0, 2, legHeight, look.Trousers[1]);
        c.Rect(mid + 1 - stride, 0, 2, legHeight, look.Trousers[2]);
        // torso, arms and head the same way, each offset by the pose
        c.Outline(ArtPalette.Ink);
    }
}
```

Poses move parts, they do not redraw them: walk frames swap which leg is forward, an attack
pushes an arm out, pain leans the torso back a pixel or two, dead lies the figure along the
ground. Two walk frames plus idle are enough for a retro look; add in-betweens only if the
movement reads as jerky in the game.

Shade every part from its ramp with light from one direction (top-left unless the project says
otherwise): a lighter column on the lit side, a darker one on the other. Outline last, so it
wraps the whole silhouette.

## Readability at size

At 32 px a character is about a dozen pixels wide. What reads is silhouette and contrast, not
detail:

- **Distinct silhouettes.** Two enemy types differ in outline shape (a hat, a bulk, a tool), not
  only in colour.
- **One accent per subject.** A single bright colour the player learns to spot.
- **Pickups say what they do.** A health item looks like health in this game's language (a cross,
  a heart, a first-aid box) before anyone reads a message. A clever object that does not read,
  such as a bottle that happens to heal, needs a label or a different design.

Check at 1x in the game, not only in the enlarged preview.

## Sheets

Lay frames on a grid: one row per animation, one column per frame, every cell the same size.
Keep one sheet per subject, and name frames `<subject>_<animation>_<index>` so code can find them.

- **Pivot** at the feet (`new Vector2(0.5f, 0f)`) for characters and anything standing on the
  ground, at the centre for icons and projectiles.
- **Padding.** Leave one transparent pixel between cells so filtering never bleeds a neighbour's
  pixels in.

## Slicing, without breaking references

Set `spriteImportMode` to `Multiple` and write one rect per cell. How depends on the editor:
newer ones use the 2D Sprite package's `ISpriteEditorDataProvider` (namespace
`UnityEditor.U2D.Sprites`), older ones the importer's `spritesheet` array. Check what the
installed version supports.

**Keep each sprite's id across reruns.** Animation clips and prefabs reference a sprite by its id
within the texture. Generate new ids on every rerun and every reference to the sheet breaks.
Read the existing rects first, reuse the id of any frame whose name matches, and only create ids
for new frames:

```csharp
var factory = new SpriteDataProviderFactories();
factory.Init();
var provider = factory.GetSpriteEditorDataProviderFromObject(importer);
provider.InitSpriteEditorDataProvider();

var existing = new Dictionary<string, GUID>();
foreach (var r in provider.GetSpriteRects()) existing[r.name] = r.spriteID;

var rects = new List<SpriteRect>();
foreach (var frame in frames)
    rects.Add(new SpriteRect
    {
        name = frame.Name,
        rect = frame.Rect,
        alignment = SpriteAlignment.Custom,
        pivot = frame.Pivot,
        spriteID = existing.TryGetValue(frame.Name, out var id) ? id : GUID.Generate(),
    });

provider.SetSpriteRects(rects.ToArray());
provider.Apply();
importer.SaveAndReimport();
```

## Icons

An icon is a sprite at the UI's size (commonly 32 or 64 px) with the world sprite's palette and
outline weight, often the same object redrawn larger and simpler. Icons that sit side by side
(keys, ammo types) share a frame, a size and a light direction, and differ in one strong colour
or shape each.
