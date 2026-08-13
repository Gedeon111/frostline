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

| Path | Owner |
|---|---|
| `src/shared/**` | Architect only |
| `src/server/Services/<X>.luau` | The job that created it |
| `src/client/Controllers/**`, `src/client/UI/**` | Client Dev |
| `Workspace.World.**` (Studio), `assets/**` | World/Tech Art |
| `tests/**` | QA |
| `docs/ECONOMY.md` | Economy Designer |
| `docs/*` (rest) | Architect |
| `tasks/BOARD.md` | Everyone — status column only, your row only |

### The WorkLog — for Studio work only (D-010)

Since D-010, **scripts are coordinated by git** — branches and PRs do that job. The WorkLog's
remaining scope is the part git cannot see: **hand-built geometry in `Workspace`**, and any
long-running Studio session. Claim a zone before building it.

`ServerStorage.WorkLog` is live in the place, and is not managed by Rojo (so a sync won't
erase it). Usage:

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

- [ ] `./scripts/check.sh` clean — stylua, selene, `rojo build`
- [ ] The place runs clean — `start_stop_play`, then `get_console_output` shows no errors
- [ ] `Tests.RunAll` green (P1)
- [ ] Strict Luau types on every public function (`--!strict` at script top)
- [ ] **Zero gameplay numbers in your code.** Everything reads from `shared/Config/`. A
      literal `0.6` or `128` in a service is an automatic reject.
- [ ] Server-authoritative: no client input is trusted without revalidation
- [ ] No `print`/`warn` outside a `Log` util guarded by `GameConfig.Debug`
- [ ] Every connection/instance you create is cleaned up (use `Trove`)
- [ ] Your `Done when` list is literally checked, item by item, in the PR description
- [ ] `tasks/BOARD.md` — your row set to `DONE`, with the PR link
- [ ] A `## Handoffs` section listing anything you needed but couldn't touch

## 6. Version control (D-010)

Scripts live in git, so normal git applies again:

- Branch: `job/<ID>-<slug>` e.g. `job/A3-creature-service`
- Commit: `[A3] add respawn timer`
- PR title: `[A3] CreatureService`
- One job = one PR. Never bundle two job IDs.
- The other person reviews and merges. Don't merge your own.
- **`git pull` before you start** — see the note at the end of §2.

**Geometry is the exception.** `Workspace` is hand-built in Studio and is not in git at all,
so it has no branches and no diffs. Coordinate world work through the WorkLog
(`owns = { "Workspace.World.shelf_ice" }`) and expect no safety net if two people build the
same zone.

## 7. You can do more than you think

Read `docs/AUTOMATION.md` before declaring anything blocked. You write code in `src/` and sync
it with Rojo, then verify in the real engine through the Studio MCP — playtest, read the
console, screenshot. Meshes generate natively; gamepasses and the game page are reachable
through Chrome MCP; the icon and thumbnails through Higgsfield.

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

### `execute_luau` is an ISOLATED context — stateful services are invisible

The biggest constraint on testing this project, found during A1.

The Studio MCP's `execute_luau` runs in its **own Lua context**, with its own module
cache and its own `_G`. Both were verified: a marker set in the game's context was
absent, and `require(Services.DataService)` from `execute_luau` returned a *fresh copy*
with an empty `profiles` table while the real service had the player loaded.

**Only the datamodel crosses that boundary.**

| What you're testing | Works from `execute_luau`? |
|---|---|
| Pure modules — `Format`, `TableUtil`, `Upgrades`, config tables | **yes** (F2, F3 used this) |
| Datamodel state — instances, properties, `leaderstats` | **yes** |
| Service in-memory state — loaded profiles, caches, registries | **no** |

`Net` *appeared* to work from `execute_luau` only because it re-derives its remote
table from the datamodel on load. That was luck, not design.

**How to test a stateful service:** put the test somewhere the game itself loads, so it
runs in the game's context, and report results through `print` — then read them with
`get_console_output`. A temporary ModuleScript in `Services/` works and uses the
existing loader. `_G` and BindableFunctions do **not** bridge the gap.

This means P1 and P4 cannot be "call `Tests.RunAll` via `execute_luau`" for anything
stateful. Those packets need respeccing: the runner has to be loaded by the bootstrap
under `GameConfig.Debug`, not injected from outside.

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
