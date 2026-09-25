# The quality floor

Build to all of this without being asked. Where a check does not apply to the game, skip it and
move on. Where it applies and cannot be met, say so in the report.

## Glanceable HUD

- The player reads the HUD in peripheral vision, mid-action, in under a second. Each element
  answers one question.
- Shape and position carry meaning before text does. A bar can be read at a glance; a number
  cannot.
- Contextual beats constant: ammo when the weapon is out, the boss bar in the boss fight.
- Critical warnings (low health, incoming damage) come from the edge of vision toward the
  centre, never the reverse.

## Contrast over the world

- Test every text and icon over the brightest and the darkest frame the game can produce, not
  over a flat colour.
- Readability comes from an outline, a backplate, a shadow or a darkened region behind the
  element. Pick one per element type in the plan and use it consistently.

## Resolution and aspect

- A scaler set to scale with screen size at the plan's reference resolution: Canvas Scaler for
  uGUI, the Panel Settings scale mode for UI Toolkit.
- Every element anchored to the edge or corner it belongs to. Backgrounds stretch.
- Content inside `Screen.safeArea` on mobile and inside the title-safe margin on TV.
- Checked at every aspect the game ships on, including 21:9 and 16:10 on PC.

## Input

- Gamepad: focus on open, predictable navigation, back always backs out, focus remembered when
  returning to a screen.
- Mouse and keyboard: hover and focus are distinct, and Tab or arrows work in menus.
- Touch: targets big enough for a thumb, nothing essential under the thumbs' resting spots.
- Prompts show the glyph of the device last used, and swap when the player changes device.

## States and data

- Normal, hover, selected, pressed and disabled for every interactive element.
- Empty, loading, full, locked and error states for every list and slot.
- The game states the HUD exists for: low health, no ammo, a key or item missing, a timer about
  to run out. Designed up front, not added when a playtester misses them.
- Numbers at their extremes, names at their longest, currencies formatted for the locale.

## Localisation

- Room for text 30 to 40% longer than English. Prefer layouts that grow over auto-sizing text.
- Font fallbacks for every script the game ships in, for example CJK and Cyrillic.
- If the game ships right-to-left languages, the layout mirrors.
- No text baked into images.

## Accessibility

- Never encode meaning in red against green alone. Add shape, icon or position.
- A UI scale option and a subtitle size option where the platform expects them.
- Hold-to-confirm has a toggle alternative.
- A reduced motion option turns off screen shake and flashing UI.

## Motion and sound

- Every confirm, back, error and reward has feedback, visual and audible.
- Menu transitions are short and never block input.
- Pause menus run on unscaled time.
- No idle motion on the HUD.

## Performance

The toolkit build references hold the specifics. The general rule for both: UI that changes
every frame is kept apart from UI that never changes, and nothing rebuilds a string or a layout
when its value has not changed.
