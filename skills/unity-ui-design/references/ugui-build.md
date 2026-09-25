# Building with uGUI

uGUI lives in prefab and scene YAML, which only the editor may write. Every screen is built or
changed by an editor script run through `unity-scene-habits`: the connected editor on 6.0 and
newer, batch mode otherwise. That skill's prefab recipes cover opening, editing and saving a
prefab asset without touching a scene.

Where the files go is `unity-file-structure-habits`' call. The paths below are the fallback.

## Tokens first

Put the plan's values in one `UITheme` ScriptableObject: named colours, `TMP_FontAsset`s, the
type scale, spacing and the shared sprites. Builder scripts read it when they construct a
screen, so no script hard-codes a colour. If the game will be re-themed later, add a small
component that applies a named theme colour to its `Graphic`, so a palette change is one asset
edit instead of a rebuild.

For text, a TextMeshPro style sheet gives each role in the type scale a named style, and a
material preset per treatment (outline, shadow, glow) carries the readability rule from the plan.
A material preset is a copy of the font asset's material, assigned as the text's shared material.

## Canvas structure

Follow whatever arrangement the project already has. If it has none: one root canvas prefab
holding the Canvas Scaler and Graphic Raycaster, and each screen a prefab with its own nested
Canvas, so a change in one screen does not rebuild the others. Only the root's scaler applies.

```csharp
var root = new GameObject("GameUI", typeof(RectTransform), typeof(Canvas),
    typeof(CanvasScaler), typeof(GraphicRaycaster));
root.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
var scaler = root.GetComponent<CanvasScaler>();
scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
scaler.referenceResolution = new Vector2(1920, 1080);
scaler.matchWidthOrHeight = 0.5f;
PrefabUtility.SaveAsPrefabAsset(root, "Assets/UI/Prefabs/GameUI.prefab");
Object.DestroyImmediate(root);
```

Widgets used on more than one screen (a menu button, an item slot, a currency counter) are their
own prefabs, nested into the screens. A visual variant of a widget is a prefab variant, not a
copy.

## Layout

- Anchor each element to the edge or corner it belongs to, with the pivot on the same side.
  Backgrounds stretch. Nothing in a HUD is centre-anchored unless it lives at the centre.
- A full-stretch `SafeArea` child under each screen holds everything that must avoid notches and
  overscan:

```csharp
void ApplySafeArea()
{
    var sa = Screen.safeArea;
    var rt = (RectTransform)transform;
    rt.anchorMin = new Vector2(sa.xMin / Screen.width, sa.yMin / Screen.height);
    rt.anchorMax = new Vector2(sa.xMax / Screen.width, sa.yMax / Screen.height);
}
```

  Re-apply it when `Screen.safeArea` or the resolution changes.

## Text

- `TextMeshProUGUI` only, never the legacy `Text`.
- Auto Size off by default. It gives siblings different sizes and breaks the type scale. Design
  the box for the longest translation instead.
- Give each font asset a fallback list for every script the game ships in, with dynamic font
  assets for large character sets such as CJK.

## Sprites

Import UI art as Sprite (2D and UI), set borders in the Sprite Editor for anything that
stretches, and pack each screen's or widget group's sprites into a Sprite Atlas.

## Selectables and input

- Replace the default Color Tint with designed states: Sprite Swap, Animation, or a Color Tint
  whose colours come from the theme. The selected state must be unmistakable from a distance.
- Automatic navigation is fine for a plain column. Set Explicit navigation wherever the layout is
  irregular and automatic picks the wrong neighbour.
- On open, `EventSystem.current.SetSelectedGameObject(first)`. On close, remember the selected
  object and restore it when the player returns.
- If nothing is selected and a gamepad or keyboard input arrives, select the screen's default.
  The mouse clearing the selection must not leave a gamepad player stranded.
- The EventSystem uses `InputSystemUIInputModule` with the Input System, and
  `StandaloneInputModule` with the legacy input manager. The probe's `activeInputHandler` says
  which.

## Performance

- Any change to a graphic rebuilds its whole canvas. Keep what changes every frame (timers, bars,
  markers) on its own nested canvas, apart from static frames and art.
- Turn `raycastTarget` off on every graphic the player does not click, which includes nearly all
  text.
- Hide a panel that toggles often by disabling its `Canvas` component, or with a `CanvasGroup`,
  rather than `SetActive`, which throws its geometry away.
- Avoid Layout Groups and Content Size Fitters on anything that updates often, and do not nest
  them deeply. Lay out once, or by code.
- An Animator on a UI object dirties its canvas every frame, even when idle. Use tweens or code
  for simple motion.
- `RectMask2D` is cheaper than `Mask` for rectangular clipping.
- Long scrolling lists pool their rows instead of instantiating one per item.
- Full-screen transparent images cost overdraw, which matters most on mobile.

## Unscaled time

A pause menu runs while `Time.timeScale` is 0. Its Animators use the Unscaled Time update mode,
its tweens use their library's unscaled or independent update setting, and its coroutines wait
with `WaitForSecondsRealtime`.
