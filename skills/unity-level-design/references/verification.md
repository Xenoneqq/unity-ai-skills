# Proving the level plays

Automated checks catch what is broken. They cannot say whether it is fun, readable or well
paced; only a person playing it can. Run the checks, look at the captures, and then say plainly
what still needs a playtest.

These recipes follow the markers described in [blockout.md](blockout.md). They are starting
points: adapt them to the project and check their output before trusting it.

## Reachability

Bake navigation with agent settings from `LEVEL_METRICS.md`, then ask for a complete path from
the spawn to every beat and to the exit:

```csharp
var spawn = GameObject.Find("Spawn").transform.position;
foreach (var marker in GameObject.FindGameObjectsWithTag("EditorOnly"))
{
    if (!marker.name.StartsWith("Beat_") && marker.name != "Exit") continue;
    var path = new NavMeshPath();
    NavMesh.CalculatePath(spawn, marker.transform.position, NavMesh.AllAreas, path);
    if (path.status != NavMeshPathStatus.PathComplete)
        Debug.LogError($"Unreachable from spawn: {marker.name} ({path.status})");
}
```

A navmesh knows walking, not jumping, climbing or swimming. Wherever the route depends on one of
those, either connect the areas with a `NavMeshLink` that mirrors the move, or check the move
directly, as below. A beat that is only reachable by a jump the navmesh does not know about
reports as unreachable; that is a missing link, not necessarily a broken level.

For a 2D level, walk the tilemap instead: a flood fill over walkable cells from the spawn, with
jump arcs from the metrics as the allowed moves between platforms.

## Jumps and heights

For each `Jump_NN_From` and `Jump_NN_To` pair, measure the horizontal gap and the height change
and compare them with the metrics, including the margin:

```csharp
var from = GameObject.Find($"Jump_{n:00}_From").transform.position;
var to = GameObject.Find($"Jump_{n:00}_To").transform.position;
var gap = Vector2.Distance(new Vector2(from.x, from.z), new Vector2(to.x, to.z));
var rise = to.y - from.y;
if (gap > metrics.comfortableJumpDistance || rise > metrics.comfortableJumpHeight)
    Debug.LogError($"Jump {n} is {gap:0.00} m across and {rise:0.00} m up: beyond comfortable");
```

Do the same for anything the level relies on staying out of reach: a ledge the player must not
climb has to be above the maximum jump height, not level with it.

Run these again after dressing. Dressing that nudges a crate into a doorway or onto a jump
landing is the usual way a proven blockout breaks.

## Captures

Look at the level from where the player will. Render from each marker with a temporary camera at
the player's eye height, pointed at the next marker, with the player camera's field of view, and
a top-down orthographic view over the whole level to compare with the plan and any paper map:

```csharp
static void CaptureFrom(Vector3 eye, Vector3 lookAt, float fov, int w, int h, string outPng)
{
    var go = EditorUtility.CreateGameObjectWithHideFlags("LevelCapture", HideFlags.HideAndDontSave, typeof(Camera));
    var cam = go.GetComponent<Camera>();
    var rt = new RenderTexture(w, h, 24);
    try
    {
        cam.fieldOfView = fov;
        cam.transform.SetPositionAndRotation(eye, Quaternion.LookRotation(lookAt - eye));
        cam.targetTexture = rt;
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
        Object.DestroyImmediate(go);
    }
}
```

On the connected path, `unity command screenshot` in Play mode captures what the real player
camera sees, which beats any approximation; `unity-scene-habits` has the command. In batch mode,
drop `-nographics` so there is something to render with.

Write captures to `level-captures/` at the repo root, outside `Assets/`. They are scratch, not
something to commit. Never save the scene after a capture run.

Then look at every image and ask of each one: can the player tell where to go next? Is the thing
the level wants to reveal later hidden from here? Does anything read as a wall of noise, or as an
empty box? Fix, and capture again.

## Playing it through

Reachability says a path exists. An autopilot proves the player can take it: a PlayMode test
that drives the real controller through its input seam along the corners of a
`NavMesh.CalculatePath` result, and uses the real interactions (doors, keys, pickups, buttons,
timed hazards) until the level's completion event fires. `unity-coding-habits`'
`references/testing.md` has how to write one.

- **No teleporting on the critical path.** State the few cheats the test allows, such as an
  invulnerable player or enemies switched off, and nothing else.
- **Key order.** For each key or unlock, a test that it can only be reached once everything
  before it is open. A key reachable too early breaks the intended order silently.
- **Connectivity.** Every area connects to the rest; nothing is sealed off.

## The playtest checklist

What only a person can check. Hand the developer the parts that apply:

- Play from the spawn without instructions: where did you go first, and was it where the level
  meant you to go?
- Did you ever stop because you did not know where to go? Where?
- Did anything block you that should not have: a prop, a lip, a gap, an invisible wall?
- Did each beat land in the order the plan says? Did the level breathe between them?
- Were dead ends worth the trip?
- Did the loop or shortcut back to earlier ground work, and did it feel like a discovery?
- With the camera and controls the game really ships with, was anything too tight, too far or
  too high?
- Did enemies come at you from more than one side, or bunch up on one path?
- Did a noise pull in enemies from places that should not have heard it?
- Could you tell what each pickup does from how it looks, before picking it up? Did picking it up
  say what it did?
