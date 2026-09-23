# Testing with two clients

One editor proves one thing: that the code compiles. Every interesting multiplayer bug needs a
second participant, and a good share of them need the second one to arrive *late*.

## The three setups

| Setup | Cost | Catches |
|---|---|---|
| Host alone in one editor | free | almost nothing; hides every host-only bug |
| Host in the editor + a second editor instance | one-time setup | most of it, with breakpoints on both sides |
| Two builds, or a build plus the editor | a build per change | everything, including what only breaks outside the editor |

Never report "tested" on the first row. On a host, `isServer` and `isClient` are both true, every
`[Command]` reaches a server in the same process, and every static singleton resolves to the local
player. That is the configuration in which broken code looks correct.

## A second editor instance

Unity will not open the same project twice. The standard workaround is a project-cloning tool that
creates a sibling directory and symlinks `Assets`, `ProjectSettings` and `Packages` into it, so
both instances edit one source of truth while holding separate `Library` folders. ParrelSync is
the common one in Mirror projects; newer editor versions have their own multiplayer play-mode
support. Check what the project already has before adding anything — installing one changes the
package manifest or the asset tree, which is a dependency decision. Ask first.

Whatever the tool, the rules are the same:

- The clone is a *clone*. Do not edit assets in it; the symlinks mean you are editing the
  original, and the clone's editor may not have reimported.
- Both instances need the same scene loaded and the same build of the scripts. After a code
  change, let both recompile before drawing conclusions from a disagreement.
- Run the original as host and the clone as client, then swap once. A bug that only appears one
  way round is an authority bug.

## The checklist

Run it after any networked change. Each line is a real failure class.

1. **Host and join.** Client sees the world in the state the host has it. Anything missing is a
   spawn or registration failure.
2. **Act on the client.** The client's `[Command]` reaches the server, the effect appears on
   *both* screens. Effect on one screen only means state was changed locally instead of through
   the server, or an RPC went the wrong direction.
3. **Act on the host.** Same check, other direction. Server-side changes must reach the client.
4. **Late join.** Change something, *then* connect the second client. It must see the changed
   state. This is the one people skip and the one that catches RPC-instead-of-SyncVar.
5. **Disconnect the client.** The host keeps running, the client's objects are cleaned up, no
   null-reference spam on either side.
6. **Rejoin.** The returning client gets a consistent world. Statics that were not cleared show
   up here as a second player object, a stale HUD, or a manager pointing at a destroyed object.
7. **Two clients plus a host**, if the game supports three. Broadcast-versus-target mistakes only
   show with two receivers: a `[ClientRpc]` where a `[TargetRpc]` was meant looks perfectly
   correct until somebody else is watching.

## Reading the console

Watch **both** consoles, and treat Mirror's warnings as errors. The ones that matter:

- `Failed to spawn server object, did you forget to add it to the NetworkManager?` — the prefab
  is not registered. Client-side only.
- `Command … without authority` — the calling client does not own that object. Either the object
  should be owned, or the command should be `requiresAuthority = false` and validate the sender.
- `EntityStateMessage … without authority` — a client tried to sync state it does not own. Often
  a `syncDirection` that does not match the design.
- `Command … while client is not ready` — sent before the client finished joining. Usually a call
  in `Start` or `Awake` that belongs in `OnStartLocalPlayer`.
- Anything about deserialization failing — a type changed on one side and not the other, or a
  custom serializer whose reader and writer disagree. Rebuild both sides before investigating.

Silence on the client while the host behaves correctly is the shape of a registration or
late-join problem. Silence on both while the screens disagree is the shape of local state that
was never networked at all.

## What to report

Say which setups you actually ran, and name any path you could only exercise as a host. "Verified
with a host and one joined client, including a late join" is a useful sentence. "Tested" is not.
