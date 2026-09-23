# Spawning, ownership and object lifetime

## Two kinds of networked object

| | Scene object | Spawned object |
|---|---|---|
| Where it starts | placed in a scene at edit time | instantiated from a prefab at runtime |
| Identified by | `sceneId`, baked at build time | `assetId`, from the prefab |
| Needs registering | no | **yes** |
| Who creates it | the scene, on both sides | the server, then Mirror on clients |

A scene object with a `NetworkIdentity` is deactivated during the scene post-process and
reactivated by `NetworkServer.SpawnObjects()` when the server starts. Both sides already have the
object, so Mirror only has to match them up by `sceneId` — which is why scene objects need no
registration and why they cannot be `Instantiate`d.

Managers, doors, levers, fixed machinery: scene objects. Players, projectiles, loot, enemies:
spawned. A scene object never needs a spawn prefab entry; a spawned one always does.

## Registering spawnable prefabs

The failure is silent by design: the server spawns the object, the client receives a message for
an `assetId` it does not know, logs one error and moves on. Nothing is visibly wrong on the
server, which is usually where you are looking.

Two ways to register, and the client must do it **before connecting**:

- Drag the prefab into the NetworkManager's **Spawnable Prefabs** list. Enough for most projects.
- `NetworkClient.RegisterPrefab(prefab)` for prefabs discovered at runtime — from a registry
  asset, an addressable, or a mod folder. Call it from the manager's client-start path.

The player prefab is registered automatically and must *not* also be in the spawnable list;
Mirror's `OnValidate` removes it and warns if you add it.

Every spawnable prefab needs a `NetworkIdentity` on its **root**. A prefab without one cannot be
spawned at all; one with an identity on a child instead of the root behaves unpredictably.

If the project keeps a registry asset listing spawnables rather than a hand-dragged inspector
list, use it. That is a better arrangement than the default — a list in a scene file is a merge
conflict waiting for the next person, per
[`unity-scene-habits`](../../unity-scene-habits/SKILL.md).

## Spawning in the right order

```csharp
[Server]
public void DropLoot(Vector3 at, int itemId)
{
    var drop = Instantiate(lootPrefab, at, Quaternion.identity);
    drop.GetComponent<LootContents>().itemId = itemId;   // SyncVar, set BEFORE spawning
    NetworkServer.Spawn(drop);
}
```

State set before `NetworkServer.Spawn` is serialized into the spawn message itself, so every
client — including one that connects tomorrow — receives the object already correct. State
pushed afterwards by `[ClientRpc]` arrives as a second message that a late joiner never sees.

`NetworkServer.Spawn` refuses a prefab asset ("it can't be spawned, Instantiate it first"),
refuses an object with no `NetworkIdentity`, and refuses to run when the server is not active.
All three log an error rather than throwing, so a spawn that "did nothing" is a console read.

## Ownership

```csharp
NetworkServer.Spawn(turret, conn);          // spawn already owned by that connection
identity.AssignClientAuthority(conn);       // hand ownership over later
identity.RemoveClientAuthority();           // take it back
```

Ownership means two things and only two: the owner may call `[Command]` methods on the object,
and the owner may write its `ClientToServer` SyncVars. It does not make the client trusted — the
server still validates.

Give ownership when the client must drive the thing responsively: its own character, a vehicle it
is driving, a cursor. Do not give it away so a client can update state the server should own; that
is how authority leaks out of the server one convenience at a time.

`NetworkServer.AddPlayerForConnection(conn, playerObject)` makes an object that connection's
player — it sets ownership and marks it as the local player on that client. Override
`OnServerAddPlayer` on the NetworkManager subclass when spawn points, names or per-player setup
are involved, and call `AddPlayerForConnection` from it.

## Despawning

| Call | Effect on clients | Effect on the server |
|---|---|---|
| `NetworkServer.Destroy(obj)` | removed | destroyed |
| `NetworkServer.UnSpawn(obj)` | removed | kept, reusable |

Both are server-only. `NetworkServer.Destroy` called on a client logs a warning explaining that a
client can only *ask* — by `[Command]` — which is exactly the right mental model. A client that
`Destroy`s a networked object locally puts itself permanently out of sync, and nothing tells it.

A scene object passed to `NetworkServer.Destroy` is unspawned and reset rather than destroyed, so
it can be spawned again later.

**Pooling** needs a custom spawn handler, registered on the client with
`NetworkClient.RegisterPrefab(prefab, spawnHandler, unspawnHandler)` or
`RegisterSpawnHandler(assetId, …)`. Mirror checks spawn handlers *before* registered prefabs, and
unspawn handlers before falling back to `Destroy`, so register both halves or objects leak.

## Disconnects

Objects owned by a connection are destroyed when it drops. Anything that must outlive the owner —
a dropped backpack, a placed structure — either must not be owned by that connection, or has to be
re-spawned under server ownership before the owner leaves. Handle it in `OnServerDisconnect`, and
call `base.OnServerDisconnect(conn)` so Mirror still does its own cleanup.

Clear statics in `OnStopServer` / `OnStopClient` / `OnStopLocalPlayer`. A cached "local player"
or "the manager" that survives a disconnect points at a destroyed object on the next session, and
in the editor that state persists across play-mode runs.
