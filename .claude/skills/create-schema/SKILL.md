---
name: create-schema
description: >-
  Create a vendor/product schema package (concrete classes + package-local
  interfaces) and take it through the full content SDLC — scaffold/author →
  gradle gate → publishOrg + org load → user verifies in their org → PR to
  dev only after explicit sign-off. Anything the base schema lacks (an
  interface, a property, a link) is declared IN THE PACKAGE as a
  `<Vendor><Base>Base` interface extending base; the base itself is never
  edited by contributors — zb owners promote at review. USE THIS when the
  user says "add a schema for X", "add classes/interfaces/fields for Y",
  "we need a link between A and B", "extend the graph model", or a ZeroBias
  task asks for a schema package. Standalone: works in this repo alone; no
  platform task required (task-driven mode is optional).
---

# create-schema — vendor schema packages, org-first SDLC

Schema packages define the AuditgraphDB object model (classes, interfaces,
fields, enums, documents) that the dataloader loads and that collectors
emit into. This skill delivers a **new schema package org-first**: the
deliverable is the schema loaded into the user's own org; the PR to `dev`
happens only after the user signs off on the org-loaded result.

```
Phase 0 prerequisites (hard gate — /prerequisites must report READY)
Phase 1 resolve + existence check (names, dependency chain, dupes)
Phase 2 branch (from dev)
Phase 3 scaffold + author          ← id: on EVERY file; zerobias.orgId BEFORE the gate;
                                     base gaps → <Vendor>XBase interfaces, never base edits
Phase 4 local scratch DB, then gate ← git add BEFORE gating
Phase 5 publishOrg + org load      ← YAML package AND its -ts twin
Phase 6 user verifies org artifact ← 🙋 explicit sign-off required
Phase 7 PR --base dev              ← drop orgId + RE-GATE first
        └─ zb review: promote package interfaces into base, or keep them vendor-local
```

## Autonomy contract — one sentence in, an org-loaded package out

The expected invocation is a single sentence: *"make a Snyk model with
org, project, target, user and issue"*. From that, run Phases 0–5 **without
asking anything** and stop at Phase 6 with the loaded model in front of the
user. Everything else is derived, decided and recorded — not asked:

| You need | Derive it |
|---|---|
| vendor / product code | lowercase-alnum of the name (`Snyk` → `snyk`); confirm with `store.Vendor.get`; product: the vendor's only product, else the one whose name matches the request, else the vendor's flagship (same code as the vendor) |
| target org | the slot's `ZB_ORG_ID` (Phase 3) |
| what the entities look like | the source order in Phase 1 → *Learn the vendor model* |
| class names, parents, properties, links, enums | the decision procedure in Phase 1 — decide, then record the decision in the package `README.md` |
| ids, branch name, package path, dependencies | mechanical, per Phase 2–3 and `templates.md` |

**Exactly four stop points.** (1) a prerequisite is missing (Phase 0);
(2) the vendor or product is not in the catalog — say which and which leaf
skill creates it; (3) the schema package already exists, locally, in the
registry or in an open PR; (4) the Phase 6 sign-off before the PR. A design
question is never a stop point: pick the option the decision procedure
gives, note it under *Decisions* in the README, and let the user overrule
at Phase 6. The package + stamp commits in Phases 4–7 are part of the
flow, not separate approvals.

**One path for everyone.** Internal and external contributors, zb staff
included, author a package and org-load it. **Nobody edits
`package/zerobias/zerobias/base/` in a contribution PR.** Two facts make
this the only workable path: build-tools refuses to org-publish any package
that already has catalog versions (`resolveOrgVersion: … Org publish is for
artifacts that exist only inside your org`), and the dataloader refuses
org-private content that shadows public names. A new package has neither
problem. What base lacks is expressed inside the package (Phase 3) and
promoted into base by zb owners at review, in a second step.

⚠ **Editing base directly is the promotion path, and it is slow by design.**
A change made in `package/zerobias/zerobias/base/` cannot be used, loaded
or checked by anyone until zb reviews it, merges it and the publish reaches
an environment — there is no org-first shortcut for base. Prefer the
package extension: it works in your org today and can still be promoted.
Commit straight to base only if you accept that wait (zb owners doing a
reviewed promotion; see "Authoring into base" at the end) — and then the
full gate still runs, like everywhere else.

**The gate is not optional.** Every schema change — package or base,
contributor or owner — passes `zbb gate`, which runs the real dataloader
against an ephemeral branch exactly as modules, collectors and products do.
Without a passed gate and its committed stamp nothing publishes and nothing
works downstream. The local scratch DB (Phase 4a) only makes the gate pass
on the first try; it never replaces it.

**Concrete classes, not interface-targeting.** Anyone can generate the
concrete classes their collector emits, so collectors target the package's
classes. Base interfaces are what those classes `extends` — they give the
data its generic meaning (a `WizUser` *is a* `User`), they are not the
ingest target.

**Modes of invocation.** Default is **request-driven**: the user describes
the schema need; no platform task required. If the user references a
ZeroBias task (UUID or task name), additionally follow the **task-driven
appendix** at the end.

**Headless runs (`claude -p "add a schema for Wiz findings"`).** Same flow
and the same autonomy contract; three hard rules:
- **Pre-flight first**: run the `prerequisites` skill (Phase 0) before
  touching anything. If anything is missing, print the exact setup
  instructions and exit — never fail mid-flow.
- **The run ENDS after Phase 5** (org load). Print what was created, how to
  verify, and: *"verify the org artifact, then run
  `claude -p 'open the PR for schema <vendor>/<code>'` (or continue
  interactively)"*. Phases 6–7 are human-gated and never run headless.
- **Decision forks stop the run**: schema already exists (or is in an open
  PR), dependency chain incomplete, gate conflict → print a structured
  report of the state and the decision needed, exit cleanly, change nothing
  further.

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

**Naming:** `<vendor>` and `<code>` segments must match `^[a-z0-9]+$` —
lowercase alphanumeric only, no hyphens/underscores/dots (the platform
`vspCodeValidator` constraint). Interface/class names are PascalCase;
fields are camelCase dot-notation. **NEVER rename** a published schema
package or its registered classes — the dataloader cannot reassign class
ownership; retire via `deprecated.yml` and add the new name instead.

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
- If it exists (anywhere), STOP and ask the user what to do. An
  already-released package cannot be org-published; extending it is a
  PR-only change reviewed by zb — say so.

### Learn the vendor model

The request names concepts (*org, project, target, user, issue*); the
package needs their real shape. Sources, in this order — stop at the first
that covers every named concept, and never ask the user for what a source
can tell you:

1. **The Hub module**, if one exists: `module/package/<vendor>/<product>/api.yml`
   in the sibling checkout, or `npm view @zerobias-org/module-<vendor>-<product>`
   → its bundled spec. Its schemas are exactly what a collector will emit,
   so property names, types and enum values come from here verbatim.
2. **The collectorbot** for the vendor (`collectorbot/package/…/src/Mappers.ts`):
   shows which module fields already map to which base properties.
3. **The vendor's public API reference** (fetch the REST/GraphQL docs for
   each named entity): the entity's fields, its identifiers, its
   relationships to the other named entities, every documented status /
   type / severity value.
4. Only if 1–3 leave a named concept undefined: ask, once, listing exactly
   what could not be established.

### Decision procedure (decide, record, don't ask)

- **Class per named concept**, `<Vendor><Concept>` in PascalCase
  (`SnykOrganization`, `SnykIssue`); one class per file.
- **Parent**: for each concept, grep base interfaces by the concept and its
  synonyms (issue → `Finding`, `Vulnerability`, `SecurityFinding`;
  org → `Tenant`, `Organization`, `Party`; project → `Project`,
  `Repository`, `Application`; user → `User`, `Account`, `Principal`) and
  read the 3–5 nearest. Extend the one whose description matches the
  vendor's meaning; when two fit, the more specific one. Nothing fits →
  `<Vendor><Concept>Base extends` the nearest structural interface
  (`Component`, `Asset`, `Principal`), never bare `Object` when a base
  interface is close.
- **Properties**: the vendor's identifier (`keyed`), name/title, status or
  state, severity/type, timestamps (created/updated/resolved), owner /
  organization, URL — then whatever the source marks as core. Reuse a base
  field when one exists (`name`, `url`, `timeCreated`, `severity`, …);
  inline fields for one-off vendor attributes; `fields/` for anything two
  classes share. Skip volatile counters and pagination noise.
- **Links**: model every relationship *between the named entities*
  (org ⟷ projects, project ⟷ issues, project → target, org ⟷ users) as
  two-way links between the package's own classes/interfaces; links to
  base types are `uniLink: true`.
- **Enums**: every value the source documents, ALL_CAPS, no `UNKNOWN` or
  `OTHER` catch-all unless the vendor itself has one — completeness is the
  point (a collector must never invent a value).
- **Package-local `<Vendor><Base>Base` interfaces** only where you add a
  property or link base lacks; otherwise classes extend base directly.
- **`links: models:`** on a package interface only when the product's
  `segments` (its catalog `index.yml`) name a code that interface models.
- Write every non-obvious choice under **Decisions** in the package
  `README.md` (parent chosen and why, base gaps declared, sources used).
  That section is what the user reviews at Phase 6.

**Read base before designing.** `ls package/zerobias/zerobias/base/interfaces/`
and READ the 3–5 interfaces nearest to each concept the package needs
(their `extends`, properties and links) — base has 125+ interfaces and the
concept is usually there or nearly there. Also skim
`package/zerobias/zerobias/base/fields/` for reusable fields. What you
find decides Phase 3: extend directly, or extend-and-add.

## Phase 2 — branch first (never commit on dev or main)

```bash
git fetch origin
git switch -c feat/schema-<vendor>-<code> origin/dev
```

**This repo's PRs target `dev`** — the bottom of the promotion chain
`dev → qa → uat → main`. A merge to `dev` publishes the `dev` prerelease line
(dist-tag `dev`); promotion up the chain is a later, separate merge, and only
`main` publishes `latest`. The promotion-order check warns on any PR that
skips a step. Branch from `origin/dev`, PR back to `dev`.

## Phase 3 — scaffold + author

### Scaffold the package

```bash
mkdir -p package/<vendor>/<code>          # or package/<vendor>/<group>/<code>
./scripts/createNewSchema.sh package/<vendor>/<code>
```

The script copies the templates + `.npmrc`, substitutes the path-derived
names, and writes the `build.gradle.kts` marker (`plugins { id("zb.schema") }`)
required for gradle discovery. You fill `{name}` / `{description}` in
`catalog.yml` and `package.json`. **Verify the scaffold immediately**:
`ls -A package/<path>` must show `package.json`, `catalog.yml`, `README.md`,
`.npmrc` (dotfile!), `build.gradle.kts`. The README is in `files` (so it is
stamp-hashed) and carries the **Decisions** section the user reviews at
Phase 6 — fill its tables as you author, not afterwards. The scaffolded `package.json` already
carries `"registry": "https://pkg.zerobias.org/"` and an `orgId`
placeholder (filled below). Exact file shapes: [templates.md](templates.md).

### Author the definitions

Under `classes/` `interfaces/` `fields/` `enums/` `documents/`, per the
**Schema Definition Reference in [CLAUDE.md](../../../CLAUDE.md)**
(per-artifact rules, link patterns, viewProperties, enum ALL_CAPS, field
reuse order). Non-negotiables:

- Never hand-edit `version` after creation — CI owns bumps (new packages
  start at `1.0.0`).
- `dependencies`: `@zerobias-com/schema-zerobias-zerobias-platform` +
  `@zerobias-org/schema-zerobias-zerobias-base` (both `latest`), plus the
  catalog package the schema describes (`@zerobias-org/product-<v>-<p>`,
  or the suite package for a suite-level umbrella schema).
- `zerobias.package` MUST equal the dot-joined directory path + `.schema`;
  `zerobias.imports` lists `zerobias.zerobias.platform.schema` +
  `zerobias.zerobias.base.schema`.
- **Every definition file starts with `id:`** (enums and documents also
  `fieldId:`) — the dataloader refuses a file without one
  (`Unable to handle interface 'X', id is missing`). Classes/interfaces:
  `UUIDv5(NIL, Name)` — deterministic from the name; fields/enums/
  documents: a fresh UUIDv4. Recipes in
  [templates.md → Generating ids](templates.md#generating-ids). Never
  change a published id and never mint a second id for an existing name.
- Every concrete class `extends` a base interface where one fits (that is
  what makes a `WizUser` count as a `User` for every base-level consumer);
  extending `Element` enables framework linking.
- **Retiring a definition: never rename, never delete in place.** Ids are
  derived from names, so a rename is a delete + create and the dataloader
  soft-deletes whatever your package stops mentioning. The pattern (real
  example: `package/w3geekery/smemart/deprecated.yml`): keep the old file
  untouched until the retirement commit, add the new name as a NEW file
  with its own id, then list the old name under the right key in
  `deprecated.yml` with a comment saying **why** (absorbed by a platform
  primitive, renamed to X, duplicate of Y) — "no longer needed" is not a
  reason. Keys: `classes:`, `interfaces:`, `fields:`, `enums:`,
  `documents:`; strings only. A name cannot be both `skip: true` and
  deprecated.

### When base lacks something — extend it inside the package

This is the heart of the skill. **Never edit base.** Declare a
package-local interface that `extends` the base one and carries the
missing part; concrete classes extend the package interface, not the base
one. Name it `<Vendor><Base>Base` when the plain `<Vendor><Base>` name is
the concrete class (the common case), otherwise `<Vendor><Base>`.

| Base lacks… | Declare in the package |
|---|---|
| a **property** on `User` | `interfaces/WizUserBase.yml: extends [User]` + the property; `classes/WizUser.yml: extends [WizUserBase]` |
| a **link** between `User` and `App` | `WizUserBase.secondApprovedBy → WizAppBase.id.secondApprover` and `WizAppBase.secondApprover → WizUserBase.id.secondApprovedBy` — a normal two-way link, both ends inside the package |
| a whole **generic interface** (a `Finding`) | `interfaces/WizFindingBase.yml: extends [Object]` (or the nearest base interface) with its properties; classes extend it |
| a link from that new interface **to a base type** | `uniLink: true` on the package side only — base never links back to a package. It becomes two-way if and when zb promotes the interface |

```yaml
# interfaces/WizAppBase.yml — what App should have had, for Wiz
id: <UUIDv5(NIL, "WizAppBase")>
description: "Wiz application: App plus the second-approver relationship"
extends:
  - App
properties:
  - secondApprover:
    linkTo: WizUserBase.id.secondApprovedBy

# interfaces/WizUserBase.yml
id: <UUIDv5(NIL, "WizUserBase")>
description: "Wiz user: User plus the applications it second-approves"
extends:
  - User
properties:
  - secondApprovedBy:
    multi: true
    linkTo: WizAppBase.id.secondApprover

# classes/WizUser.yml — the collector emits THIS
id: <UUIDv5(NIL, "WizUser")>
description: "A user in Wiz"
extends:
  - WizUserBase          # not User
properties:
  - wizId:
    field: wiz.id
```

The data works end to end at the interface level for the developer — no
waiting on base — and `WizUser` is still a `User` everywhere base is
consumed. At PR review zb owners decide whether `secondApprover` /
`secondApprovedBy` (or all of `WizFindingBase`) belong in base; if so, **zb
updates the PR**: the promoted parts move to base, the package interfaces
lose them, the classes extend base directly, and unilinks can become
two-way. Nothing for the contributor to redo.

### Pitfalls the gate finds last — read for them first

Learned authoring the physical-space model (schema #87); each one costs a
gate run if found late. There is no script for these — read the chain.

- **Redeclaring an inherited property is an overload, not an override.** If
  any interface in the `extends` chain already has `capacity`, your
  interface must not declare `capacity` again — the dataloader refuses
  (`… already exists on extended class`). Read the whole chain, not just
  the parent.
- **Diamonds bring duplicate properties.** `Asset` and `Location` both
  define `inventoryItems`; an interface extending both (directly or through
  parents) collides. `Environment` on `main` gets away with it, so the
  loader tolerates this pair today — don't rely on it; pick one parent.
- **`skip: true` interfaces are not loaded** (e.g. `Datacenter`). Don't
  extend them, don't edit them expecting an effect.
- **T3 must be identical on both link halves** when both declare it
  (`t3 fields do not match` otherwise); declaring it on one side is fine.
- **Geometry and quantities use the platform `number` type**; counts use
  `integer`. Both resolve without a local field file.
- **`viewProperties` cannot read a link attribute (T3) yet** — a column
  that needs one has to wait; show the linked object's `name` instead.
- **Top-level `links: models:` blocks load** (deferred resolution to
  catalog codes) — a clean gate proves the block is well-formed, not that
  the codes exist; verify codes in the segment / compliance_feature repos.
- **Resource links do not inherit.** A `models` block lands on the
  declaring interface only, never on what extends it. Put it on the most
  abstract interface whose *name* still entails the capability
  (`Repository` ⇒ VCS, `IdentityProvider` ⇒ IAM), never on structural roots
  (`Object`, `Component`, `Asset`, `Application`, `Principal`, `Party`).
- **A new interface needs at least two properties.** Single-property
  interfaces break the platform's GraphQL builder (the `FederatedIdentity`
  lesson); give it a second real property or fold it into its parent.
- **A package `README.md` is stamp-hashed** (it is in `files`). A docs-only
  README edit invalidates `gate-stamp.json` like any content change — re-gate
  or ship it with the next content commit.

### Set the org target BEFORE the first gate

**Replace the scaffolded `zerobias.orgId: "{target-org-uuid}"` in the
package's `package.json` with the real org UUID now** (`zbb --slot <slot>
env get ZB_ORG_ID | tail -n1` from inside the repo). A leftover placeholder
fails the gate (`zerobias.orgId "{target-org-uuid}" is not a valid UUID`).
With orgId present the gate's dataloader step seeds
your org into the ephemeral branch and runs org-scoped, matching how
org-scoped tokens authorize. ⚠ The gate-stamp's sourceHash DOES cover
`package.json`: deleting orgId later (Phase 7) invalidates the stamp, so
budget one more gate at the end.

## Phase 4 — local scratch DB, then gate (git add FIRST, always via zbb)

### 4a — iterate locally (seconds per run)

The gate loads through a remote Neon branch and takes minutes for a small
package; the local scratch DB runs the same dataloader checks in seconds.
Iterate here until the load is clean, then gate once. Needs Docker.

```bash
npx @zerobias-org/util-content-dev-schema          # separate terminal: Postgres 17 on :15432, db content_dev
export PGHOST=localhost PGPORT=15432 PGUSER=postgres PGPASSWORD=postgres PGDATABASE=content_dev PGSSLMODE=disable
cd package/<path> && dataloader --content-dev --skip-pgboss --skip-dynamo -d ./
# clean = "Importer finished successfully", exit 0
```

What it catches: missing/invalid ids, unresolved `extends`, one-sided
links, unresolved `t3`, enum case, `viewProperties` JSONata, field
references. Full recipe and its differences from CI: `CONTRIBUTING.md`.

### 4b — gate (mandatory — nothing publishes without it)

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
with package size and your link**: a vendor package takes minutes (base,
for reference, takes 1–3 h). It is not hanging — tail the log. Two
`✗ vault-connection` lines at the top are harmless preflight noise. On
success **commit `gate-stamp.json`** — CI's publishGuard rejects publishes
without a valid committed stamp, and **no PR workflow runs the gate for
you**.

⚠ **Skipped ≠ passed**: with `ZB_TOKEN` absent the dataloader step is
SKIPPED and the stamp records `"testDataloader": "skipped"` — fine for an
external contributor's PR, NOT fine for this flow: the org-first path
requires a stamp that says `"passed"`. Check it before proceeding.

If you gated before adding new files, re-gate after `git add`.

## Phase 5 — publishOrg + load into the user's org

Publishes an org-private rc version (`<X.Y.Z+1>-rc.<orgIdStripped>.<n>`,
computed by zbb — never hand-authored) of the schema package **and its
`-ts` twin**, and queues a dataloader job into the target org — no PR, no
shared catalog involved. Publishing re-runs the dataloader step to
regenerate the TS twin, so budget the same time as the gate. `zbb
publishOrg` needs `lifecycle.publishOrg` in the repo's `zbb.yaml` — on a
branch that predates it, zbb falls back to the meta-repo and dies with
`bash: ./gradlew: No such file or directory`; rebase onto `dev`.

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
`-rc.<org>.1+` can be REJECTED ("greater than latest"). If the load is
rejected, the fix is a one-time
`npm dist-tag add <pkg>@<new-rc> latest --registry=https://pkg.zerobias.org`
(run by the user; the next shared release reassigns `latest` on publish)
before re-loading. Apply to the YAML package; the `-ts` twin only needs it
if a consumer resolves it by `latest`.

Notes: org users can only queue org-private (`-rc.<org>`) loads — a plain
catalog-semver load is 403 (platform-admin only). Org loads need
build-tools ≥ **1.0.137** (verify:
`./gradlew buildEnvironment | grep build-tools`; a stale locally-published
copy in `~/.m2` can shadow the release).

## Phase 6 — user verification + sign-off  ⭐

Show the user the org-loaded schema:
- the completed org dataloader job (id + status),
- the loaded classes and their `extends` bindings in the app (model/schema
  browser) — including the package's `<Vendor>XBase` interfaces and the
  links between them,
- the published rc versions of BOTH npm artifacts
  (`npm view <pkg> versions` / `<pkg>-ts`).

Have them judge names, descriptions, property shapes, and link targets —
schema mistakes are expensive later (published names can't be renamed).
**Do NOT proceed to the PR until the user explicitly confirms** (e.g.
"looks good, ship it"). Silence or further tweak requests are NOT
sign-off — if unclear, ask. Headless runs never reach this phase — they
stop after Phase 5 by design.

## Phase 7 — PR to dev (after sign-off only)

1. Flip ownership to the shared catalog: **delete `zerobias.orgId` from
   `package.json`, then RE-GATE** (`cd <pkg> && zbb --slot <slot> gate`):
   the stamp's sourceHash covers `package.json`, so without a fresh gate
   the publish workflow rejects the stamp (`source-hash-changed`) after
   merge. Leftover `-rc.<org>.<n>` npm versions don't collide with catalog
   semver.
2. Commit — selective staging, conventional message, no co-authors:

```bash
git add package/<vendor>/<code>/
git commit -m "feat(<vendor>-<code>): add <Name> schema"
git push -u origin <branch>
```

3. PR against **dev**:

```bash
gh pr create --base dev \
  --title "<same conventional subject>" \
  --body "…summary (what the schema models and WHY), the package-local
          interfaces that extend base and what each ADDS to base (this is
          the promotion review list — name each <Vendor>XBase, the
          property/link it carries, and the unilinks toward base),
          validation checklist (gate ✓ with testDataloader passed ✓,
          gate-stamp committed ✓, org-loaded + user-verified ✓), and
          anything needing SME review (naming calls, extends choices,
          link targets)…"
```

The PR is how the schema reaches the shared catalog; the org-private
artifact from Phase 5 stays in the user's org either way. An org that
wants to keep a schema private simply never opens the PR — that IS the
customer own-schema path, fully supported.

### What happens at review (zb owners)

Anyone with owner access on the zb org reviews the `<Vendor>XBase`
interfaces and decides, per interface or per property, whether to
**promote** it into base or keep it vendor-local. Promotion is zb's change,
made on the same PR: base gains the interface/property/link, the package
interface drops the promoted part (or is removed if now empty), the
classes `extends` the base interface directly, and unilinks toward base
become two-way. The contributor is told what moved; nothing to redo.

### Authoring into base (zb owners only)

Sometimes zb owners promote a reviewed design straight into
`package/zerobias/zerobias/base/` (schema #87, the physical-space model, is
the exemplar). Accept the trade-off first: **the change is unusable and
unverifiable by anyone until it is merged and published** — no org load, no
early collection. If that wait is a problem, author it as a package and
promote later; that is the default even for zb.

When you do edit base:
1. Branch off `origin/dev`; the PR targets **`dev`** like every package PR
   (base is a package: it publishes the `dev` prerelease line first and is
   promoted dev → qa → uat → main). Only an owner who explicitly accepts
   publishing `latest` on merge targets `main`.
2. Additive only: new interfaces/fields/enums/documents, new properties,
   new parents on existing interfaces. Never rename, remove or retype
   anything published; retire via `deprecated.yml`.
3. Every new file carries its id (interfaces `UUIDv5(NIL, Name)`).
4. Walk the pitfalls list above by hand — read every `extends` chain you
   touch, all the way up.
5. **Run the gate.** Base is ~550 files and takes 1–3 hours through a
   remote Neon branch; that is the cost of touching base, not a reason to
   skip it. The stamp must be refreshed and committed **before** the PR is
   mergeable — CI's publish guard rejects a stale stamp, and no PR workflow
   runs the gate for you.
6. PR body: what each new interface/property/link adds, why base and not a
   package, and the gate evidence (`"testDataloader": "passed"`).

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
- **Enum value not ALL_CAPS** → rejected at review, even though the gate
  passed: the dataloader only checks for a leading letter
  (`Enumeration value must start with letter`). Every value is
  `[A-Z][A-Z0-9_]*`; fix it before the PR, not after.
- **`Unable to handle <kind> '<name>', id is missing` / `… is not a valid
  UUID`** → the file lacks `id:` (or an enum/document lacks `fieldId:`);
  mint it per [templates.md → Generating ids](templates.md#generating-ids).
- **`'<name>': it already exists as <id>, but this artifact declares id
  <other>`** → the name is already loaded under another id (file renamed,
  id re-minted). Reuse the existing id — an existing resource cannot be
  re-keyed.
- **`'<name>': that name is already taken by an existing resource … this
  package does not own`** (org loads) → your package collides with a
  PUBLIC name. Rename yours (the `<Vendor>` prefix exists for this) —
  private content cannot shadow public names.
- **`Left/Right link property 'x' already exists on extended class`** →
  you redeclared a property that base already has on the interface you
  extend. Drop it from the package interface; base has it.
- **Dataloader rejects a link** → links must be bidirectional and target
  an existing class/interface — see the link catalog in CLAUDE.md. A link
  from a package interface to a BASE type must be `uniLink: true`.
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
  org-publish format`** → the package is already a shared catalog artifact:
  it cannot be org-published, by design. Extending it is a PR-only change
  for zb review; new work goes in a new package.
- **`zbb publishOrg` → `bash: ./gradlew: No such file or directory`** → the
  repo's `zbb.yaml` on your branch has no `lifecycle.publishOrg` (branch
  predates it); rebase onto `dev`.
- **Gate seems to hang** → it is loading every file of the package into a
  remote Neon branch. Check the log tail before assuming a hang. A Neon
  connection timeout / `No route to host` is a network drop — re-run the
  identical command once.
- **`gateCheck`: `source-hash-changed` right after editing `package.json`**
  → package.json IS hashed (orgId add/remove included); re-gate.
- **PR opened with a stale `gate-stamp.json`** → it cannot merge: someone
  runs `cd <pkg> && zbb --slot <slot> gate` on the branch and commits the
  stamp. There is no CI fallback and no exception for base.
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
  rules, publish workflow, the extend-don't-edit rule for base.
- [templates.md](templates.md) — exact file shapes, id recipes.
- [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) — local scratch-DB recipe
  and the external-contributor lane (fork → gate → PR).
- [`scripts/createNewSchema.sh`](../../../scripts/createNewSchema.sh) —
  scaffold script.
