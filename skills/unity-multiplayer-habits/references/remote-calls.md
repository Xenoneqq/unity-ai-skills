# Commands, RPCs and SyncVars in detail

Every name here exists in current Mirror. Older projects differ — confirm against
`Assets/Mirror/Core` before using one, and prefer whatever the project already uses.

## Commands — client asks, server decides

```csharp
[Command]
void CmdOpenDoor(NetworkIdentity door)
{
    if (door == null) return;                      // it may have despawned in flight
    if (!door.TryGetComponent(out DoorController d)) return;
    if (d.IsLocked()) { TargetSyncDoor(door, d.IsOpen(), true); return; }  // reject + correct
    d.Open();
}
```

- Runs on the server, called from a client. Requires the calling connection to **own** the
  object the method is on.
- `[Command(requiresAuthority = false)]` lets any client call it — necessary for a method on an
  unowned scene object such as a shared manager. It removes Mirror's only built-in check, so
  the body must identify and authorise the caller itself.
- **The sender.** Add `NetworkConnectionToClient sender = null` as the last parameter and Mirror
  fills it in server-side. You cannot pass a `NetworkConnection` as an ordinary parameter; the
  weaver rejects it with a message pointing you at exactly this. `connectionToClient` on an owned
  object is the same information.
- `connectionToClient.identity` is the caller's player object on the server. That, not a
  parameter, is how you find out who is asking.
- `[Command(channel = Channels.Unreliable)]` exists for input-rate traffic that may be dropped.
  Default is reliable and ordered; leave it there unless you have a reason.

## ClientRpc — server tells every observer

```csharp
[ClientRpc]
void RpcPlayImpact(Vector3 at) => Instantiate(impactVfx, at, Quaternion.identity);
```

- Callable only on the server, only on a **spawned** object. Before `NetworkServer.Spawn` there
  are no observers, so the call goes nowhere.
- `[ClientRpc(includeOwner = false)]` skips the owning client — the right tool when the owner
  already played the effect locally, instead of a hand-rolled `isOwned` check in the body.
- Reaches only clients connected and observing *now*. Nothing about an RPC is replayed to a late
  joiner. If the effect leaves lasting state, the state belongs in a SyncVar and the RPC is only
  the flourish on top.

## TargetRpc — server tells one client

```csharp
[TargetRpc]
void TargetPickupRejected(string reason) { /* runs on the owner's client */ }

[TargetRpc]
void TargetShowMessage(NetworkConnection target, string text) { /* runs on `target` */ }
```

The leading `NetworkConnection` parameter is optional. Without it Mirror sends to the object's
`connectionToClient`; with it you choose the connection. Mirror strips that parameter before
serializing, so it costs nothing on the wire. Pick one form per project and stay with it —
mixing them is a reliable source of "why did nobody get this".

This is the right shape for answers and rejections: the client asked by `[Command]`, the server
replies to that client alone rather than broadcasting a correction to everyone.

## SyncVars — facts, not events

```csharp
[SyncVar(hook = nameof(OnHealthChanged))]
int health = 100;

void OnHealthChanged(int oldValue, int newValue) => healthBar.Set(newValue);
```

- Hook signature is exactly `void Name(T oldValue, T newValue)`. Instance, static and virtual
  hooks all work. A mismatched signature is a weaver error, not a runtime one — read the console
  after a compile.
- **Direction.** `syncDirection` defaults to `SyncDirection.ServerToClient`. The server writes,
  clients read. A client writing such a field changes only its own copy: nothing is transmitted
  and the next sync overwrites it, with no warning.
- **`SyncDirection.ClientToServer`** flips it, for owner-driven state. The server still validates
  it on arrival, and a client that does not own the object cannot write it.
- **Where the hook fires.** On a client, the hook runs from deserialization. On a *host*, setting
  the SyncVar calls the hook directly in the setter. On a dedicated server it does not fire at
  all — so server logic that must react to its own write calls the method itself.
- **The hook fires only when the value actually changed.** At spawn that comparison is against
  the field's inspector default, so a server value equal to the default fires nothing. Never put
  initial setup in a hook; put it in `OnStartClient`, where the initial payload has already been
  applied.
- **Collections** are `SyncList<T>`, `SyncDictionary<K,V>` and `SyncSet<T>`, declared `readonly`
  and initialized inline. They replicate per-operation deltas and have a `Callback` event rather
  than a hook. They are not a place for large data — every insert is traffic.

## Serializing your own types

Mirror's weaver generates readers and writers for structs and simple classes automatically. Two
cases it cannot do for you:

**Asset references.** Never try to send a `ScriptableObject` or a prefab. Send an id and resolve
it against a registry on the other side:

```csharp
public static void WriteItem(this NetworkWriter writer, ItemDefinition item)
    => writer.WriteInt(item.id);

public static ItemDefinition ReadItem(this NetworkReader reader)
    => ItemRegistry.Get(reader.ReadInt());   // null here is a bug worth logging loudly
```

Put them in a static class; the weaver finds extension methods on `NetworkWriter`/`NetworkReader`
anywhere in the assembly. Both sides must resolve the same id to the same asset, so the registry
has to be deterministic — an explicit id field, not a load order.

**Scene and spawned objects.** `NetworkIdentity`, `GameObject` and `NetworkBehaviour` parameters
are serialized as a `netId` and resolved against the receiver's spawned set. That resolution can
fail — the object may have despawned in flight, or not yet have spawned on that client — so a
null check at the top of every handler is not defensive clutter, it is the normal case.

## Method guards

`[Server]` and `[Client]` make a method return early on the wrong side and log a warning;
`[ServerCallback]` and `[ClientCallback]` do the same silently, for methods Unity calls on both
sides such as `Update`. They guard the method — adding `if (!isServer) return;` inside a
`[Server]` method is dead code. They do **not** make a method remote: a `[Server]` method called
from client code simply does nothing.
