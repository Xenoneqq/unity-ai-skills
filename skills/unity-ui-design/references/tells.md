# Tells

Generated and rushed game UI clusters around a few looks. Every one of them is legitimate for
some brief. They are listed because they show up regardless of the game, which makes them
defaults rather than choices. Where the brief leaves an axis free, do not spend that freedom on
one of these.

## Unity defaults left in

The fastest way to look like a prototype. Any of these in a shipped screen reads as unfinished.

- TextMeshPro's `LiberationSans SDF`, or legacy `Text` components with the built-in font.
- The stock sprites: `UISprite` rounded rectangle, `Background`, `Knob`, `Checkmark`.
- A `Button` still on the default Color Tint transition, going slightly grey when pressed.
- UI Toolkit's default runtime theme: grey rounded buttons, grey text fields, untouched.
- Canvas Scaler left on Constant Pixel Size, so the UI shrinks on 4K and overflows on a Steam
  Deck.
- Everything anchored to the centre, so the HUD drifts off the corners at any other aspect ratio.
- No safe-area handling, so a phone notch or a TV's overscan eats the corners.
- An EventSystem with nothing selected on open: the screen is dead until the mouse moves.
- The old `Outline` and `Shadow` effect components stacked on every text.
- A half-transparent black full-screen image behind every popup.
- The same 0.3 second CanvasGroup fade on every panel.

## Generic game UI

What you reach for when nobody asked for anything in particular.

- A dark translucent panel with a thin light border and rounded corners behind everything, the
  same radius on every panel regardless of hierarchy.
- The title screen as a centred column: logo, then Play, Options, Quit as identical buttons of
  identical width.
- Every button label in tracked-out capitals.
- A pulsing glow on the primary button.
- A health bar that fades green to yellow to red, with "100/100" printed on it.
- Neon cyan and magenta on near-black as the answer to "make it look cool".
- Placeholder squares or emoji where icons should be, or one icon style from one pack and a
  second from another.
- Drop shadow on all text, whether or not it sits over anything busy.

## Genre clichés

Each genre has a default costume. Wearing it is not wrong, but it is the look of the genre, not
of this game. Run the swap test from the skill: if the screen would fit any other game in the
genre, it is the costume.

| Genre | The costume |
|---|---|
| Fantasy RPG | Parchment texture, ornate gold frames, a Trajan-like serif such as Cinzel, wax seals. |
| Sci-fi | Cyan hologram lines, hex grids, scanlines, corner brackets, a squared face such as Orbitron. |
| Military shooter | Olive and orange, stencil type, tactical brackets, fake telemetry numbers. |
| Horror | Scratchy or dripping type, blood red on black, a flicker on everything. |
| Post-apocalyptic | Rust, duct tape, spray paint, stencilled crates. |
| Mobile casual | Candy gradients, thick dark strokes, a bouncy scale pop on every element, star bursts. |
| Retro and pixel | Press Start 2P for all text, CRT scanlines, chunky drop shadows. |

## Where the alternative comes from

Not from a different cliché. From the game's own material:

- **Its objects.** What would a person in this world use to show this information? A ship's
  instrument, a ledger, a radio, a chalkboard.
- **Its mechanic.** The one thing the player does most. The signature element usually belongs to
  it.
- **Its art.** Sample the palette from the key art, not from a genre mood board. Match the UI's
  edge quality to the game's: a painterly game with razor-clean vector panels looks pasted on.
- **Its tone.** A comedy and a tragedy with the same mechanics should not share a pause menu.
