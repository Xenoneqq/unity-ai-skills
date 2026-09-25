# The HTML mockup

A mockup exists to get a yes or a redirect on the look before anything is wired in Unity. It is
cheap to change, so change it freely. It is not the product, so do not polish what the toolkit
will render differently anyway.

## Where it lives

`ui-mockups/<screen>.html` at the repo root. Outside `Assets/` on purpose: Unity would import an
HTML file under `Assets/` as a text asset and give it a `.meta`. One file per screen, fully self
contained: inline CSS, inline script, no build step. Fonts may come from Google Fonts or from the
project's own font files by relative path (`../<project>/Assets/UI/Fonts/Face.ttf`), which works
when the file is opened locally.

Whether the mockups get committed is the developer's call. Leave them in place either way.

## What it must show

- **A stage at the reference resolution.** A fixed-size element, for example 1920 by 1080 CSS
  pixels, scaled to fit the window with a CSS transform. Sizes in the mockup are then the sizes
  in Unity, one to one.
- **Aspect toggles.** Buttons that resize the stage to each aspect the game ships on: 16:9,
  21:9, 16:10, 4:3, and portrait phone if mobile is a target. Anchored elements must hold their
  corners as the stage changes, exactly as they will in Unity.
- **A safe-zone overlay** that can be switched on to show the margins from the plan.
- **Backdrop toggles.** The gameplay screenshot if the developer gave one, plus a bright busy
  backdrop and a dark one. Readability over the world is the thing a page mockup most easily
  hides.
- **States side by side.** For each interactive element, normal, hover, selected, pressed and
  disabled next to each other, and a way to see which one gamepad focus would show.
- **Real content at the extremes.** The longest name, the biggest number, the empty list. Not
  lorem ipsum, not "Item 1".
- **The signature moment**, if it is motion, as a CSS animation that can be replayed with a
  button. Everything else stays still.

## Write CSS the toolkit can follow

Name the CSS custom properties exactly as the tokens will be named in Unity (`--color-ink`,
`--font-size-body`, `--space-2`), so the palette carries over by copy and paste.

For UI Toolkit, write the mockup in the subset USS understands, and the stylesheet ports almost
directly: flexbox layout only, sizes in `px` and `%`, `border-radius`, `border-*`,
`background-color`, background images, `opacity`, `translate`, `scale`, `rotate`, and
transitions on those. Check the project's version for anything else.

Either way, avoid what neither toolkit draws natively: CSS grid, `box-shadow`, gradient
backgrounds, `backdrop-filter` blur, blend modes. If the look needs one of them, it becomes a
sprite or a 9-sliced image in Unity. Mark those elements in the mockup with a comment so the
build step knows an asset is needed.

Text will not match exactly. TextMeshPro and UI Toolkit render signed-distance-field text, with
outline and glow as material settings; CSS `text-shadow` and `-webkit-text-stroke` only
approximate them. Say so to the developer when the look depends on it.

## Showing it

Open it for the developer: the built-in browser if the environment has one, otherwise `open` on
macOS, `xdg-open` on Linux or `start` on Windows. Screenshot it yourself if you can, at two
aspects over both backdrops, and critique before asking. Then ask for a go-ahead or changes.
