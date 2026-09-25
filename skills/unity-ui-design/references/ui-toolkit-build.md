# Building with UI Toolkit

UXML, USS and TSS files are authored text, meant to be written by people, so writing them
directly is fine. That is the difference from scene and prefab YAML, which the engine serializes
and which only the editor may write. The `.meta` beside each new file is still the editor's job:
let it import the file, never write the meta yourself, and commit the two together.

Where the files go is `unity-file-structure-habits`' call. The paths below are the fallback.

## Tokens first

One stylesheet holds every value from `UI_STYLE.md`, as variables on `:root`:

```css
/* Assets/UI/Theme/Tokens.uss */
:root {
    --color-ink: #2b2118;
    --color-surface: #e9dcc3;
    --color-accent: #c2452d;
    --font-size-body: 28px;
    --font-size-title: 64px;
    --space-2: 16px;
    --space-4: 32px;
}
```

A theme stylesheet applies it to the whole panel, on top of Unity's default theme. Keep the
default import: controls such as `ScrollView` and `Slider` draw their internals from it. Then
override every visible style, or the default grey look shows through.

```css
/* Assets/UI/Theme/Game.tss */
@import url("unity-theme://default");
@import url("Tokens.uss");
@import url("Controls.uss");
```

`Controls.uss` restyles the shared controls (buttons, toggles, sliders) once, with every state,
so screens never style a button themselves.

Screens use the variables and never a literal colour or size:

```css
.menu-button {
    color: var(--color-ink);
    font-size: var(--font-size-body);
    -unity-font-definition: url("../Fonts/Display SDF.asset");
    -unity-text-outline-width: 1px;
    -unity-text-outline-color: var(--color-surface);
    transition-property: scale, opacity;
    transition-duration: 0.1s;
}
.menu-button:hover { opacity: 0.9; }
.menu-button:focus { scale: 1.06 1.06; border-color: var(--color-accent); }
.menu-button:active { scale: 0.97 0.97; }
.menu-button:disabled { opacity: 0.4; }
```

`:focus` is what a gamepad player sees. It must be unmistakable on its own, not a slight
variation of `:hover`.

## A screen

```xml
<!-- Assets/UI/PauseMenu/PauseMenu.uxml -->
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <ui:Style src="PauseMenu.uss" />
    <ui:VisualElement name="root" class="pause">
        <ui:Label text="Paused" class="pause__title" />
        <ui:Button name="resume" text="Resume" class="menu-button" />
        <ui:Button name="settings" text="Settings" class="menu-button" />
        <ui:Button name="quit" text="Quit to Title" class="menu-button" />
    </ui:VisualElement>
</ui:UXML>
```

Name every element code needs to find. Style through classes, not names.

## Wiring it up

Two assets, both created through the editor, never by writing YAML:

- **One Panel Settings asset per UI layer**, shared by every screen on it, carrying the scale
  mode, reference resolution and theme from the plan.
- **A prefab per screen**, holding a `UIDocument` that points at the Panel Settings and the UXML,
  plus the screen's controller. Built with the prefab recipes in `unity-scene-habits`.

```csharp
var ps = ScriptableObject.CreateInstance<PanelSettings>();
ps.scaleMode = PanelScaleMode.ScaleWithScreenSize;
ps.referenceResolution = new Vector2Int(1920, 1080);
ps.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight;
ps.match = 0.5f;
ps.themeStyleSheet = AssetDatabase.LoadAssetAtPath<ThemeStyleSheet>("Assets/UI/Theme/Game.tss");
AssetDatabase.CreateAsset(ps, "Assets/UI/Theme/GamePanel.asset");
```

The controller queries its elements in `OnEnable`, because the `UIDocument` rebuilds its tree
whenever it is re-enabled, and focuses the first control once the panel has laid out:

```csharp
void OnEnable()
{
    var root = GetComponent<UIDocument>().rootVisualElement;
    var resume = root.Q<Button>("resume");
    resume.clicked += Resume;
    root.RegisterCallback<NavigationCancelEvent>(_ => Resume());
    root.schedule.Execute(() => resume.Focus());
}
```

## Input

With the Input System package, gamepad and keyboard navigation reach runtime panels through an
EventSystem with an `InputSystemUIInputModule`. Check the scene or bootstrap prefab has one. A
screen with no focused element on open does not respond to a gamepad at all.

Remember the focused element when a screen closes and restore it when the player comes back.

## Safe area

UI Toolkit does not apply `Screen.safeArea` itself. Pad the root to it, and re-apply on
`GeometryChangedEvent` so rotation and resolution changes are covered:

```csharp
void ApplySafeArea(VisualElement root)
{
    var sa = Screen.safeArea;
    var topLeft = RuntimePanelUtils.ScreenToPanel(root.panel, new Vector2(sa.xMin, Screen.height - sa.yMax));
    var bottomRight = RuntimePanelUtils.ScreenToPanel(root.panel, new Vector2(sa.xMax, Screen.height - sa.yMin));
    var size = root.panel.visualTree.layout.size;
    root.style.paddingLeft = topLeft.x;
    root.style.paddingTop = topLeft.y;
    root.style.paddingRight = size.x - bottomRight.x;
    root.style.paddingBottom = size.y - bottomRight.y;
}
```

## USS is not CSS

- Layout is flexbox only. No grid, no media queries, no `calc()`.
- No `box-shadow` and no gradient backgrounds. A soft shadow or a gradient is a sprite, and a
  sprite with borders set in the Sprite Editor 9-slices as a background image.
- Animate `translate`, `scale`, `rotate` and `opacity`. They skip layout. Animating `width`,
  `left` or `margin` relayouts every frame.
- Custom shaders, world-space panels and some filters depend on the editor version. Check the
  project's version before planning around one.

## Performance

- Elements that move every frame, such as a marker tracking a target, get
  `usageHints = UsageHints.DynamicTransform`.
- Long lists, inventories most of all, use `ListView` with `makeItem` and `bindItem`, which only
  creates the rows on screen.
- Never clear and rebuild a subtree to update it. Change the label's text, and only when the
  value changed.

## Motion and sound

Put UI sounds in one place: callbacks registered on each screen's root for `FocusInEvent` and
`ClickEvent` that play the plan's sounds, so no button carries its own audio code. Check that the
pause menu's transitions still run with `Time.timeScale` at 0.
