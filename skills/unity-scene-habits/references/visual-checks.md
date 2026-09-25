# Visual checks

A test proves a rule holds. It cannot tell you a pose looks awkward, a sprite is unreadable or a
light is off. A screenshot can, and when no human is checking the work it is the best evidence
there is. Anything visual ships with a PlayMode test that renders it to a PNG, and someone looks
at the PNG.

## Rendering headless

PlayMode tests render in batch mode as long as `-nographics` is left off. Whether that works
depends on the machine: a desktop with a GPU usually renders, a CI box may need a GPU or a
virtual display. Establish it once with one screenshot test; the frame check below fails loudly
if nothing rendered.

## Capturing

Render the camera into a texture yourself. `ScreenCapture` is unreliable without a window.

```csharp
static Texture2D Capture(Camera cam, int width = 960, int height = 540)
{
    var rt = RenderTexture.GetTemporary(width, height, 24);
    var previous = cam.targetTexture;
    cam.targetTexture = rt;
    cam.Render();
    RenderTexture.active = rt;
    var tex = new Texture2D(width, height, TextureFormat.RGB24, false);
    tex.ReadPixels(new Rect(0, 0, width, height), 0, 0);
    tex.Apply();
    cam.targetTexture = previous;
    RenderTexture.active = null;
    RenderTexture.ReleaseTemporary(rt);
    return tex;
}
```

A Screen Space - Overlay canvas is not drawn by `camera.Render()`. For a shot that includes UI,
switch the canvas inside the test: `canvas.renderMode = RenderMode.ScreenSpaceCamera;
canvas.worldCamera = cam;`.

## Failing on a broken frame

A black, blown-out or flat frame means the camera, lighting or rendering is broken, not that the
content is fine. Fail the test on it:

```csharp
var pixels = tex.GetPixels32();
float sum = 0, sumSq = 0;
foreach (var p in pixels)
{
    var l = (0.2126f * p.r + 0.7152f * p.g + 0.0722f * p.b) / 255f;
    sum += l;
    sumSq += l * l;
}
var mean = sum / pixels.Length;
var spread = Mathf.Sqrt(sumSq / pixels.Length - mean * mean);
Assert.That(mean, Is.InRange(0.02f, 0.98f), "frame is black or blown out");
Assert.That(spread, Is.GreaterThan(0.01f), "frame is flat");
File.WriteAllBytes(path, tex.EncodeToPNG());
```

## Where the files go

Somewhere ignored by git. Under `unity-manage-work` that is `session-materials/screenshots/`,
one folder per task, and it is the one place in `session-materials/` workers may write. Outside
a managed session, use the system temp folder (`Path.GetTempPath()`) and log the path. Not the
project's `Temp/`: Unity deletes it when the editor quits, so a batch run loses the files.

Mark screenshot tests with `[Category("Screenshot")]`. A full-suite run reruns every earlier
screenshot test and overwrites its PNGs; filter the category out of routine runs if the older
shots still need looking at.

## Looking

Open every PNG. A screenshot nobody opened proves nothing. Check what a player would notice: is
the subject framed and readable, does it look like the rest of the game, is anything clipped,
stretched or floating.
