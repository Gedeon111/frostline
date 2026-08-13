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

## 2. File ownership

**One owner per path. Never edit a file you do not own.** If your job needs a change in
someone else's file, write the request into your PR description under `## Handoffs` and the
Architect routes it. Do not "just quickly fix it."

| Path | Owner |
|---|---|
| `src/shared/**` | Architect only |
| `src/server/Services/<X>.luau` | The job that created it |
| `src/client/Controllers/**`, `src/client/UI/**` | Client Dev |
| `src/world/**`, `assets/**` | World/Tech Art |
| `tests/**` | QA |
| `docs/ECONOMY.md` | Economy Designer |
| `docs/*` (rest) | Architect |
| `tasks/BOARD.md` | Everyone — status column only, your row only |

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

- [ ] `selene src/` clean, `stylua --check src/` clean
- [ ] `rojo build` succeeds
- [ ] Strict Luau types on every public function (`--!strict` at file top)
- [ ] **Zero gameplay numbers in your code.** Everything reads from `shared/Config/`. A
      literal `0.6` or `128` in a service is an automatic reject.
- [ ] Server-authoritative: no client input is trusted without revalidation
- [ ] No `print`/`warn` outside a `Log` util guarded by `GameConfig.Debug`
- [ ] Every connection/instance you create is cleaned up (use `Trove`)
- [ ] Your `Done when` list is literally checked, item by item, in the PR description
- [ ] `tasks/BOARD.md` — your row set to `DONE`, with the PR link
- [ ] `## Handoffs` section in the PR listing anything you needed but couldn't touch

## 6. Git

- Branch: `job/<ID>-<slug>` e.g. `job/A3-creature-service`
- Commit: `[A3] add respawn timer`
- PR title: `[A3] CreatureService`
- One job = one PR. Never bundle two job IDs.
- Architect reviews and merges. Workers do not merge their own PRs.

## 7. You can do more than you think

Read `docs/AUTOMATION.md` before declaring anything blocked. Studio runs headlessly through
`run-in-roblox`; assets upload through the Open Cloud API; gamepasses and the game page are
reachable through Chrome MCP; meshes, icons, and audio are generated through Higgsfield. The
pipeline jobs `P1`–`P6` exist to make all of that a one-command operation.

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

1. **Pure unit tests** (`tests/*.spec.luau`, job E1) — economy math, cost curves, weight,
   multipliers, validation predicates. Runs under plain Luau, sub-10s.
2. **Integration tests in real Studio** (`tests/integration/`, jobs P1 + P4) — DataStores,
   `workspace`, `Players`, replication, region checks. Driven by `run-in-roblox`, no clicking.
3. **In-engine capture** (job C7) — screenshots from fixed cameras, part counts, asset ID
   resolution, for anything visual.

**Rule:** if a piece of logic can't be tested at layer 1, it's in the wrong file. Pull the
math into a pure module and test that; leave only the engine wiring for layer 2.
