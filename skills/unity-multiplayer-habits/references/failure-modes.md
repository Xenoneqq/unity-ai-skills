# Working backwards from a symptom

Multiplayer failures rarely throw. Start from what the screens disagree about.

## Nothing appears on the client

| Also true | Cause |
|---|---|
| Client console: `Failed to spawn server object, did you forget to add it to the NetworkManager?` | The prefab is not in Spawnable Prefabs and was never `RegisterPrefab`ed. |
| No console output at all, object exists on the server | The object was `Instantiate`d but never `NetworkServer.Spawn`ed. |
| `GameObject … is a prefab, it can't be spawned` | `NetworkServer.Spawn` was handed the asset instead of an instance. |
| `SpawnObject … has no NetworkIdentity` | Identity missing, or on a child rather than the prefab root. |
| Works as host, fails for a real client | Something in the spawn path reads a local singleton that only exists in the host process. |

## It works for whoever did it, and for nobody else

The change was made locally and never left the machine. Either the code path runs on the client
and should have gone through a `[Command]`, or the server changed a plain field where a SyncVar
was needed.

Check `syncDirection`. A client writing a `ServerToClient` SyncVar updates its own copy, sends
nothing, and is overwritten on the next sync — silently.

## It works for everyone who was there, and not for whoever joined later

An event was sent where a fact belonged. `[ClientRpc]` reaches only the clients connected at the
time; nothing replays it. Move the durable part into a SyncVar and set it on the server **before**
`NetworkServer.Spawn`, so it rides the spawn payload.

The same shape appears with `OnStartClient` doing work that depended on an RPC that has not
arrived. Read the SyncVar instead — the initial payload is deserialized before `OnStartClient`
runs, so the value is already there.

## The hook never fires

Three causes, in order of likelihood:

1. The value never actually changed. Mirror compares before invoking; assigning the same value is
   a no-op.
2. It is the initial spawn and the server value equals the field's inspector default. The
   comparison is against that default, so nothing "changed". Do initial setup in `OnStartClient`.
3. You are on a dedicated server. The hook fires on clients from deserialization, and on a host
   directly from the setter — but a dedicated server writing its own SyncVar does not call it.
   Call the method yourself.

## The hook fires too early

Hooks run during deserialization of the spawn payload, **before** `OnStartClient`. A hook that
touches something `OnStartClient` sets up will hit a null. Either move the setup earlier, or make
the hook tolerate not being ready and let `OnStartClient` do the first application.

## Console says `Command … without authority`

The calling client does not own the object the method is declared on. Decide which is true:

- It should be owned — spawn it with an owner connection, or `AssignClientAuthority`.
- It is a shared object such as a scene manager — use `[Command(requiresAuthority = false)]`, and
  identify the caller inside the body from `NetworkConnectionToClient sender = null`. Opting out
  of the check means you now do the check.

## Correct on the host, wrong on a dedicated server (or the reverse)

On a host, `isServer` and `isClient` are both true and the two roles share a process. The usual
causes:

- Code that means "the dedicated server" guarded with `isServer` instead of `isServerOnly`.
- A static "local player" or "local manager" referenced inside server code. On a host it resolves
  to the host's own object, so the wrong player takes the effect and it looks like it worked.
- Client-only components assumed present — a camera, an input reader, a UI canvas — on an object
  the dedicated server also owns.

## The same thing happens twice

An RPC and a SyncVar hook both applying the same change. Pick one: fact or event, never both.
Double-firing also comes from a hook that writes the SyncVar it hooks; Mirror guards against the
immediate recursion, but the logic is still wrong.

## The player object is wrong after a reconnect

A static set in `OnStartClient` or `OnStartLocalPlayer` and never cleared. Clear it in the
matching `OnStop*`. In the editor, statics survive play-mode runs unless the project has domain
reload disabled *and* handles it, so the second run inherits the first run's ghosts.

## Position stutters or rubber-bands

- Two sources writing the same transform: a NetworkTransform plus gameplay code moving the object
  on the other side. One writer only.
- `syncDirection` on the NetworkTransform not matching who actually drives the object.
- A `CharacterController` or non-kinematic `Rigidbody` fighting a teleport. Mirror's transform
  components call `Physics.SyncTransforms()` on reset for this reason; custom teleports need the
  same care.

## Everything is correct but slow to appear

`syncInterval` on that NetworkBehaviour, the server tick rate, or an interest-management setting
excluding the observer. Check in that order — the first is per component and the most likely, the
last is global and the least likely to be what you changed.
