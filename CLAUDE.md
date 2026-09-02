# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Open-source monorepo for AuditgraphDB schema packages under the `@zerobias-org` organization. Schema packages define object types (classes, interfaces, fields, documents, enums) that are loaded into AuditgraphDB by the dataloader.

Build + publish pipeline: **gradle (`zb.schema` plugin) + `zbb-publish-reusable.yml`** — no lerna, no nx.

## Common Development Commands

### Setup and Installation
- **Initial setup**: `npm install` (refreshes root lockfile for commitlint + tsx dev deps).

### zbb setup — do this before any gate

`zbb` is the build CLI for this repo ([`zerobias-org/util`](https://github.com/zerobias-org/util/tree/main/packages/zbb),
`packages/zbb`). Install/upgrade with `npm i -g @zerobias-org/zbb`.

**Lifecycle commands require a loaded slot.** A slot is a named local environment holding port
allocations, generated secrets, and the env vars declared across every `zbb.yaml`. Without one,
`zbb gate` refuses:

```
Not inside a loaded slot. Run: zbb slot load <name>
```

First time on a machine:
```bash
zbb slot create local     # scans zbb.yaml files, allocates ports, pulls env/secrets
zbb slot load local       # runs preflight tool checks, spawns a subshell with env loaded
```
`slot load` drops you into a subshell with the prompt `[zb:local]:path$`. Work normally inside it —
gradle, npm, and docker all see the slot env. `exit` leaves; `zbb slot load local` reconnects
instantly. Re-running `zbb slot load` with no args re-evaluates from the current directory, picking
up newly-declared vars. `zbb slot list` shows existing slots.

Schema is a content repo — it defines no long-running services, so **no stack needs to be started**.
A loaded slot is sufficient.

> **Exception:** explicitly-pathed gradle tasks (`zbb :hl7:fhir:gate`) are passed straight through to
> gradle and work **without** a slot. Bare lifecycle names (`zbb gate`, `zbb gateCheck`,
> `zbb publish`) are the ones that require it. If you get the "not inside a loaded slot" error, that
> is what you hit.

### Per-package validation

**Run gates through `zbb`, never `./gradlew` directly.** `zbb` wraps the gradle wrapper and pins the
JDK toolchain to Java 21. A bare `./gradlew` picks up whatever JDK is on `PATH`; on JDK 25 Gradle
8.10.2 aborts with an opaque `25.0.2` and nothing else. That is **not** a missing-JDK problem and
does **not** mean you should install a different JDK — it means `zbb` was bypassed.

**Preferred — `cd` into the package and run the bare task.** `zbb` walks up to the gradle root,
detects the current subproject from cwd, and prefixes the task name for you:
```bash
cd package/hl7/fhir && zbb gate          # runs :hl7:fhir:gate
```
This works at any depth and needs no hand-typed gradle path.

Explicit paths also work from the repo root. Each schema's gradle path mirrors its directory:
```bash
zbb :{vendor}:{code}:gate                  # depth 2 (e.g. :hl7:fhir)
zbb :{vendor}:{group}:{code}:gate          # depth 3 (e.g. :zerobias:zerobias:base)
```
Either way, keep the gate scoped to one package. A bare `zbb gate` from the repo root runs every
schema and rewrites every `gate-stamp.json`.

`gate` chains `validate` → `lint` → `compile` → `test*` → `buildArtifacts` → `testDataloader` →
`writeGateStamp`.

`testDataloader` loads the schema into an ephemeral Neon branch via the **remote dataloader service**
(`DATALOADER_SERVICE_URL`, default `https://app.zerobias.com/api/dataloader`), authenticated by
`ZB_TOKEN`. No local Neon credentials are involved — `NEON_API_KEY` / `NEON_PROJECT_ID` are not read
by the gate.

> **If `ZB_TOKEN` is unset or blank, `testDataloader` is skipped (not failed) and the gate still
> writes a stamp.** The stamp records this honestly as `"testDataloader": "skipped"` rather than
> `"passed"` — so check that field before trusting a green gate. Skipped is not passed.

### Repo-wide tasks
- `zbb validateUniquePackageNames` — fails if two schemas share the same `zerobias.package` block name.
- `zbb projectPaths` — used by zbb to map gradle project paths to disk locations.
- `zbb changedModules` — lists schemas modified since the last version tag.

### Lifecycle through `zbb`
The same commands the CI workflow runs (per `zbb.yaml`):
```bash
zbb gate           # → ./gradlew gate
zbb gateCheck      # → ./gradlew gateCheck
zbb version        # → ./gradlew versionStandardPackages (single-writer, main only)
zbb publish        # → ./gradlew publish
zbb publishOrg     # → ./gradlew publishOrg -PorgPublish=true
                   #   org-first SDLC: publishes an org-private rc (X.Y.Z-rc.<orgId>.<n>)
                   #   and queues an org dataloader load; the -ts twin follows automatically
```

### Per-package helpers
Schema packages carry **no npm scripts at all** — the publish flow is fully gradle-driven. If you
need to validate a package, run the gate (see [Per-package validation](#per-package-validation)),
not an npm script.

## Repository Architecture

### Monorepo Structure
- **`package/`**: schema packages organized by vendor/code (e.g. `hl7/fhir`, `zerobias/zerobias/base`).
- **`scripts/`**: dev helpers (`createNewSchema.sh` scaffolder, `setup-org-credentials.sh` one-time credential/slot setup).
- **`templates/`**: starter files for new schemas (`catalog.yml`, `package.json`) with `{dashed}`/`{dotted}`/`{path}`/`{name}`/`{description}` placeholders.
- **`bundle/`**: `@zerobias-org/schema-bundle` aggregate; auto-refreshed by the publish workflow's `update-bundle` step.
- **`build.gradle.kts`** + **`settings.gradle.kts`**: root validator + auto-discovery of schemas by `build.gradle.kts` marker.
- **`zbb.yaml`**: lifecycle map between zbb commands and gradle tasks; imports the shared dev-stack credentials.
- **`gradle.properties` / `gradle-ci.properties`**: shared + CI properties (vault refs).

### Schema Package Structure
Each schema package follows this structure:
```
package/{vendor}/{code}/
├── build.gradle.kts      # one-liner: plugins { id("zb.schema") } — written by the scaffolder
├── package.json          # @zerobias-org/schema-{vendor}-{code}
├── catalog.yml           # Schema catalog entry (name, package, description)
├── .npmrc                # Registry configuration (copied from repo root by the scaffolder)
├── gate-stamp.json       # Committed; preflight rejects packages without one
├── classes/              # AuditgraphDB class definitions (YAML)
├── interfaces/           # Interface definitions (YAML)
├── fields/               # Field definitions (YAML)
├── documents/            # Document type definitions (optional)
├── enums/                # Enum type definitions (optional)
└── deprecated.yml        # Optional: names of removed classes/interfaces/fields/enums/documents
```

### Technology Stack
- **Gradle**: build + publish orchestration via the `zb.workspace` + per-package `zb.schema` plugin family.
- **zbb**: CLI that translates lifecycle commands (gate, version, publish, publishOrg) to gradle tasks.
- **`zbb-publish-reusable.yml`**: shared GitHub Actions workflow that runs gate-check, version-bump (single-writer on main), matrix publish, and bundle refresh; env-branch sync is dispatched separately (see [Branches](#branches)).
- **TypeScript twin**: each schema publishes a companion `-ts` npm package generated by `@zerobias-com/platform-schema-ts-generator` against the schema loaded into an ephemeral Neon Postgres branch.
- **YAML**: schema definition format.

## Schema Definition Reference

The dataloader is the source of truth for schema semantics — everything below marked *enforced by
the dataloader* fails at load time (gate or CI), not at file-validation time. Definitions live in
five directories; filenames ARE names (PascalCase files for classes/interfaces, camelCase
dot-notation for fields/enums/documents).

### Identity (`id`) — required on every definition file

Every file under `classes/`, `interfaces/`, `fields/`, `enums/` and `documents/` starts with an
`id:` line; enums and documents carry a second one, `fieldId:`. The dataloader **refuses a file
without one** (`Unable to handle interface 'X', id is missing` / `… is not a valid UUID`) — enforced
at load time, so the gate's `testDataloader` step is where a missing id surfaces.

| Artifact | `id` | `fieldId` | How to mint |
|---|---|---|---|
| class, interface | **UUIDv5(NIL namespace, Name)** — deterministic from the (globally unique) name; `Account` → `1a32e499-4e51-5bae-9e39-70f6c2e4184a` | — | `python3 -c 'import uuid,sys;print(uuid.uuid5(uuid.UUID(int=0),sys.argv[1]))' Account` |
| field | UUIDv4, minted once | — | `python3 -c 'import uuid;print(uuid.uuid4())'` |
| enum, document | UUIDv4 — the data type it declares | UUIDv4 — the backing field the dataloader creates alongside it | same v4 one-liner, twice |

Rules (enforced by the dataloader):
- The declared id must **match the existing row** for that name — a name that already exists in
  the target DB under a different id is refused rather than silently duplicated. So: **never change
  a published id, never mint a second id for an existing name.** New files get new ids; existing
  files keep theirs.
- An id that resolves to a row owned by **another package** is refused (ids are globally unique).
- `uuidgen` on macOS cannot do v5 (Linux `uuidgen --sha1 --namespace … --name …` can); the python
  one-liners above work on both.

### Classes (`classes/`)

Concrete classes define AuditgraphDB object types — real objects collected from external systems.

**Filename:** PascalCase matching the class name (e.g. `X509Certificate.yml`).

```yaml
id: ccddd2e5-e455-585e-9bb7-902903228b0d           # REQUIRED — UUIDv5(NIL, "Bid")
description: "A vendor's bid on an RFP"               # REQUIRED
extends:                                              # Optional (defaults to 'Object')
  - Object                                            # Can extend INTERFACES only (not classes)
icon: images/classes/myvendor/Bid.svg                 # Optional icon URL
shared: false                                         # Optional (default: false)
tags:                                                 # Optional tags for categorization
  - query-folder.bids
properties:                                           # Optional (must be an ARRAY if present)
  - price:
    field: bid.price                                  # Reference a field in fields/
  - isDraft:                                          # Inline field definition
    field:
      type: boolean
      description: "True while the bid is unsubmitted"
  - responses:                                        # Multi-valued link
    multi: true
    linkTo: BidResponse.id.bid
viewProperties:                                       # Optional UI display config
  "Name":
    jsonata: name
    sort: name
```

Real examples: `package/w3geekery/smemart/classes/Bid.yml`,
`package/zerobias/zerobias/base/classes/CAPEC.yml`,
`package/microsoft/azure/classes/AzureResourceGroup.yml`.

**Class rules (enforced by the dataloader):**
- `id` is **required** — `UUIDv5(NIL, ClassName)`; see [Identity](#identity-id--required-on-every-definition-file).
- `description` is **required**.
- `properties` must be an **array** if present.
- Class names are **globally unique** (across every loaded schema, not just yours).
- Classes can only extend **interfaces** (never other concrete classes).
- No `extends` → the class extends `Object` (for non-platform schemas).
- Property names must be **unique** within the class, including inherited properties.
- Cannot overload an extended class's field property with a link.
- Cannot `skip` and `deprecate` a class simultaneously.

### Interfaces (`interfaces/`)

Interfaces define shared property contracts that classes and other interfaces extend. They enable
polymorphism — and on this platform they are the primary integration surface (see
[Extending the base schema](#extending-the-base-schema--interfaces-first)).

**Filename:** PascalCase matching the interface name (e.g. `Account.yml`).

```yaml
# package/zerobias/zerobias/base/interfaces/Account.yml (abridged)
id: 1a32e499-4e51-5bae-9e39-70f6c2e4184a                        # REQUIRED — UUIDv5(NIL, "Account")
description: "A user or system account inside an application"   # REQUIRED
icon: images/classes/auditmation/base/Account.svg               # Optional
extends:
  - Principal                     # Can extend OTHER INTERFACES only
viewProperties:
  "Account Name":
    jsonata: name
    sort: name
  "Groups":
    jsonata: $count(groups)       # Computed property
properties:
  - login:
    field: account.login          # Reference a shared field
  - email:
    field: email
    multi: true                   # Array of emails
  - identity:                     # Link with multiple target types
    multi: true
    linkTo:
      - FederatedIdentity.id
      - FederatedIdentity.email
      - FederatedIdentity.login
```

**Interface rules (enforced by the dataloader):**
- `id` is **required** — `UUIDv5(NIL, InterfaceName)`; see [Identity](#identity-id--required-on-every-definition-file).
- `description` is **required**.
- Interface names are **globally unique**.
- Interfaces can extend **other interfaces** only (not concrete classes).
- **No circular extends chains** (loop detection).
- Property names must be **unique** within the interface.

### Fields (`fields/`)

Fields define atomic, reusable property types, referenced by class/interface properties.

**Filename:** camelCase dot-notation `{parent}.{fieldName}.yml` (e.g. `account.login.yml`), or a
bare name for cross-cutting fields (e.g. `locationCode.yml`).

```yaml
# package/zerobias/zerobias/base/fields/account.login.yml
id: 88eeaa46-8365-433d-8bb1-e994eb907343   # REQUIRED — UUIDv4, minted once
description: "The login for the entity"    # Optional (defaults to field name)
displayName: "Login"                       # Optional (defaults to field name)
type: "string"                             # REQUIRED
keyed: true                                # Optional (default: false) — searchable key field
indexed: true                              # Optional (default: true); keyed forces it to true
reserved: false                            # Optional (default: false) — protected field
defaultValue: "unknown"                    # Optional
example: "jdoe"                            # Optional
```

**Supported types:** `string`, `boolean`, `number`, `integer`, `date`, `datetime`

**Field rules (enforced by the dataloader):**
- `id` is **required** — a UUIDv4 minted once; see [Identity](#identity-id--required-on-every-definition-file).
- `type` is **required** and must be non-empty.
- Field names are **globally unique**.
- A field cannot be named `enum` (use `enums/` instead).
- `keyed` / `indexed` must be booleans if specified; `keyed: true` automatically sets `indexed: true`.
- Reserved fields cannot also be keyed.

### Enums (`enums/`)

**Filename:** camelCase dot-notation (e.g. `team.privacy.yml`).

```yaml
id: 1a4d62e9-1a51-4e0b-b9e8-0cc3f1521f7e       # REQUIRED — UUIDv4 (the data type)
fieldId: 3d741741-6c55-4902-9444-6354dc490b08  # REQUIRED — UUIDv4 (the backing field)
description: The level of privacy this team should have.
displayName: Privacy
values:                                    # REQUIRED, non-empty array
  - SECRET: 'Only visible to organization owners and members of this team.'
  - CLOSED: 'Visible to all members of this organization.'
```

**Enum rules (enforced by the dataloader):**
- `id` **and** `fieldId` are **required** (both UUIDv4); see [Identity](#identity-id--required-on-every-definition-file).
- `values` is **required** and cannot be empty. Entries are strings or `{KEY: description}` objects.
- Values **MUST be ALL_CAPS** matching `[A-Z][A-Z0-9_]*` — lowercase values fail at load time.
- Values cannot repeat within the same enum.
- Enum names are **globally unique**.

### Documents (`documents/`)

Documents define complex nested object structures (compound types).

**Filename:** camelCase dot-notation (e.g. `organization.plan.yml`).

```yaml
id: c92031c2-f225-4be7-ade5-67c74b753e30       # REQUIRED — UUIDv4 (the data type)
fieldId: d89c7157-f2d6-4fa5-8edf-57f57e783f17  # REQUIRED — UUIDv4 (the backing field)
description: "Organization billing plan"     # Optional
displayName: "Plan"                          # Optional
properties:                                  # REQUIRED (must be an array)
  - company:
    field:
      type: string
  - seats:
    field:
      type: integer
```

**Document rules (enforced by the dataloader):**
- `id` **and** `fieldId` are **required** (both UUIDv4); see [Identity](#identity-id--required-on-every-definition-file).
- `properties` must be an **array**, referencing existing fields or documents.
- Top-level property names cannot repeat; document field names are **globally unique**.
- Links from documents **require** `uniLink: true`.

### `deprecated.yml`

Lists removed classes/interfaces/fields/enums/documents so the dataloader can clean them up (and
history stays traceable). All arrays contain strings only:

```yaml
classes:
  - OldClassName
interfaces:
  - OldInterface
fields:
  - old.fieldName
enums:
  - old.enumName
documents:
  - old.documentName
```

Real example: `package/w3geekery/smemart/deprecated.yml`.

### Link patterns (property `linkTo`)

Links create graph relationships between classes. They are defined inside `properties` arrays.

```yaml
properties:
  # Simple link (bidirectional by default — the other side must declare its half)
  - subscription:
    linkTo: AzureSubscription

  # Multi-valued link (one-to-many)
  - members:
    multi: true
    linkTo: Account

  # Explicit bidirectional pairing: ClassName.matchField.pairedProperty
  # (see package/zerobias/zerobias/base/classes/CAPEC.yml)
  - parent:
    linkTo: CAPEC.id.children       # pairs with the `children` property below
  - children:
    multi: true
    linkTo: CAPEC.id.parent

  # Multiple target types (see base interfaces/Account.yml)
  - identity:
    multi: true
    linkTo:
      - FederatedIdentity.id
      - FederatedIdentity.email
      - FederatedIdentity.login

  # Unidirectional link — no reverse property on the target
  # (see package/microsoft/azure/classes/AzureResourceGroup.yml)
  - managedBy:
    linkTo: AzureResource
    uniLink: true

  # Temporal / attributed relationship: t3 names a field stored on the link itself
  # (see base interfaces/Repository.yml — user/group carry permissionSet)
  - user:
    multi: true
    linkTo: SourceCodeMgmtAcct
    t3: permissionSet

  # Required link
  - owner:
    linkTo: Account
    required: true

  # Hidden link (not shown in UI)
  - internalRef:
    linkTo: InternalObject
    hidden: true

  # Pattern-matching link (target resolved by value match; property must be a core type)
  - relatedAssets:
    linkTo: Asset
    patternMatch: true

  # Deferred link — the target class may not exist yet; resolved on a future schema load
  # (see base interfaces/Ticket.yml — impactedComponent)
  - impactedComponent:
    multi: true
    linkTo: Component
    defered: true                   # NOTE: spelling with one 'r' — matches the loader

  # Name the link predicate explicitly (a registered platform link predicate)
  - hiddenByTechniques:
    multi: true
    linkTo: Technique
    resourceLinkType: hidden_by
```

**Link rules (enforced by the dataloader):**
- `linkTo` as an array **cannot** use `patternMatch` / `patternMatchType`, cannot be empty, and each
  item must include a **period** (`ClassName.propertyName`); property names in the array cannot repeat.
- Both sides of a bidirectional link **must match** — one-sided links fail with `No matching link`
  unless `uniLink: true` or `defered: true` is set.
- `t3` fields must exist (in your package or an import) and match on **both** sides of the link.
- Pattern-match properties must be **core types**.
- Cannot overload an inherited field property with a link.
- Document links require `uniLink: true`.

### Property definition patterns

```yaml
properties:
  - login:
    field: account.login            # 1. Reference an existing field (yours or an import's)

  - kev:                            # 2. Inline field — unique to this class, used once
    field:
      type: boolean                 #    Required for inline
      description: "Known Exploited Vulnerability"   # Required for inline
      displayName: "KEV"            #    Optional; also: name, keyed, indexed, reserved,
      defaultValue: "false"         #    defaultValue, example
  - email:
    field: email
    multi: true                     # Array values (default: false)
    required: true                  # Required property (default: false)
```

**Preference order when adding a property:**
1. **Base schema field** if one fits (`email`, `url`, `name`, `timeCreated`, …) — search
   `package/zerobias/zerobias/base/fields/` first.
2. **Inline field** if the field is unique to this class and used only once.
3. **Package field** (`fields/` directory) if used by 2+ classes within the same schema.
4. **Enums and documents** are always declared in their directories, then referenced — never inline.

### View properties (dashboard configuration)

```yaml
viewProperties:
  "Column Header":                  # Display name in the UI
    jsonata: propertyName           # JSONata expression for the value
    sort: propertyName              # Optional: enables sorting on this column
  "Computed Column":
    jsonata: $count(members)        # JSONata functions work
  "Nested Value":
    jsonata: address.city           # Dot-notation for nested properties
```

**Rules:** a `sort` column cannot be more than **3 levels deep**, and the sorted property must exist
on the class or something it extends. Invalid JSONata fails at load time.

### Interface vs inline vs fields — decision table

| Scenario | Approach |
|----------|----------|
| Generic concept any vendor could yield | Base interface (add one via PR if missing — see below) |
| Properties shared across classes in the same vendor package | Vendor-specific mixin interface |
| Property unique to one class | Inline field definition |
| Property used in 2+ classes in the same package | Define in `fields/` |
| Enumerated values | Always `enums/`, then reference |
| Complex nested objects | Always `documents/`, then reference |

**Inheritance design guidelines:**
- **Extend base interfaces** whenever your class fits an existing concept (`Account`, `Asset`,
  `Repository`, `Application`, …).
- **Create vendor mixin interfaces** (e.g. `AzureObject`) for properties shared across that vendor's classes.
- **Multiple inheritance** is supported — combine base + vendor interfaces.
- **Keep extends chains shallow.**

```yaml
extends:
  - Repository        # from the base schema — the generic contract
  - AzureObject       # vendor mixin — shared vendor properties
```

### Resource links (`links:` — class/interface → catalog resources)

Separate from property `linkTo`: a **top-level** `links:` block on a class or interface `.yml` maps
a link **predicate** to a list of target **aliases** (catalog codes). It links the *type itself* to
existing catalog resources — products, segments, compliance features — not one object to another.

```yaml
# interfaces/Repository.yml (abridged; on `dev`)
description: "Source control repository"
extends:
  - Component
links:
  models:
    # --- segments ---
    - c_vcs      # Version Control Systems (VCS)
    - t_vchp     # Version Control Hosting Platform
    # --- compliance features ---
    - f_cvm2     # Code version management
```

Semantics (dataloader + platform ResourceLinker):

- The block is a map of `predicate → [alias, …]`. Predicates must be registered platform link
  predicates (`models`, `implements`, `references`, …); aliases are resolved against catalog resources.
- At load time the dataloader writes a **deferred resource-link segment** per `(predicate, alias)` —
  the target does **not** need to be loaded yet. The platform's ResourceLinker resolves each alias
  later and creates the actual link, minting the link type on the fly with direction fixed by the
  predicate's registered inverse/from-side. An alias that never resolves expires with the segment.
- Links attach to the **base** catalog resource, never a specific version. An alias that resolves to
  more than one non-version resource is ambiguous and the link is **skipped with an error** — use
  **code-style aliases** (`c_*`/`t_*` segment codes, `f_*` compliance-feature codes), never display names.
- Segments carry provenance (package code, artifact version, predicate, alias) and are
  **reconciled** on every load: remove a `links:` entry and reload, and the link disappears once no
  declarer remains. Two packages declaring the same link co-exist.

#### `links.models` — interface → segment / compliance feature *(pre-release, on `dev`)*

Base interfaces carry `links: models:` blocks mapping each interface to the catalog **segment
codes** and **compliance-feature codes** whose data model it is. `models` is the predicate (inverse:
`modeled_by`; the interface is the from side), so the graph reads `Repository models c_vcs` and
`c_vcs modeled_by Repository`.

This is the schema half of "segment declarations create schema obligations": a product categorized
under a segment must yield objects of the interfaces that segment is `modeled_by`. The annotation
pass currently lives on the `dev` branch (19 base interfaces, e.g.
`git show origin/dev:package/zerobias/zerobias/base/interfaces/Repository.yml`) and lands on `main`
with the next base publish. When adding a base interface, include a `models` block if the matching
segment/feature codes exist in the catalog.

### How the dataloader processes a schema package

Multi-pass, so cross-references resolve regardless of file order:

```
1. package.json  → upsert Package + Schema; link package dependencies
2. deprecated.yml → mass-deprecation of listed names
3. Enum + document DATA TYPES registered
4. fields/, then enum VALUES, then document PROPERTIES
5. interfaces/ (extends chains), then classes/, then their properties
6. uniLink opposite-link pass, then link matching (bidirectional pairing)
7. viewProperties passes
8. Cleanup: soft-delete + cache update
```

Three behaviors to internalize:

- **The package is the source of truth.** Any class/interface/field the DB has for your package
  that this load did not mention is **soft-deleted** (its properties and link types cleaned up).
  Renaming a file is a delete + create — see [Naming Rules](#naming-rules-critical) before renaming
  anything published.
- **Implicit imports.** Every schema implicitly imports the platform and base schema packages —
  declare them in `zerobias.imports` anyway (see [Dependencies](#dependencies)) so the dependency
  graph is explicit.
- **Deferred resolution.** `defered: true` property links and all top-level `links:` aliases resolve
  after load — a clean gate does not prove a deferred target exists, only that the declaration is
  well-formed.

### Common validation errors → fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `properties is not an array` | Properties defined as a map | Use array syntax: `- propName:` |
| `description is missing` | No description on class/interface | Add `description: "..."` |
| `extended interface does not exist` | Typo in `extends`, or missing import | Fix spelling / add the providing package to `zerobias.imports` |
| `extends logic loop found` | Circular inheritance | Break the cycle |
| `cannot overload extended properties field with a link` | Link reuses an inherited property name | Rename the link property |
| `No matching link` | Bidirectional link missing its other side | Add the reciprocal link, or `uniLink: true`, or `defered: true` |
| `t3 fields do not match` | t3 differs between link sides | Same t3 field on both sides |
| `LinkTo array item missing period` | Array linkTo without `.` | Use `ClassName.propertyName` |
| `Enumeration value must start with letter` | Lowercase/numeric enum value | ALL_CAPS (`[A-Z][A-Z0-9_]*`) |
| `Field type not specified` | Missing `type` on a field | Add `type: string` (or other type) |
| `field "x.y" not found` | Class references a field with no YAML | Create `fields/x.y.yml` or drop the reference |
| `Unable to handle <kind> '<name>', id is missing` | Definition file has no `id:` (or enum/document lacks `fieldId:`) | Add it — v5(NIL, Name) for classes/interfaces, v4 otherwise; see [Identity](#identity-id--required-on-every-definition-file) |
| `… id '<x>' is not a valid UUID` | Typo / placeholder left in `id:` | Paste the generated UUID |
| `'<name>': it already exists as <id>, but this artifact declares id <other>` | Name already loaded under another id (renamed file, re-minted id) | Reuse the existing id — an existing resource cannot be re-keyed |
| `'<name>': that name is already taken by an existing resource … this package does not own` | Org-private load collides with a public name | Pick a different name, or change the public package via PR — private content cannot shadow public names |

## Extending the base schema — interfaces first

The base schema — `package/zerobias/zerobias/base` — is **interface-heavy by design**: 125+
interfaces (`Account`, `Asset`, `Repository`, `Application`, `Backup`, `Pipeline`, …) and only a
handful of concrete classes. That is not an accident; it is how data reaches the platform:

- **Collectors and modules target base interfaces, not concrete classes.** A collector for a new
  product declares the interface(s) it emits (`Backup`, `Principal`, `Repository`, …) and ships
  data immediately — no vendor schema package required first.
- **The platform materializes a `Dynamic<Interface>` concrete class per interface** (e.g.
  `DynamicBackup` for `Backup`), routed by a discriminator field on the emitted objects — so
  interface-targeted data has a concrete home from day one.
- **Vendor concrete classes come later**, once the data shape stabilizes: they `extends` the base
  interface (plus an optional vendor mixin) and take over from the dynamic class.
- **Segment declarations create schema obligations.** A product categorized under a segment must be
  able to yield the objects that segment implies ("a backup tool better give me a list of
  backups"). The base interface *is* that contract, and
  [`links.models`](#linksmodels--interface--segment--compliance-feature-pre-release-on-dev) wires
  each interface to the segment/compliance-feature codes it models.

**When a generic concept is missing from `package/zerobias/zerobias/base/interfaces/`, the right
move — for agents and humans alike — is to add a new interface to the base schema and open a PR to
`main`.** This is the default path, not an exception: base grows exactly this way (recent
additions: `AuditLogEntry`, `PipelineRun`, `SoftwarePackage`, `PackageRegistry`). Do not park a
generic concept in a vendor package because a base PR feels heavyweight — it isn't, and a generic
interface hidden inside a vendor package is invisible to every other integration. The
[`create-schema` skill](.claude/skills/create-schema/SKILL.md) covers this flow end to end.

### Where a new type belongs

| You are adding | Put it in |
|---|---|
| A generic concept any vendor could yield (audit-log entry, pipeline run, secret, ticket) | **New base interface** → PR to `main` |
| Vendor-specific properties/links over an existing concept | Concrete class (+ optional vendor mixin interface) in `package/<vendor>/…` |
| Properties shared only across one vendor's classes | Vendor mixin interface in that vendor's package |
| Org-internal types that should not enter the public catalog | Your own schema package in your fork, loaded into **your org** via `publishOrg` — no PR needed |

### Designing a base interface

- Model the **concept**, not one vendor's API. Property names stay generic; prefer existing base
  fields (`name`, `email`, `url`, `timeCreated`, …) over minting new ones.
- `extends` other base interfaces where a real hierarchy exists (`Account extends Principal`);
  keep chains shallow.
- `description` is required; add `viewProperties` for the columns a human would want.
- Add a `links: models:` block when matching segment/compliance-feature codes exist (see above).

### Blast radius of touching base

Every schema package (and every collector) depends on base, so:

- **Additive changes are cheap.** A new interface, property, or field is a normal patch-bumped
  publish; dependents track base via `latest` and pick it up on their next load.
- **Never rename or remove a published artifact.** Class ownership is registered platform-side;
  renaming requires manual ownership transfer coordinated with the platform team, and the
  source-of-truth soft-delete (above) means a rename silently deletes the old name. Deprecate via
  `deprecated.yml` and add the new name instead.
- **Never redefine a published field's type** or rewrite enum values in place — collected data
  already conforms to them.
- **Version bumps are CI's job** (single-writer on main). No manual bumps in the PR.

### Targeting an interface from a collector or concrete class

Concrete classes target interfaces through `extends` (multiple inheritance supported — base
interface + vendor mixin). Collectors declare the interface they emit and stamp each object with a
discriminator field (e.g. `principalType`) that routes it into the interface's dynamic class until
a concrete class exists.

## Validation

> **Always gate your package before pushing** — `cd` into it and run `zbb gate` (see
> [Per-package validation](#per-package-validation)). Do not invoke `./gradlew` directly.
> Local file-checks alone are not enough — schema correctness (class extends chains, field references, link bidirectionality, enum format, etc.) is only enforced by the dataloader. `gate` runs the local validator, and runs the dataloader against an ephemeral Neon branch **provided `ZB_TOKEN` is set** — without it that step is silently skipped. See **[CONTRIBUTING.md](CONTRIBUTING.md)** for the full validation workflow — required reading for third-party contributors working from a fork.

### Validator (in repo)

`build.gradle.kts` defines a per-package `contentValidator` that checks the things the dataloader cannot or does not:

- `catalog.yml`, `package.json`, and `.npmrc` exist at the schema root.
- At least one of `{classes, interfaces, fields, enums, documents}` contains a `.yml` definition (skipped for `zerobias.deprecated: true` packages).
- **Filesystem ↔ npm ↔ zerobias-block triangulation**: `package.json` `name` and `zerobias.package` match the directory layout. For umbrella schemas (directories ending in `/schema`), the trailing segment is dropped before deriving the expected names.

The repo-wide `:validateUniquePackageNames` task fails if two schemas share the same `zerobias.package` block name.

### Gate (full validation)

`zbb gate` (from inside the package) runs the full pipeline:

1. `validateContent` — the per-package validator above.
2. `:validateUniquePackageNames` — repo-wide cross-cut.
3. `testDataloader` — loads the schema into an ephemeral Neon branch via the remote dataloader service and validates everything the dataloader checks (extends chains, link bidirectionality, enum format, viewProperties, etc.). **Skipped (not failed) when `ZB_TOKEN` is unset or blank**; CI runs it on every push.
4. `writeGateStamp` — writes `gate-stamp.json`, recording each step's status (`passed` / `skipped` / `up-to-date` / …). **`publishGuard` rejects packages without a committed, valid stamp.**

To confirm the dataloader actually ran, check the stamp: `"testDataloader": "passed"` means it ran,
`"skipped"` means it did not. Verify the stamp with `zbb gateCheck` (cheap — no build or vault
needed).

### Package Naming
- npm name: `@zerobias-org/schema-{parts joined with -}` (e.g. `@zerobias-org/schema-hl7-fhir`, `@zerobias-org/schema-zerobias-zerobias-base`).
- `zerobias.package` block: `{parts joined with .}.schema` (e.g. `hl7.fhir.schema`, `zerobias.zerobias.base.schema`).
- For umbrella schemas (`package/{vendor}/{product}/schema/`), the trailing `schema/` is dropped from the npm name; the block uses `{parent}.schema`.

## Creating a new schema package

Say "add a schema for X" / "add an interface for Y" (or run `/create-schema`) —
the [create-schema skill](.claude/skills/create-schema/SKILL.md) handles the
whole org-first flow, for vendor schema packages AND base-interface additions;
a ZeroBias task id is optional.

Hard prerequisites live in the
[`prerequisites` skill](.claude/skills/prerequisites/SKILL.md) — run
`/prerequisites` to pre-flight the repo (tools, MCPs, credentials — the API
key must be an **org owner** key; member keys can't load artifacts to the
org). If one is missing: **install it or wait — never work around it** (no
substitute tooling, no alternative paths).

The content SDLC (the skill owns the details — don't restate them here):

1. scaffold → author → `zbb --slot <slot> gate` (never bare `./gradlew`) → commit `gate-stamp.json`
2. `publishOrg` (org-private rc `X.Y.Z-rc.<orgId>.<n>` + org dataloader load) → verify in YOUR org → 🙋 explicit user sign-off
3. only then PR → base **`main`**

**No ZeroBias org?** (external contributors): stop after the gate and open the
PR against `main` — maintainers run the org verification on their side. See
[CONTRIBUTING.md](CONTRIBUTING.md).

One-time credential setup (all credential homes, check-first):
`./scripts/setup-org-credentials.sh` — run it yourself in a normal terminal;
`--launch` starts Claude Code through your zbb slot (the session and its MCPs
use the slot's identity).

### Scaffolding by hand

1. Create the directory: `mkdir -p package/{vendor}/{code}` (or `package/{vendor}/{group}/{code}`).
2. Run the scaffolder — the path is repo-root-relative and **must include the `package/` prefix**:
   ```bash
   scripts/createNewSchema.sh package/{vendor}/{code}
   ```
   It copies `templates/catalog.yml` + `templates/package.json` + the repo-root `.npmrc`,
   substitutes the `{dashed}`/`{dotted}`/`{path}` placeholders from the path, and **writes the
   `build.gradle.kts` marker itself** — no manual marker step. New packages start at version
   **`1.0.0`**; CI owns every bump after that.
3. Fill the remaining placeholders by hand: `{name}` and `{description}` in `catalog.yml` and
   `package.json` (and add the product dependency — see [Dependencies](#dependencies)).
4. Define schema content under `classes/`, `interfaces/`, `fields/`, `enums/`, `documents/`.
5. `cd package/{vendor}/{code}` and run `zbb gate`, then commit the generated `gate-stamp.json`.
   (Not `./gradlew` — see [Per-package validation](#per-package-validation).)

### Dependencies

The scaffolded `package.json` already depends on (both tracked as `latest`):

- `@zerobias-com/schema-zerobias-zerobias-platform` — platform schema (`Object`, `File`, `Element`, …).
- `@zerobias-org/schema-zerobias-zerobias-base` — the base interfaces/classes.

Add yourself, once the catalog product exists (it should — schemas hang off a product):

- `@zerobias-org/product-{vendor}-{code}` — your product package.

`zerobias.imports` (already in the template; both are also implicit dataloader imports, but declare
them so the dependency graph is explicit):

- `"zerobias.zerobias.platform.schema"`
- `"zerobias.zerobias.base.schema"`

### `.npmrc`

The scaffolder copies the repo-root `.npmrc` into the package — do not hand-edit the copy, and do
not substitute a different registry config. Auth comes from the environment (`ZB_TOKEN` for
`pkg.zerobias.org`; the slot provides it).

## Commit and Versioning
- Follow Conventional Commits: `<type>(<scope>): <subject>`
- Types: feat, fix, docs, style, refactor, perf, test, chore
- Versioning is gradle-driven: `zbb version` → `versionStandardPackages`, which bumps each changed
  package's `package.json` and commits as `chore(release): <pkg> vX.Y.Z`. Single-writer, `main` only.
- Changelogs are **not** generated. The `CHANGELOG.md` files still present in some packages are
  legacy artifacts and are no longer updated by the release flow.
- No manual version bumps in pull requests

## Branches

- `main` — default, **all PRs target it**
- `dev`, `qa`, `uat` — environment branches kept in sync by the publish workflow after every
  successful main publish (`publish.yml` dispatches `sync-env-branches.yml`). Never PR against them.

## Authentication
- Set `ZB_TOKEN` environment variable for NPM registry authentication (the slot provides it — see
  [Sessions, credentials & MCPs](#sessions-credentials--mcps--slot-first))
- Packages publish to the ZeroBias Package Registry: `https://pkg.zerobias.org/`

---

## ZeroBias Task Integration (optional)

Task-driven mode is **optional** — `/create-schema` works with or without a platform task id.
When a ZeroBias task does drive the work:

```
/create-schema [task-id]
```

See **[.claude/skills/create-schema/SKILL.md](.claude/skills/create-schema/SKILL.md)** for the complete workflow.

**Dependency chains:**
```
Standards workflow:  vendor → [suite] → [product] → framework/standard/benchmark → crosswalk
Data workflow:       vendor → [suite] → [product] → schema → collectorbot → pipeline
```

Schemas are on the data workflow. Vendor is required; suite and product are optional (but the
product dependency should exist — see [Dependencies](#dependencies)). Check/create dependencies first.

### Key APIs

```javascript
// Check dependencies exist (REQUIRED before schema)
zerobias_execute("portal.Vendor.search", { searchVendorBody: { search: "vendor" }})
zerobias_execute("portal.Product.search", { searchProductBody: { search: "vendor product" }})

// Get your party ID for assignment
zerobias_execute("platform.Party.getMyParty", {})

// Transition task to in_progress (use transitionId, NOT status)
zerobias_execute("platform.Task.update", {
  id: taskId,
  updateTask: {
    assigned: partyId,
    transitionId: "7f140bbe-4c10-54ac-922c-460c66392fad"
  }
})
```

### Workflow Transitions

| Transition | Target Status | ID |
|------------|---------------|-----|
| Start | in_progress | `7f140bbe-4c10-54ac-922c-460c66392fad` |
| Peer Review | awaiting_approval | `f017a447-0994-594d-9417-39cbc9a4de88` |
| Accept | released | `1d2e9381-f609-5e26-8bc6-7bbb65a9048d` |

**Note:** Always get actual IDs from `task.nextTransitions`.

---

## Naming Rules (CRITICAL)

The `{vendor}` and `{code}` segments must be **identical** across all identifiers. The gate's
validator enforces this automatically.

```
npm package:   @zerobias-org/schema-{vendor}-{code}
catalog.yml:   {vendor}.{code}.schema
directory:     package/{vendor}/{code}/
product dep:   @zerobias-org/product-{vendor}-{code}
zb.package:    {vendor}.{code}.schema
```

**Rules:**
- `{vendor}` and `{code}` must match `^[a-z0-9]+$` — **lowercase alphanumeric only. No hyphens, no underscores, no dots.** This matches the ZB platform UI's `vspCodeValidator` constraint on product/vendor/suite codes. The API does not enforce this server-side, but the ecosystem (catalog package names, dataloader artifact resolution) requires it.
- **NEVER rename** a published schema package without coordinating with the platform team (Chris/Kevin). Renaming after classes are registered requires manual ownership transfer on the platform side. The dataloader cannot automatically reassign class ownership between packages.
- Enum values **MUST be ALL_CAPS** matching `[A-Z][A-Z0-9_]*`. The dataloader enforces this — lowercase values fail at load time.

## Important Notes
- `npm install` at the repo root only refreshes the lockfile for the commitlint dev deps. Commitlint
  is configured (`.commitlintrc.json`), but there is no `.husky/` directory and no `prepare` script,
  so **nothing enforces commit-message format locally** — follow the convention by hand.
- **All PRs target `main`** — `dev`/`qa`/`uat` are synced environment branches (see [Branches](#branches)), not PR bases.
- Versions are managed by gradle (`zbb version`), not by hand. New packages scaffold at `1.0.0`;
  packages migrated from the old lerna flow took a major bump on their first gradle publish, so
  live versions are `2.x` / `3.x`.
- The gate — not an npm script — is what ensures schema integrity before publication
- Schema packages use the `zerobias` config key (dataloader supports both `zerobias` and `auditmation`)
- Extending `Element` base class enables framework linking without schema changes

## Related Documentation
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — the two contribution lanes (with/without a ZeroBias org)
- **[.claude/skills/create-schema/SKILL.md](.claude/skills/create-schema/SKILL.md)** — full schema SDLC walkthrough (org-first)
- **[.claude/skills/prerequisites/SKILL.md](.claude/skills/prerequisites/SKILL.md)** — pre-flight for tools/MCPs/credentials
- **[zerobias-org/product](https://github.com/zerobias-org/product)** — product repo (the parent dependency); sibling on the same gradle pipeline
- **[zerobias-org/collectorbot](https://github.com/zerobias-org/collectorbot)** — ETL that emits objects conforming to these schemas
- **[zerobias-org/zerobias](https://github.com/zerobias-org/zerobias)** — open-source meta-repo (cross-repo concepts, MCP setup, architecture)

---

## Sessions, credentials & MCPs — slot-first

<!-- Synced section: identical in vendor, suite, product, module, schema.
     The zerobias meta-repo's CLAUDE.md carries the same rules in its
     own words. Edit in one repo, copy to all. -->

All org credentials (platform ORG key, registry key, org/env identity)
live in a **zbb slot**; Claude Code sessions are launched THROUGH the
slot so the committed `.mcp.json` templates (`${VAR}` refs — no
secrets) and the zb `env` profile resolve that identity.

- **One-time setup (per org/env):** the user runs
  `./scripts/setup-org-credentials.sh` themselves in a normal terminal
  (never inside a Claude session). Check-first and re-runnable: it
  creates the slot (`<env>-<org-prefix>`), stores the keys, and wires
  `~/.npmrc` + the zb profile.
- **Launch:** `./scripts/setup-org-credentials.sh --launch [args…]`,
  or `zbb --slot <slot> --stack <stack> exec claude` from anywhere
  (`<stack>` = this repo's `zbb.yaml` `name:` short form, i.e.
  `schema` here); from this repo's root plain
  `zbb --slot <slot> exec claude` works too (cwd infers the stack).
  NEVER launch stackless from outside a `zbb.yaml` directory: a slot
  holds NO user vars of its own (only `ZB_SLOT*` identity) — every
  credential is **stack-scoped**, and lives ONCE per slot on the
  shared `dev` stack (`@zerobias-org/dev-stack`); this repo's stack
  imports it (see `zbb.yaml` depends/imports), so the setup script
  seeds only the dev stack and every content stack resolves the same
  creds transitively. Never `env set` those vars on a content stack —
  a per-stack override shadows the import and rotation stops
  propagating there. `zbb --slot <slot> --stack dev exec claude`
  launches a creds-only session from anywhere (MCPs work; repo gates
  still need the repo's own stack). Add `--continue` to resume the
  previous session under another slot (sessions are keyed by cwd,
  not by slot).
- **Missing MCP tools / 401 / `MISSING_ENV_VAR` / `NOT SET`** means
  the session wasn't launched through a slot WITH a stack context.
  Check inside the session: `echo ${ZB_SLOT:-no-slot} ${ZB_ORG_ID:-no-stack}`
  (`no-slot` = not launched through zbb; `no-stack` = launched
  stackless). Fix the launch — exit and relaunch; `/mcp` reconnect can
  never pick up new env (it is captured once at claude startup). Do NOT
  register MCPs with pasted literal keys (a baked key silently
  overrides every slot identity, connecting as the wrong org) and do
  NOT export creds into the session as a workaround.
- **Multi-org / multi-env = one slot each**, chosen at launch time;
  switching identity means restarting claude through the other slot
  (env is read once at startup). A second IDENTITY (another API key)
  for the same org gets its own named slot too — a preset `SLOT` skips
  the reuse-by-content scan:
  `SLOT=<name> ZB_API_KEY=<other-key> ./scripts/setup-org-credentials.sh`.
  With several slots holding one org, always pass `--slot` explicitly —
  the auto-reuse scan just takes the first match.

Deep dive: the meta-repo's
[docs/MCPs.md](https://github.com/zerobias-org/zerobias/blob/main/docs/MCPs.md).

## GitHub token — `read:packages` (required for EVERY zbb/gradle command)

This repo resolves its gradle plugins (`zb.workspace`, `zb.base`,
`zb.content`) from **GitHub Packages Maven**, so the token gates the whole
zbb toolchain — compile, validation, tests, `gate`, publish — not one task.

`com.zerobias.build-tools` is a **public** package, but GitHub Packages Maven
refuses **anonymous** reads. This is a registry requirement, not a permission
one: nothing has to be granted to anyone and no org membership is involved.
Any GitHub account whose token carries `read:packages` can read it.

**Being logged in to `gh` is NOT enough — the scope is separate, and an
authenticated-but-unscoped token is the usual false pass.** Assert the scope,
not the login:

```bash
gh auth status 2>&1 | grep -q 'read:packages' && echo OK || echo 'MISSING read:packages'
gh auth refresh -s read:packages && export GITHUB_TOKEN=$(gh auth token)   # the fix
```

Definitive check — proves the read (200 = ready, 401 = scope missing):

```bash
curl -s -o /dev/null -w '%{http_code}\n' -u "x:$(gh auth token)" \
  https://maven.pkg.github.com/zerobias-org/util/zb/workspace/zb.workspace.gradle.plugin/maven-metadata.xml
```

**Agent rule — do not report this as a blocker.** A 401 from
`maven.pkg.github.com`, `Plugin [id: 'zb.workspace'] was not found`, or
`Could not resolve com.zerobias.build-tools` is a KNOWN, SELF-FIXABLE state.
It lands on the very first request (plugins pin `1.+`, so `maven-metadata.xml`
is fetched before any package file is read). Run the refresh above and retry.
Never present it as an environment limitation, never silently downgrade to
`validateContent`-only, and never write "validation deferred to CI" — a
package whose gate never ran cannot publish.

⚠ Machines that have run `publishToMavenLocal` on build-tools are silently
exempt (`mavenLocal()` is first in the resolution order). Clean, CI and
container environments have no `~/.m2` and always need the scope — never
conclude it is unnecessary because a developer machine worked. An INVALID
`GITHUB_TOKEN` also silently shadows a valid keyring login (`gh auth status`
exposes it).

## Windows — WSL2 only

Everything here runs only on Ubuntu (`zbb` fails on native Windows).
On Windows, work inside WSL2 end-to-end — user walkthrough:
[docs/WindowsWSLSetup.md](https://github.com/zerobias-org/zerobias/blob/main/docs/WindowsWSLSetup.md).

- **If this session runs on NATIVE Windows** (prompt `PS C:\`, paths
  under `C:\` or `/mnt/c/...`): your ONLY job is getting WSL2 + Ubuntu
  installed. Refuse repo work — no cloning, editing, git, or builds —
  and point the user to their WSL session. Never relay work between a
  Windows agent and a WSL agent.
- **In WSL:** logins and credential setup happen in the Ubuntu
  terminal (`gh auth login`, claude's first-run login,
  `setup-org-credentials.sh`). Once setup is green, offer Remote
  Control (`/remote-control`, or `--launch --remote-control`) to
  continue from the Claude desktop / mobile app.
