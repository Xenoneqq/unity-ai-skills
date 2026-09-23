---
name: unity-multiplayer-habits
description: >
  Build multiplayer correctly in a Unity project using Mirror: let the server own game state and
  the client own its own movement, pick the right direction for every remote call, re-validate
  anything a client sends, register spawnable prefabs so they actually appear, branch on the
  right identity flag, and never call it done without two clients agreeing. Settles which
  networking framework a project uses before any networked code exists. Use when: adding or
  changing networked behaviour, "sync this across clients", "why does this only work for the
  host", "it works in the editor but the other player sees nothing", "my prefab doesn't spawn
  for clients", `[Command]`, `[ClientRpc]`, `[SyncVar]`, `NetworkBehaviour`, Mirror, "test with
  two clients", or "/unity-multiplayer-habits".
---

# Unity multiplayer habits

Two rules about who decides what. Everything below is how to keep them.

**The server owns game state.** Health, inventory, score, loot, doors, who died, what spawned.
The server decides and tells clients. A client *asks*; it does not announce. This is the part a
cheater profits from forging, so this is the part the server keeps.

**The client owns its own body.** Player movement is the standard exception, and
client-authoritative is the default to reach for: server-authoritative movement only feels good
once you have client-side prediction *and* server reconciliation, and without them every input
waits a full round trip. Mirror agrees — `NetworkTransformBase.Reset()` sets
`syncDirection = SyncDirection.ClientToServer`, so a freshly added NetworkTransform is
client-authoritative out of the box. It is the developer's call, not this skill's: if the project
already chose otherwise, that choice wins.

Correctness first, because these bugs are the expensive kind. They reproduce only with two
clients and they fail *silently* — no exception, no warning, just two screens that disagree.

## 0. Before any of this: which framework

**If the project already networks, that decision is made.** Follow it. Never introduce a second
networking stack alongside an existing one — they fight over the same lifecycle and nothing
survives the merge.

```bash
ls -d "$ROOT/Assets/Mirror" 2>/dev/null                       # Mirror, vendored under Assets
grep -n 'netcode.gameobjects' "$ROOT/Packages/manifest.json"  # Netcode for GameObjects
grep -rl 'NetworkBehaviour' "$ROOT/Assets" --include='*.cs' | head
```

**Only when nothing is networked yet is this a question — and it is the user's to answer.** Work
out what is actually available first, then ask; do not present an option the project cannot use.

Netcode for GameObjects needs **Unity 2021.3 or later**. Read the editor version from
`ProjectSettings/ProjectVersion.txt` before asking:

| Project editor | What to offer |
|---|---|
| 2021.3 or newer | Both. A real choice — ask. |
| 2020.3 or older | Mirror. NGO installs only from a git URL there, which is not a footing to start a project on. |
| Unity 6000.3+ | Both, but NGO must be 2.x — 1.x is not supported there. |

Frame the question so the user can actually decide, and do not pick for them:

- **Netcode for GameObjects** is Unity's own, installed from the Package Manager
  (`com.unity.netcode.gameobjects`), and lines up with Unity's other multiplayer services.
- **Mirror** is third-party, vendored into `Assets/`, older and heavily used, with a large body
  of community answers behind it.

Neither is the right answer in general. What matters is that one gets chosen deliberately, before
any networked code exists, rather than arrived at by accident.

**The rest of this skill is written for Mirror.** The principles below — server owns state, the
client owns its own body, validate on the server, register what you spawn, test with two clients —
hold for either. The API does not: NGO's equivalents are `NetworkBehaviour` with `[Rpc]`,
`NetworkVariable`, and `NetworkObject`, and the details differ enough that you must check its docs
rather than translating Mirror calls by name. If the project picks NGO, say plainly which parts of
this skill you are applying as principle rather than as API.

## 1. Read the project before writing anything

```bash
find . -path '*/Mirror/version.txt' -not -path '*/Library/*' -exec cat {} +   # Mirror version
grep -rl ': NetworkManager' --include='*.cs' Assets --exclude-dir=Mirror      # manager subclass
for a in Command ClientRpc TargetRpc SyncVar; do printf '%-10s %s\n' "$a" \
  "$(grep -rl "\[$a" --include='*.cs' Assets --exclude-dir=Mirror | wc -l)"; done
```

That last count is the project's shape in one glance. Far more `[ClientRpc]` than `[Command]`
means a server-authoritative design where the server pushes state and clients rarely request it —
match it. The reverse means clients drive; find out whether that was deliberate before adding to
it. If the project documents its own networking conventions, those win over everything here.

**Mirror's API moves between versions**, so check the vendored source under `Assets/Mirror`
rather than recalling a name. `hasAuthority` is gone in current Mirror, split into `isOwned`
(this connection owns the object) and `authority` (this side may write this component's state).

## 2. Pick the direction before you write the method

Every networked call goes exactly one way.

| You need | Use | Runs on | Watch out |
|---|---|---|---|
| A client to ask the server for something | `[Command]` | server | Needs ownership unless you opt out |
| The server to tell everyone | `[ClientRpc]` | every observer | **Late joiners never hear it** |
| The server to answer or correct one client | `[TargetRpc]` | one client | Best tool for rejections |
| A client to *have* a value | `[SyncVar]`, `SyncList` | replicated | Rides the spawn payload |

The deciding question: **is this an event or a fact?** "The door just slammed" is an event — an
RPC. "The door is open" is a fact — a SyncVar. Sending both for one thing is the most common
piece of redundant networking there is: they arrive on the same tick and do the work twice.

**Anything a late joiner must know is a SyncVar, never an RPC.** An RPC reaches only the clients
connected when it was sent, and nothing replays it; a SyncVar is serialized into the object's
spawn payload, so a client joining an hour later still receives it. Set server state *before*
`NetworkServer.Spawn` so it ships inside the spawn message. Everything looks right until somebody
joins second, which is what makes this the failure that costs the most time.

Signatures, the sender parameter, `requiresAuthority`, `includeOwner`, hook rules and serializing
your own types: [references/remote-calls.md](references/remote-calls.md).

## 3. Re-validate everything a client sends

A `[Command]` body is the trust boundary. Treat its parameters as a request, not as facts.

- **Derive the caller from the connection, never from a parameter.** `connectionToClient`, or a
  `NetworkConnectionToClient sender = null` last parameter that Mirror fills in, is authoritative.
  A client can lie about an id it passes; it cannot lie about which socket the message arrived on.
- **Send identity, not authority.** Pass a `NetworkIdentity` and let the server resolve it against
  its own spawned set. Never pass "how much damage" or any other number the server can compute.
- **Check against server state only.** Distance, cooldowns, ownership, is this door locked, was
  this one-shot pickup already taken. Reading a local singleton or a client-side field inside a
  `[Command]` is the classic version of this bug, and on a host it even looks like it works.
- **A rejected command returns**, and says so. Log it, `return`, and if the client predicted the
  outcome send a `[TargetRpc]` carrying the authoritative state. Silent rejection leaves a screen
  permanently wrong.

Anti-cheat beyond this is a later layer, proposed rather than imposed. When a project reaches the
point of caring, the order is: server-side sanity checks first (speed caps, position-delta and
teleport limits, rejecting impossible moves), then lag compensation, then full prediction and
reconciliation. None of that is a reason to make movement server-authoritative on day one.

## 4. Spawning: registration is the part that bites

A spawnable object needs a `NetworkIdentity` on its root, and **its prefab must be registered on
the client** — in the NetworkManager's Spawnable Prefabs list, or via
`NetworkClient.RegisterPrefab` before connecting. Unregistered, the server spawns it happily while
the client logs one error and shows nothing. It is the most common "but it works for me".

```csharp
var crate = Instantiate(cratePrefab, spawnPoint.position, Quaternion.identity);
crate.GetComponent<CrateContents>().itemId = rolledId;   // SyncVar, set first
NetworkServer.Spawn(crate);                              // then it rides the payload
```

Only the server spawns and only the server destroys — `NetworkServer.Destroy` to remove it
everywhere, `NetworkServer.UnSpawn` to take it off clients but keep the instance for reuse. A
client that wants an object gone asks by `[Command]`. Pass an owner connection only when a client
genuinely needs authority over the thing: `NetworkServer.Spawn(obj, conn)`. Scene objects versus
spawned objects, ownership over its lifecycle, pooling and disconnects:
[references/spawning.md](references/spawning.md).

A networked prefab is still a prefab. How to create and edit one belongs to
[`unity-scene-habits`](../unity-scene-habits/SKILL.md); where the files go belongs to
[`unity-file-structure-habits`](../unity-file-structure-habits/SKILL.md).

## 5. Branch on the flag that means what you mean

| Flag | True when | Use it for |
|---|---|---|
| `isServer` | this object is spawned on the server | server logic; **also true on a host** |
| `isClient` | this object is spawned on a client | visuals, audio, UI |
| `isServerOnly` / `isClientOnly` | not a host | the genuinely one-sided case |
| `isLocalPlayer` | this is *my* player object | input, camera, local HUD |
| `isOwned` | my connection owns this object | pets, vehicles, anything owned but not me |
| `authority` | this side may write this component's state | before writing a SyncVar yourself |

Four mistakes worth naming:

- **Assuming `isServer` and `isClient` are exclusive.** On a host both are true; code meaning
  "only the dedicated server" needs `isServerOnly`. Most host-only bugs are this.
- **Using `isLocalPlayer` for ownership.** It is true only for the player object. A turret you own
  is `isOwned` and not `isLocalPlayer`.
- **Writing a `ServerToClient` SyncVar from a client.** It changes that client's local copy, is
  never transmitted, is overwritten on the next sync, and Mirror says nothing.
- **Reaching for a static "local player" singleton inside an RPC body.** Act on `this`. On a host
  that singleton is the host's own object, so the call silently hits the wrong player.

Client-side spawn order is fixed: SyncVars deserialize (firing any hooks) → `OnStartClient` →
`OnStartAuthority` → `OnStartLocalPlayer`. So SyncVars are readable in `OnStartClient` but a hook
can fire *before* it — do initial setup in `OnStartClient`, use hooks for later changes, and
clear any static you set in the matching `OnStop*`.

## 6. Spend bandwidth on purpose

- **Sync the cause, not every consequence.** One SyncVar plus a hook that updates ten visuals
  beats ten synced fields.
- **Raise `syncInterval`** for anything that need not be instant. Per NetworkBehaviour, `0` by
  default, meaning every send tick.
- **Use `syncMode = SyncMode.Owner`** for state only the owner needs, so it is not broadcast.
- **No NetworkTransform on things that never move.** Sync the spawn pose once instead.
- **Interest management exists** for large worlds. It changes global behaviour, so raise it
  rather than switching it on.

## 7. Test with two clients, every time

A single editor proves only that the code compiles, and one editor running as host hides every
host-only bug. The real test is **host plus a separate client**, hunting a late join.

The practical setup is a second editor instance on the same project, via a project-cloning tool
that symlinks the project into a clone directory so both instances share one source of truth.
Check whether the project already has one; installing one is a dependency decision, so ask. Two
builds, or a build plus the editor, work too and are closer to production. Either way, run the
checklist in [references/two-client-testing.md](references/two-client-testing.md): host-and-join,
act from each side, late join, disconnect, rejoin, and what to watch in both consoles.

## 8. Before calling it done

- Both clients agree on the state you changed, **and** a client that joined after the change
  agrees too. If you only verified the first, say so.
- Neither console shows Mirror's spawn, authority or deserialize warnings. They are warnings, not
  errors, and they are almost always the actual bug.
- Every new spawnable prefab is registered — confirmed by spawning one with a client connected,
  not by reading the inspector.
- Name which flags you branched on and anything you could only test as a host. An untested path
  in networking code is a bug you have not met yet.

When a symptom matches none of this, work backwards from it:
[references/failure-modes.md](references/failure-modes.md).
