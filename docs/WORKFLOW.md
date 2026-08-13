# Worker Protocol — FROSTLINE

Read this before you touch a file. It exists because 6 workers editing one Roblox codebase
in parallel will produce merge garbage unless ownership is absolute.

## 1. Roster

| Role | Model | Count | Owns |
|---|---|---|---|
| **Architect** | Claude Opus 5 | 1 | `src/shared/**`, all docs, contract changes, PR review, conflict resolution. Does not implement features. |
| **Server Dev** | Claude Opus 5 | 1–2 | `src/server/Services/**` |
| **Client Dev** | GPT-5.6 Sol *or* Claude Sonnet 5 | 1–2 | `src/client/**` |
| **World/Tech Art** | Claude Sonnet 5 | 1 | `src/world/**`, asset wiring |
| **Economy Designer** | Claude Opus 5 | 1 | proposes `Config/` values via RFC, owns `docs/ECONOMY.md`, `tests/economy.spec.luau` |
| **QA / Exploit** | Claude Opus 5 | 1 | `tests/**`, `tools/` test harnesses, review-only elsewhere |
| **You** | — | 1 | job `V2` (feel check), 2FA codes, and the go/no-go on anything public |

Model choice is a suggestion, not a constraint — but keep **one** Architect, and give the
Architect the strongest model available. Contract quality determines whether parallel work
merges or collides.

## 2. Script ownership — now the only collision guard

**One owner per path. Never edit a script you do not own.** If your job needs a change
elsewhere, write it under `## Handoffs` in your notes and the Architect routes it. Do not
"just quickly fix it."

This mattered before. Since D-009 it is **critical**: Team Create's script locking protects
humans from each other, but MCP edits go straight into the datamodel. Two agents on one
script means **no merge, no warning, last write silently wins.** The table below is the only
thing standing between you and lost work.

| Path | Owner |
|---|---|
| `ReplicatedStorage.Shared.**` | Architect only |
| `ServerScriptService.Services.<X>` | The job that created it |
| `StarterPlayerScripts.Controllers.**`, `.UI.**` | Client Dev |
| `Workspace.World.**`, `ReplicatedStorage.Assets.**` | World/Tech Art |
| `ServerStorage.Tests.**` | QA |
| `docs/ECONOMY.md` | Economy Designer |
| `docs/*` (rest) | Architect |
| `tasks/BOARD.md` | Everyone — status column only, your row only |

### The WorkLog — an actual lock, not a convention

`ServerStorage.WorkLog` is live in the place. Before editing any script:

```lua
local WorkLog = require(game.ServerStorage.WorkLog.README)
WorkLog.OwnerOf("ServerScriptService.Services.CurrencyService")
--> "A3 (opus-5 / Gedeon)"  or  nil if free
```

**The protocol, four steps:**

1. **Check.** `WorkLog.Active()` — if any live entry lists a script you intend to edit in its
   `owns`, stop. Work elsewhere or hand off.
2. **Claim.** Create `ServerStorage.WorkLog.<JobID>` — a ModuleScript returning
   `{ job, agent, status, started, heartbeat, owns, notes, handoffs }`. **One file per job.**
   A single shared file would itself become the thing you collide on.
3. **Work.** Refresh `heartbeat` and `notes`. Need a script outside your `owns`? Add it to
   `handoffs` — don't edit it.
4. **Release.** Set `status = "done"`. Leave the entry; it's the record of what happened.

`owns` is the contract. Not in your `owns` means read-only, no exceptions.

**Claim when you START.** A claim posted at the end prevents nothing.

**Humans claim too** — building geometry in Team Create is `owns = { "Workspace.World.shelf_ice" }`.

A claim older than ~2h with no heartbeat is stale, but say so before taking it over. The
other agent may just be slow, and a human may be mid-thought.

**Two humans, two agent fleets:** your agents cannot see each other. The WorkLog and the
board are the entire coordination mechanism — if nobody claims, nothing protects you.

### The WorkLog does not cover everything (learned the hard way)

It lives in Studio, so it only sees Studio work. It cannot see someone working in git, and it
cannot see someone working from a plan version that has since changed.

**This already cost us a full job.** PR #1 implemented F1 exactly to spec, from a commit made
about an hour before D-009 replaced the entire file-based approach. Good work, obsolete the
moment it was pushed, and nothing in the system flagged it.

Two rules close the gap:

1. **`git pull` and re-read your packet before you start.** Not when you finish. The plan is
   still moving; a packet you read yesterday may not be the packet that exists today.
2. **A decision that supersedes a frozen contract goes on the board *before* it goes in the
   docs.** Whoever files the RFC checks the WorkLog and open branches first, and tells anyone
   mid-flight. Rewriting the foundation under someone is a coordination failure by the person
   rewriting it, not by the person who was working.

## 3. Contract freeze

`src/shared/Config/**`, `src/shared/Types.luau`, and `src/shared/Remotes.luau` are frozen
after job `F2` lands. To change them:

1. Add an entry to `docs/DECISIONS.md` — problem, proposed change, blast radius (which jobs
   must be re-checked).
2. Stop working on the dependent part. Do something else in your packet.
3. Architect edits the contract and posts the diff on the board.
4. Resume.

This costs you 20 minutes. Silently changing a shared type costs the project a day.

## 4. Job packet format

Every job in `tasks/M*.md` is a self-contained prompt. Hand the whole `### [ID]` block to a
worker as its opening message. Each packet has:

- **Owner** — which role
- **Depends on** — job IDs that must be `DONE` first
- **Read first** — exact files to load before writing anything
- **You own** — the only paths you may create or modify
- **Build** — the spec
- **Done when** — objective, checkable acceptance criteria
- **Out of scope** — the things you will be tempted to do anyway. Don't.

## 5. Definition of Done — every job, no exceptions

- [ ] The place runs clean — `start_stop_play`, then `get_console_output` shows no errors
- [ ] `Tests.RunAll` green (P1)
- [ ] Strict Luau types on every public function (`--!strict` at script top)
- [ ] **Zero gameplay numbers in your code.** Everything reads from `shared/Config/`. A
      literal `0.6` or `128` in a service is an automatic reject.
- [ ] Server-authoritative: no client input is trusted without revalidation
- [ ] No `print`/`warn` outside a `Log` util guarded by `GameConfig.Debug`
- [ ] Every connection/instance you create is cleaned up (use `Trove`)
- [ ] Your `Done when` list is literally checked, item by item, in your handoff notes
- [ ] `tasks/BOARD.md` — your row set to `DONE`
- [ ] A `## Handoffs` note listing anything you needed but couldn't touch
- [ ] **`P7` snapshot run** so the work exists in git history

## 6. Version control

There are no branches and no PRs — Studio is the source of truth and everyone works in one
live place (D-009). What replaces them:

- **Claim on the board before you start.** That's the lock.
- **Run the `P7` snapshot at the end of every session.** It reads scripts out of Studio and
  commits them. A snapshot you didn't take is history you don't have.
- **Snapshot before anything risky**, so there's a known-good commit to read back from.
- Restoring is deliberate: read the old file from git, paste it in. Nothing auto-syncs back
  into Studio, ever — an automatic sync is precisely what would fight Team Create.
- Review happens by reading the other person's scripts in Studio, or by reading the snapshot
  diff in git. Do it — nobody's merging for you now.

## 7. You can do more than you think

Read `docs/AUTOMATION.md` before declaring anything blocked. You author directly in Studio
through the MCP — create scripts, run Luau, generate meshes, screenshot, playtest. Gamepasses
and the game page are reachable through Chrome MCP; the icon and thumbnails through
Higgsfield. The pipeline jobs `P1`–`P7` exist to make the rest routine.

**"I can't do this, a human must" is almost always wrong here.** Before you write it, check
which of the four channels covers it.

The genuine exceptions, and they are short:

- **Judging feel.** Whether a 0.6s swing is satisfying is not a measurable property. That's
  job `V2`, ten minutes, and it's the only thing on the board assigned to a person.
- **A 2FA prompt.** If one appears mid-flow, stop and ask for the code. Don't retry.
- **Outward-facing, hard-to-undo actions.** Creating paid products, flipping the place
  public, anything that spends real money or is visible to real players — do the work up to
  that line, then confirm before crossing it.

Report failures honestly. If the audio upload is rejected for account verification, say so
and take the documented fallback. Do not claim a job is done because the code compiles.

## 8. Testing

Three layers, and every job must say which ones it used:

1. **Pure unit tests** (`ServerStorage.Tests`, job E1) — economy math, cost curves, weight,
   multipliers, validation predicates. Run in Edit mode via `execute_luau`, sub-10s, no
   playtest needed.
2. **Integration tests during play** (`Tests.Integration`, job P4) — DataStores, `Workspace`,
   `Players`, replication, region checks. `start_stop_play` + `execute_luau` against the
   `Server` datamodel, failures read back with `get_console_output`.
3. **Visual capture** (job C7) — `screen_capture` from fixed cameras, part counts, asset ID
   resolution, for anything that has to look right.

**Rule:** if a piece of logic can't be tested at layer 1, it's in the wrong module. Pull the
math into a pure ModuleScript and test that; leave only engine wiring for layer 2.

### The require cache will lie to you

`require()` results are **cached across `execute_luau` calls**. Edit a module, re-run your
check, and you get the *old* value back — with no error and no warning. You conclude the fix
worked. It didn't.

This bit F2: a config value was changed, verified as changed in the source, and the test still
reported the pre-change number.

Use a fresh clone in any check that runs after an edit:

```lua
local function freshRequire(module: ModuleScript)
    local clone = module:Clone()             -- distinct instance = distinct cache entry
    clone.Name = module.Name .. "__fresh"
    clone.Parent = module.Parent             -- sibling, so relative requires still resolve
    local ok, result = pcall(require, clone)
    clone:Destroy()
    assert(ok, tostring(result))
    return result
end
```

Parenting the clone as a **sibling** matters — modules resolve dependencies through
`script.Parent`, so a clone parked elsewhere fails to find `Types`.
