# Capturing the built UI

The goal is to look at the real screen the way a player will see it, at every aspect the game
ships on, over the world it will sit on. Then compare it to the approved mockup and the plan.

**The fallback recipes below are starting points, not proven procedures.** Rendering UI outside
the Game view varies across editor versions and render pipelines. Adapt them, check the output before
trusting it, and if capture will not work in this project, stop trying and use the developer
checklist at the end. An unverified screen reported honestly is fine. A screen described as
looking right that nobody saw is not.

## The matrix

| Aspect | Size | When |
|---|---|---|
| 16:9 | 1920 x 1080 | Always |
| 21:9 | 2560 x 1080 | PC |
| 16:10 | 1280 x 800 | PC and handheld PCs |
| 4:3 | 1024 x 768 | PC, tablets |
| Portrait phone | 1170 x 2532 | Mobile, portrait games |

Each size over two backdrops at least: a bright busy one and a dark one. Add a real gameplay
frame if the developer has one. Write the images to `ui-captures/` at the repo root, outside
`Assets/`. They are scratch, not something to commit.

## First choice: the editor's screenshot command

On the connected path (editor 6.0+, Pipeline installed, editor `ready` in `unity status`; see
`unity-scene-habits`), the editor captures itself at any size:

```bash
unity command --query screenshot    # confirm this editor exposes it, and read its parameters
unity command screenshot --output ui-captures/pause-2560x1080.png --width 2560 --height 1080
```

It captures what the editor is showing, so the screen has to be on screen. Play mode, at the
point the game opens that screen, is the cleanest way: nothing is saved, and the backdrop is the
real game rather than a stand-in. Add the bright and dark cases by capturing in the brightest and
darkest places the game has. Never place the screen in a scene just to capture it and then save
that scene.

The recipes below are for when this command is not available: an older editor, no Pipeline, or
a screen that cannot be reached in Play mode.

Rendering needs a graphics device: in batch mode, drop `-nographics` for capture runs.

## uGUI

Render a screen prefab into a texture from an editor script, in a preview scene so no open scene
is touched:

```csharp
static void Capture(string prefabPath, int w, int h, Color backdrop, Vector2 reference, float match, string outPng)
{
    var scene = EditorSceneManager.NewPreviewScene();
    var rt = new RenderTexture(w, h, 24);
    try
    {
        var camGo = new GameObject("CaptureCamera");
        SceneManager.MoveGameObjectToScene(camGo, scene);
        var cam = camGo.AddComponent<Camera>();
        cam.scene = scene;
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = backdrop;
        cam.targetTexture = rt;

        var ui = (GameObject)PrefabUtility.InstantiatePrefab(
            AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath), scene);
        var canvas = ui.GetComponentInChildren<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceCamera;
        canvas.worldCamera = cam;

        // Some versions size ScaleWithScreenSize from the Game view, not the target texture.
        // Apply the same formula by hand so the capture matches the requested size.
        var scaler = canvas.GetComponent<CanvasScaler>();
        if (scaler != null)
        {
            var log = Mathf.Lerp(Mathf.Log(w / reference.x, 2), Mathf.Log(h / reference.y, 2), match);
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ConstantPixelSize;
            scaler.scaleFactor = Mathf.Pow(2, log);
        }

        Canvas.ForceUpdateCanvases();
        foreach (var t in ui.GetComponentsInChildren<TMP_Text>()) t.ForceMeshUpdate();
        cam.Render();

        RenderTexture.active = rt;
        var tex = new Texture2D(w, h, TextureFormat.RGB24, false);
        tex.ReadPixels(new Rect(0, 0, w, h), 0, 0);
        File.WriteAllBytes(outPng, tex.EncodeToPNG());
    }
    finally
    {
        RenderTexture.active = null;
        rt.Release();
        EditorSceneManager.ClosePreviewScene(scene);
    }
}
```

A screen prefab without its own canvas needs one added as its parent for the capture. For a
gameplay-frame backdrop, put a full-stretch `RawImage` showing the frame on a second canvas with
a lower sorting order, on the same camera.

Nothing here is saved: the preview scene closes and the prefab asset is only read.

## UI Toolkit

Runtime panels update in the player loop, so capture in Play mode. A temporary capture component
swaps the document onto a copy of its Panel Settings that renders into a texture:

```csharp
IEnumerator CaptureAt(UIDocument doc, int w, int h, Color backdrop, string outPng)
{
    var rt = new RenderTexture(w, h, 24);
    var ps = Instantiate(doc.panelSettings);
    ps.targetTexture = rt;
    ps.clearColor = true;
    ps.colorClearValue = backdrop;
    doc.panelSettings = ps;
    yield return null;
    yield return new WaitForEndOfFrame();

    RenderTexture.active = rt;
    var tex = new Texture2D(w, h, TextureFormat.RGBA32, false);
    tex.ReadPixels(new Rect(0, 0, w, h), 0, 0);
    File.WriteAllBytes(outPng, tex.EncodeToPNG());
    RenderTexture.active = null;
}
```

Swapping Panel Settings rebuilds the document's tree, which re-runs the controller's `OnEnable`.
Remove the capture component and anything it added once done; it must not end up in a prefab or
scene diff. Compare colours against the mockup: a panel rendered to a texture can come out in a
different colour space from the Game view.

## Critique

Look at every image. Compare it to the mockup at the same aspect and backdrop, then against the
checklist in [readability.md](readability.md). Fix what is wrong and capture again. Report which
images you looked at.

## When capture is not possible

Say so, and give the developer this list, trimmed to what applies:

- The Game view's aspect dropdown at every shipped aspect, and the Device Simulator for notched
  phones.
- Every screen with a gamepad alone: something focused on open, navigation goes where expected,
  back always backs out, focus returns where it was.
- The pause menu with the game paused: its animations still play.
- The longest language, or a pseudo-localised build: nothing overflows or clips.
- The HUD in the brightest and the darkest place in the game.
- The Profiler with the HUD idle: no canvas rebuilds or panel updates every frame.
