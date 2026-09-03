---
name: create-schema
description: >-
  Create or extend AuditgraphDB schema packages and take them through the full
  content SDLC — scaffold/author → gradle gate → publishOrg + org load → user
  verifies in their org → PR to main only after explicit sign-off. Covers BOTH
  vendor/product schema packages AND extending the base schema with new
  interfaces (interface-first: when a generic concept is missing, add it to
  base and PR it). USE THIS when the user says "add a schema for X", "add
  classes/interfaces/fields for Y", "add an interface to the base schema",
  "extend the graph model", or a ZeroBias task asks for a schema package.
  Standalone: works in this repo alone; no platform task required (task-driven
  mode is optional).
---

# create-schema — schema packages & base interfaces, org-first SDLC

Schema packages define the AuditgraphDB object model (classes, interfaces,
fields, enums, documents) that the dataloader loads and that collectors
target. This skill delivers NEW schema packages **org-first**: the default
deliverable is the schema loaded into the user's own org; the PR to `main`
happens only after the user signs off on the org-loaded result. Changes to
already-published packages — the shared base above all — are **PR-only**:
gate → review → PR, visible in the dev environment after merge.

```
Phase 0 prerequisites (hard gate — /prerequisites must report READY)
Phase 1 resolve + existence check (mode, names, dependency chain, dupes)
Phase 2 branch (from main)
Phase 3 scaffold + author content   ← id: on EVERY file; Mode A: zerobias.orgId BEFORE the gate
Phase 4 gate                        ← git add BEFORE gating; minutes for a vendor pkg, HOURS for base
Phase 5 publishOrg + org load       ← Mode A ONLY (new, org-only packages); YAML + -ts twin
Phase 6 user verifies               ← A: the org artifact · B: the YAML + gate result  🙋 sign-off
Phase 7 PR --base main              ← A: drop orgId + RE-GATE first · B: straight to PR
```

**Two request shapes (decide in Phase 1, before touching files):**

| Mode | What | Where | Typical ask | SDLC tail |
|---|---|---|---|---|
| **A — vendor schema package** | NEW package of concrete classes (+ package-local interfaces/fields/enums) | `package/<vendor>/[<group>/]<code>/` | "add a schema for Stellar Cyber findings" | **org-first**: gate → publishOrg → verify in org → PR |
| **B — base schema extension** | new generic INTERFACE (+ fields/enums it needs) in the shared base schema | `package/zerobias/zerobias/base/` | "collectors need a Backup interface" | **PR-only**: gate → review → PR → visible in dev after merge |

**Org publish is for NEW artifacts only.** build-tools refuses to
org-publish any package that already has catalog versions
(`resolveOrgVersion: … Org publish is for artifacts that exist only inside
your org`), and the dataloader's ownership scope refuses org-private content
that shadows public names. So Mode B — and any extension of an
already-released vendor package — never reaches Phase 5: its verification is
the gate (`testDataloader: passed`) plus review of the YAML, and the change
becomes visible in the dev environment once the PR merges and publishes.

**Interface-first (the platform model).** Collectors and modules target base
**interfaces**; the dataloader materializes `Dynamic<Interface>` concrete
classes at ingest, and segment declarations create schema obligations. So
when the generic concept you need is missing from
`package/zerobias/zerobias/base/interfaces/`, the RIGHT move is Mode B: add
the interface to base and PR it — this is the default path, not an
exception, and proposing it proactively is encouraged. Reserve Mode A for
genuinely vendor-specific shapes; its classes should `extends` base
interfaces wherever one fits. When a Mode A package needs a base interface
that doesn't exist yet, do Mode B FIRST (own branch + PR + org load), then
build the vendor package on top — sequencing note in Phase 5.

**Modes of invocation.** Default is **request-driven**: the user describes
the schema need; no platform task required. If the user references a
ZeroBias task (UUID or task name), additionally follow the **task-driven
appendix** at the end.

**Headless runs (`claude -p "add a backup interface to the base schema"`).**
Same flow, three hard rules:
- **Pre-flight first**: run the `prerequisites` skill (Phase 0) before
  touching anything. If anything is missing, print the exact setup
  instructions and exit — never fail mid-flow.
- **The run ENDS after Phase 5** (Mode A org load) or **after Phase 4**
  (Mode B gate). Print what was created, how to
  verify, and: *"verify the org artifact, then run
  `claude -p 'open the PR for schema <vendor>/<code>'` (or continue
  interactively)"*. Phases 6–7 are human-gated and never run headless.
- **Decision forks stop the run**: schema/interface already exists (or is
  in an open PR), dependency chain incomplete, mode ambiguous, gate
  conflict → print a structured report of the state and the decision
  needed, exit cleanly, change nothing further.

**Skill-vs-reality conflicts.** If observed tool behavior contradicts this
skill, STOP: verify against the primary source (`settings.gradle.kts`,
build-tools source in `util`, the workflow YAML, the dataloader), act on
what the source says, and queue a fix to this skill in the same session —
never force reality to match stale text.

## Phase 0 — prerequisites (hard gate)

Invoke this repo's [`prerequisites` skill](../prerequisites/SKILL.md)
(`/prerequisites`) and get `READY` before ANYTHING else — interactive or
headless. If something is missing there are exactly two permitted actions:
install it (with consent) or stop and wait. Never work around it — no
substitute tooling, no raw HTTP instead of the `zb` MCP, no partial
continuation.

This gate applies for the WHOLE flow, not just at the start: if any
prerequisite fails mid-flow (401s, expired token, org load refused, tool
vanished), treat it as a prerequisite regression — STOP the phase you're
in, re-run `/prerequisites`, and resume only from `READY`.

## Phase 1 — resolve inputs + existence check

**Pick the mode** (table above). If the request is ambiguous ("add a schema
for backups" could be a base interface or a vendor package), ask — the two
modes produce different artifacts with different blast radii.

**Naming (both modes):** `<vendor>` and `<code>` segments must match
`^[a-z0-9]+$` — lowercase alphanumeric only, no hyphens/underscores/dots
(the platform `vspCodeValidator` constraint). Interface/class names are
PascalCase; fields are camelCase dot-notation. **NEVER rename** a published
schema package or its registered classes without platform-team
coordination — the dataloader cannot reassign class ownership.

### Mode A — vendor schema package

The data workflow chain is `vendor → [suite] → [product] → schema`. The
schema attaches to a catalog entry and depends on its package:

```
zerobias_execute("store.Vendor.get", { vendorCode: "<vendor>" })
    // 404 = vendor missing → STOP; create it first (vendor repo's
    //        /create-vendor), org-first into the SAME target org.
zerobias_execute("store.Vendor.listProducts", { vendorCode: "<vendor>" })
    // confirm the product exists (or store.Suite.get for a suite-level
    // umbrella schema) → STOP and create it first if missing.
```

(The `portal.*.search` ops in older docs do NOT exist — if an op errors as
unknown, discover the current name with `zerobias_search("vendor")` and
stay within `store.*`.)

Then check the schema itself doesn't already exist:
- Locally: `ls package/<vendor>/` (any depth).
- Registry: `npm view @zerobias-org/schema-<vendor>-<code> versions`
  (404 = free).
- If it exists (anywhere), STOP and ask the user what to do (extend /
  nothing).

### Mode B — base schema extension

- **Read the neighbors first**: `ls package/zerobias/zerobias/base/interfaces/`
  and READ the 3–5 nearest-by-concept interfaces (their `extends` and
  properties) — the base has 125+ interfaces and the concept may already
  be covered or nearly covered (in which case extending an existing
  interface with a field beats adding a near-duplicate).
- **Check in-flight work**: `gh pr list --state open --search "<concept>"`
  — customers add base interfaces by PR too; never duplicate an open one.
- Confirm base fields/enums to reuse: `ls package/zerobias/zerobias/base/fields/`
  — prefer reusing an existing field definition over minting a synonym.

## Phase 2 — branch first (never commit on main)

```bash
git fetch origin
git switch -c feat/schema-<vendor>-<code> origin/main    # Mode A
git switch -c feat/base-<concept> origin/main            # Mode B, e.g. feat/base-backup-interface
```

**This repo's PRs target `main`** — `main` is the default branch and the
publish workflow's sync job propagates main → uat → qa → dev. Branch from
`origin/main`, PR back to `main`.

## Phase 3 — scaffold + author

### Mode A — scaffold the package

```bash
mkdir -p package/<vendor>/<code>          # or package/<vendor>/<group>/<code>
./scripts/createNewSchema.sh package/<vendor>/<code>
```

The script copies the templates + `.npmrc`, substitutes the path-derived
names, and writes the `build.gradle.kts` marker (`plugins { id("zb.schema") }`)
required for gradle discovery. You fill `{name}` / `{description}` in
`catalog.yml` and `package.json`. **Verify the scaffold immediately**:
`ls -A package/<path>` must show `package.json`, `catalog.yml`, `.npmrc`
(dotfile!), `build.gradle.kts`. Exact file shapes: [templates.md](templates.md).

Then author the definitions under `classes/` `interfaces/` `fields/`
`enums/` `documents/` per the **Schema Definition Reference in
[CLAUDE.md](../../../CLAUDE.md)** (per-artifact rules, link patterns,
viewProperties, enum ALL_CAPS, field reuse order). Non-negotiables:

- Never hand-edit `version` after creation — CI owns bumps (new packages
  start at `1.0.0`).
- `dependencies`: `@zerobias-com/schema-zerobias-zerobias-platform` +
  `@zerobias-org/schema-zerobias-zerobias-base` (both `latest`), plus the
  catalog package the schema describes (`@zerobias-org/product-<v>-<p>`,
  or the suite package for a suite-level umbrella schema).
- `zerobias.package` MUST equal the dot-joined directory path + `.schema`;
  `zerobias.imports` lists `zerobias.zerobias.platform.schema` +
  `zerobias.zerobias.base.schema`.
- Concrete classes `extends` base interfaces wherever one fits (that's
  what makes the data reachable by interface-targeting collectors);
  extending `Element` enables framework linking.
- **Every definition file starts with `id:`** (enums and documents also
  `fieldId:`) — the dataloader refuses a file without one
  (`Unable to handle interface 'X', id is missing`), and the gate's
  `testDataloader` step is where it surfaces. Classes/interfaces:
  `UUIDv5(NIL, Name)` — deterministic from the name; fields/enums/
  documents: a fresh UUIDv4. Recipes in
  [templates.md → Generating ids](templates.md#generating-ids). Never
  change a published id and never mint a second id for an existing name
  (the load refuses the mismatch instead of duplicating the row).

### Mode B — author in the base package

No scaffold — edit `package/zerobias/zerobias/base/` directly:
- `interfaces/<Name>.yml` — `description`, `extends` (an existing base or
  platform interface), `properties` referencing fields, `viewProperties`.
  Match the style of a freshly-read neighbor exactly (the YAML property
  shape is quirky — copy a real one).
- New `fields/*.yml` / `enums/*.yml` only where nothing reusable exists.
- `id:` on every NEW file, same rule as Mode A (interface →
  `UUIDv5(NIL, Name)`; field → v4; enum/document → `id` + `fieldId`, both
  v4). Existing base files keep their ids untouched — when you add a
  property to an existing interface you edit the file, not its `id`.
- Additive changes only: never rename/remove/retype anything published —
  that is a platform-team-coordinated event, not a PR.

### Mode A only — set the org target BEFORE the first gate

**Set `zerobias.orgId: "<target-org-uuid>"` in the NEW package's
`package.json` now.** With orgId present the gate's dataloader step seeds
your org into the ephemeral branch and runs org-scoped, matching how
org-scoped tokens authorize. ⚠ The gate-stamp's sourceHash DOES cover
`package.json`: deleting orgId later (Phase 7) invalidates the stamp, so
budget one more gate at the end. **Mode B never sets orgId** — base is a
shared package and cannot be org-published (rule above).

## Phase 4 — gate (git add FIRST, always via zbb)

All builds go through `zbb` — **never invoke `./gradlew` directly**. Only
zbb injects the slot env AND pins the JDK (a bare `./gradlew` on JDK 25
dies with an opaque `25.0.2`).

```bash
ls -A package/<path>                     # completeness check incl. DOTFILES (.npmrc!)
git add package/<path>/                  # BEFORE gating — the gate-stamp's
                                         # sourceHash enumerates git ls-files;
                                         # untracked files are invisible to it
zbb --slot <slot> stack add "$(git rev-parse --show-toplevel)"  # once per slot
cd "$(git rev-parse --show-toplevel)/package/<path>" && zbb --slot <slot> gate
zbb gate --check                         # validate the stamp (no slot needed)
```

⚠ Write EVERY `zbb gate` / `publishOrg` as `cd <absolute-path> && zbb …`
in ONE command — never rely on inherited shell cwd (background shells
reset it, and a repo-root run targets the wrong project).

`gate` = `validateContent` (file/name triangulation) +
`:validateUniquePackageNames` + `dataloaderExec`/`testDataloader` + the
TS-twin generation + `writeGateStamp`. The dataloader step asks the
dataloader-service (authed by `ZB_TOKEN`) for an ephemeral Neon branch, then
runs `@zerobias-com/platform-dataloader@prod` **locally on your machine**
against that remote branch — this is where declared ids, extends chains,
link bidirectionality, enum format, and viewProperties are actually
enforced. Every statement is a round trip to us-east-1, so **duration scales
with package size and your link**: a vendor package takes minutes; base
(~500 files) takes ~1 h on a good link and 2–3 h on a slow one. It is not
hanging — tail the log. Two `✗ vault-connection` lines at the top are
harmless preflight noise. To iterate quickly before the gate, use the local
scratch-DB flow in `CONTRIBUTING.md` (seconds, same dataloader checks, no
stamp). On success **commit `gate-stamp.json`** — CI's publishGuard rejects
publishes without a valid committed stamp, and **no PR workflow runs the
gate for you**.

⚠ **Skipped ≠ passed**: with `ZB_TOKEN` absent the dataloader step is
SKIPPED and the stamp records `"testDataloader": "skipped"` — fine for an
external contributor's PR, NOT fine for this flow: the org-first path
requires a stamp that says `"passed"`. Check it before proceeding.

If you gated before adding new files, re-gate after `git add`. Mode B: the
gate runs on the BASE package
(`cd package/zerobias/zerobias/base && zbb --slot <slot> gate`) and
re-writes its stamp — a changed stamp after your edit is expected.

## Phase 5 — publishOrg + load into the user's org (Mode A only)

**Mode B skips this phase — go to Phase 6.** Org publish is refused for any
package that already has catalog versions, with no override.

Publishes an org-private rc version (`<X.Y.Z+1>-rc.<orgIdStripped>.<n>`,
computed by zbb — never hand-authored) of the NEW schema package **and its
`-ts` twin**, and queues a dataloader job into the target org — no PR, no
shared catalog involved. Publishing re-runs the dataloader step to
regenerate the TS twin, so budget the same time as the gate. `zbb
publishOrg` needs `lifecycle.publishOrg` in the repo's `zbb.yaml` — on a
branch that predates it, zbb falls back to the meta-repo and dies with
`bash: ./gradlew: No such file or directory`; rebase onto `main`.

1. Confirm `"zerobias": { …, "orgId": "<org-uuid>" }` is in the package's
   `package.json` — set in Phase 3, where it belongs.
2. Environment — must be in the **slot/stack env** (a plain shell `export`
   does not reach the gradle build); the `prerequisites` skill and
   `./scripts/setup-org-credentials.sh` own the full reference
   (`ZB_API_KEY` org key, `ZB_TOKEN` registry key, `ZB_PLATFORM_URL`,
   `NPM_CONFIG_TAG`, and the DATALOADER_SERVICE_URL leave-unset rule).
   ⚠ **Slot-env mutation gate:** changing any slot value that redirects
   traffic or identity (URLs, `ZB_ORG_ID`, keys) MID-FLOW requires showing
   the user the evidence and the exact `env set`, and getting confirmation
   BEFORE running it.
3. Run as ONE command with an absolute path:
   `cd <repo>/package/<path> && zbb --slot <slot> publishOrg`
4. Verify it landed: confirm the org dataloader job completed (retry the
   identical command ONCE on a server-side failure before diagnosing),
   then verify the loaded model — Phase 6 owns what to show the user. Read
   ops only: discover current model/schema read operations with
   `zerobias_search("schema")` / `zerobias_search("model")` rather than
   inventing op names.
5. **Iterate here**: edit → re-gate → re-run `zbb --slot <slot> publishOrg`
   until the user is satisfied. Loading happens ONLY through
   `zbb publishOrg` — never POST the dataloader API directly, and never
   use the MCP to load artifacts (MCP ops are for reads/verification only).

⚠ **Dist-tag landmine on iteration.** The dataloader's load guard compares
the requested version against the target env's dist-tag, falling back to
`latest`. A FIRST `publishOrg` of a package works because the registry
force-assigns `latest` to that rc. But subsequent rc's only get the
`NPM_CONFIG_TAG` tag (`dev`) while `latest` stays put — so the org load of
`-rc.<org>.1+` can be REJECTED ("greater than latest"). If the load is rejected, the
fix is a one-time
`npm dist-tag add <pkg>@<new-rc> latest --registry=https://pkg.zerobias.org`
(run by the user — and note it must be undone is NOT true: the next shared
release reassigns `latest` on publish) before re-loading. Apply to the
YAML package; the `-ts` twin only needs it if a consumer resolves it by
`latest`.

**Sequencing (Mode B → Mode A):** a vendor package whose classes `extends`
a base interface that is not yet on `main` cannot gate until the base PR
has merged and published (the gate resolves base from the registry). Open
the base PR first; build the vendor package on top once it is out.

Notes: org users can only queue org-private (`-rc.<org>`) loads — a plain
catalog-semver load is 403 (platform-admin only). Org loads need
build-tools ≥ **1.0.137** (verify:
`./gradlew buildEnvironment | grep build-tools`; a stale locally-published
copy in `~/.m2` can shadow the release).

## Phase 6 — user verification + sign-off  ⭐

**Mode A** — show the user the org-loaded schema:
- the completed org dataloader job (id + status),
- the loaded classes and their `extends` bindings in the app (model/schema
  browser),
- the published rc versions of BOTH npm artifacts
  (`npm view <pkg> versions` / `<pkg>-ts`).

**Mode B** — there is no org artifact to show. Present the definition
itself: a compact table of the interface (name, description, `extends`,
properties → fields, link targets, `links.models` codes) plus the gate
evidence (`"testDataloader": "passed"` and the `Interface '<Name>' added` /
`validated` lines from the gate log). The interface becomes visible in the
dev environment after the PR merges and publishes.

Have them judge names, descriptions, property shapes, and link targets —
schema mistakes are expensive later (published names can't be renamed).
**Do NOT proceed to the PR until the user explicitly confirms** (e.g.
"looks good, ship it"). Silence or further tweak requests are NOT
sign-off — if unclear, ask. Headless runs never reach this phase — they
stop after Phase 5 by design.

## Phase 7 — PR to main (after sign-off only)

1. **Mode A:** flip ownership to the shared catalog — **delete
   `zerobias.orgId` from `package.json`, then RE-GATE**
   (`cd <pkg> && zbb --slot <slot> gate`): the stamp's sourceHash covers
   `package.json`, so without a fresh gate the publish workflow rejects the
   stamp (`source-hash-changed`) after merge. Leftover `-rc.<org>.<n>` npm
   versions don't collide with catalog semver. **Mode B:** nothing to flip —
   the Phase 4 stamp is the one you commit.
2. Commit — selective staging, conventional message, no co-authors:

```bash
# Mode A
git add package/<vendor>/<code>/
git commit -m "feat(<vendor>-<code>): add <Name> schema"
# Mode B
git add package/zerobias/zerobias/base/
git commit -m "feat(base): add <Interface> interface"

git push -u origin <branch>
```

3. PR against **main**:

```bash
gh pr create --base main \
  --title "<same conventional subject>" \
  --body "…summary (what the schema/interface models and WHY — for Mode B:
          the generic concept, its consumers, the neighbors considered),
          validation checklist (gate ✓ with testDataloader passed ✓,
          gate-stamp committed ✓, org-loaded + user-verified ✓), and
          anything needing SME review (naming calls, extends choices,
          link targets)…"
```

The PR is how the schema reaches the shared catalog; the org-private
artifact from Phase 5 stays in the user's org either way. ⚠ A Mode A
package whose base interface is still org-only must WAIT for the base PR
to merge and publish first — CI resolves `latest` from the registry.
An org that wants to keep a schema private simply never opens the PR —
that IS the customer own-schema path, fully supported.

## Common issues

**First rule for any SERVER-side failure** (dataloader jobs, platform
calls): re-run the identical command ONCE before diagnosing or escalating.

- **Gate fails with opaque `25.0.2`** → `./gradlew` was invoked directly
  on JDK 25; use `zbb` (it pins the toolchain).
- **`stack add` from a git worktree fails "Stack 'schema' already exists"**
  → harmless: zbb resolves stacks by `zbb.yaml` name, not path. Skip it.
- **Publish workflow skips the package** → missing `build.gradle.kts`
  marker (the scaffolder writes it; check for a deletion).
- **`package.json name expected '@zerobias-org/schema-<…>'` /
  `zerobias.package expected '<…>'`** → name/dir triangulation; fix the
  fields, never rename the dir.
- **Enum values rejected** → must be ALL_CAPS `[A-Z][A-Z0-9_]*` — the
  dataloader enforces it at load time.
- **`Unable to handle <kind> '<name>', id is missing` / `… is not a valid
  UUID`** → the file lacks `id:` (or an enum/document lacks `fieldId:`);
  mint it per [templates.md → Generating ids](templates.md#generating-ids).
- **`'<name>': it already exists as <id>, but this artifact declares id
  <other>`** → the name is already loaded under another id (file renamed,
  id re-minted). Reuse the existing id — an existing resource cannot be
  re-keyed.
- **`'<name>': that name is already taken by an existing resource … this
  package does not own`** (org loads) → your org-private package collides
  with a PUBLIC name. Pick a different name, or change the public package
  through a PR (Mode B) — private content cannot shadow public names.
- **Dataloader rejects a link** → links must be bidirectional and target
  an existing class/interface — see the link catalog in CLAUDE.md.
- **`testDataloader` errored (not skipped)** → slot misconfigured; check
  the stack is added and the slot resolves `ZB_TOKEN`
  (`zbb --slot <slot> env get ZB_TOKEN | tail -n1` from INSIDE the repo).
- **Stamp says `"testDataloader": "skipped"`** → `ZB_TOKEN` didn't reach
  the build; the org-first flow needs `passed` — fix the slot, re-gate.
- **`publishOrg` 401 on `/dana/me` or the org load is refused** → the ORG
  key (`ZB_API_KEY`, fallback `ZB_TOKEN`) is not an org OWNER key of the
  org in `zerobias.orgId`; non-prod targets REQUIRE `ZB_API_KEY`.
- **Org load rejected "greater than latest"** → the dist-tag landmine in
  Phase 5.
- **`resolveOrgVersion: … already has catalog versions` / `doesn't fit the
  org-publish format`** → the package is a shared catalog artifact (base, or
  any released vendor package): it cannot be org-published, by design. Skip
  Phase 5; gate → review → PR (the Mode B path).
- **`zbb publishOrg` → `bash: ./gradlew: No such file or directory`** → the
  repo's `zbb.yaml` on your branch has no `lifecycle.publishOrg` (branch
  predates it); rebase onto `main`.
- **Gate "hangs" for an hour or more** → it is loading every file of the
  package into a remote Neon branch; base takes 1–3 h. Check the log tail
  before assuming a hang. A Neon connection timeout / `No route to host` is
  a network drop — re-run the identical command once.
- **`gateCheck`: `source-hash-changed` right after editing `package.json`**
  → package.json IS hashed (orgId add/remove included); re-gate.
- **`dataloaderOrgJob` fails with `npm … 401 Unauthorized`** (server-side,
  `/root/.npm` in the log) → the TARGET env's dataloader pod fetches with
  its OWN `ZB_TOKEN` — no client-side fix. Retry once; then escalate to
  platform infra.
- **Generated `ts/` directory shows up untracked** → the TS twin's
  workdir; it is gitignored (`**/ts/`) — never commit it.

## Task-driven appendix (only when the user references a ZeroBias task)

- Fetch: `platform.Task.get` (UUID). Task code is not searchable.
- Assign + start: `platform.Party.getMyParty` → `platform.Task.update` with
  `assigned` (party id), `customFields` (`artifactType: schema`, `repoUrl`,
  `branchName`), and the Start transition — **always take transition IDs
  from `task.nextTransitions`**, never hardcode them.
- Comment progress at start and completion (`platform.Task.addComment`).
- After the PR: transition to Peer Review. Link to a parent task with
  `platform.Resource.linkResources` if this schema was created as a
  dependency (e.g. for a connector).

## References (this repo only)

- [`CLAUDE.md`](../../../CLAUDE.md) — Schema Definition Reference (artifact
  rules, link catalog, viewProperties, validation-error table), naming
  rules, publish workflow.
- [templates.md](templates.md) — exact file shapes.
- [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) — external-contributor lane
  (fork → gate → PR; maintainers verify org-side).
- [`scripts/createNewSchema.sh`](../../../scripts/createNewSchema.sh) —
  scaffold script.
