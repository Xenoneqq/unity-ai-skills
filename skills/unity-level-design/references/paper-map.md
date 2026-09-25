# The paper map

A paper map is for a yes or a redirect on the layout before any geometry exists. Moving a room on
it costs a keystroke; moving it in a blockout costs a rebuild and a re-check. Change it freely.

It is optional. The skill offers it; the developer decides. Build one when they accept, or for
your own use when laying the level out at scale will catch problems early.

## Big maps

A single drawing stops working once the level is too large to read at one scale: an open world,
a large outdoor region, a city. Map the area being built instead, at a scale where a doorway is
still visible, and add a small overview that only shows how that area connects to its
neighbours and to the major landmarks.

## Where it lives

`level-plans/<level>.html` at the repo root, beside the written plan and outside `Assets/`, so
Unity never imports it. One self-contained file: inline SVG, CSS and script, no build step. It
opens in any browser, locally.

Whether plans get committed is the developer's call. Leave them in place either way; the next
pass on the level starts from them.

## What it must show

- **Scale.** A metre grid, and the player's footprint drawn to scale in a corner, so every room
  and corridor can be judged against the person walking it. In 2D, draw tiles and the player
  sprite's bounds.
- **The critical path** as one continuous line from spawn to exit, with arrows. Optional routes
  in a lighter line.
- **Beats**, numbered in play order along the path, each with a one-line label taken from the
  plan.
- **Landmarks**, and a sightline cone from the spawn and from each beat towards what the player
  should see next.
- **Gates and keys.** What blocks progress, and where the thing that opens it is.
- **Loops and shortcuts**, drawn so it is obvious where they rejoin earlier ground, and which way
  they open. A one-way door or drop gets an arrow.
- **Height.** Shade or label floor heights, and mark every jump, drop and climb with its size in
  metres, so the metrics can be checked on paper.
- **Cover and threat** for combat spaces: where enemies start, where the player can hide, and
  the lines between them.

Toggles to show and hide each layer keep a busy map readable. A side-view section through the
level earns its place whenever height carries the design.

## What it must not do

It is a diagram of play, not a picture. No textures, no props, no attempt at the final look;
those invite comments on the wrong thing. The dressing pass is where the level stops being
tidy. On paper, tidy is the point.

## Showing it

Open it for the developer: the built-in browser if the environment has one, otherwise `open` on
macOS, `xdg-open` on Linux or `start` on Windows. Screenshot it yourself if you can and check it
against the plan and [tells.md](tells.md) before asking. Then ask for a go-ahead or changes.

Once approved, the map is the spec for the blockout. The top-down capture in
[verification.md](verification.md) is compared against it, and any difference the build forced
gets said out loud.
