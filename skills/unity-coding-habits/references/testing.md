# Testing gameplay code

How to write Unity Test Framework tests that stay deterministic and do not leak into each other.
Whether the project has tests at all, and how high verification can go without them, is
`unity-agent-worker`'s `references/verification.md`.

## Seams, not devices

Input-driven and random-driven code gets a seam: a nullable override the component reads before
it reads the real source. Tests set the override; the game never does.

```csharp
public struct MovementInput
{
    public Vector2 Move;
    public bool Jump;
}

public class PlayerMotor : MonoBehaviour
{
    MovementInput? inputOverride;

    public void SetInputOverride(MovementInput? input) => inputOverride = input;

    MovementInput ReadInput() => inputOverride ?? ReadDevices();
}
```

The same shape covers chance: `SetDropRollOverride(float?)` on whatever rolls a loot drop, so a
test can force the roll instead of retrying until it happens.

The Input System's own `InputTestFixture` fakes devices instead. It needs the package listed under
`testables` in `Packages/manifest.json`, which is a manifest change, so it is the user's call.
The seam needs nothing.

## Fixed frame time

Set `Time.captureDeltaTime = 1f / 60f` in the fixture's setup and back to `0` in its teardown.
Every frame then advances exactly one sixtieth of a second however fast the machine runs, so a
test that waits 60 frames has simulated one second every time.

## Leave nothing behind

`Destroy` is deferred to the end of the frame, so objects a teardown destroys are still there,
colliders and all, when the next test starts. Use `Object.DestroyImmediate` in `[TearDown]`, or
`Destroy` and then `yield return null` in a `[UnityTearDown]`.

Tests that share a scene collide in space too. A new feature's test area placed in an older
test's line of fire breaks that test. Prefer behaviour tests that build their own geometry at
runtime, and keep a shared test scene for smoke and screenshot tests. If features must share one,
give each its own region of it.

## Long tests

`[UnityTest]` times out after 180 seconds by default. A playthrough or soak test that needs
longer says so: `[UnityTest, Timeout(600000)]`.

## Silence

Tests run through the connected editor play their sound out of the user's speakers. Mute the whole
test assembly with a fixture outside any namespace, which NUnit applies to every test in it:

```csharp
[SetUpFixture]
public class MuteAudio
{
    float volume;

    [OneTimeSetUp] public void Mute() { volume = AudioListener.volume; AudioListener.volume = 0f; }
    [OneTimeTearDown] public void Restore() => AudioListener.volume = volume;
}
```

Test audio by asserting which clip a source played, never by listening.

## Proving a level can be finished

For a level or anything with progression, the strongest test is an autopilot: a bot that plays
it through the same seams a player uses.

- It steers the real controller through its input seam, for example along the corners of a
  `NavMesh.CalculatePath` result, and uses the real interactions: triggers, doors, pickups,
  buttons, timed hazards.
- **No teleporting on the critical path.** The test states its few allowed cheats up front, such
  as an invulnerable player or enemies switched off, and nothing else.
- It asserts the completion event fires within a timeout.

Pair it with key-order tests (each key is reachable only once the doors before it are open) and a
connectivity test. Together they catch what a navmesh query misses: ledges the controller cannot
climb, triggers that never fire, doors that never open.

## Related

- **Screenshots** of anything visual: `unity-scene-habits`, `references/visual-checks.md`.
- **Project-wide import settings** checked by a test: `unity-scene-habits`,
  `references/builders.md`.
