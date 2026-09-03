# `@zerobias-org/schema`

Open-source AuditgraphDB schema packages for the ZeroBias platform.

This monorepo hosts schema definitions (classes, interfaces, fields, documents, enums) that are published to npm and loaded into AuditgraphDB by the dataloader. All PRs target **`main`** (`dev`/`qa`/`uat` are environment branches synced automatically after each main publish).

- **Build pipeline:** gradle + [`zbb-publish-reusable`](https://github.com/zerobias-org/devops/blob/main/.github/workflows/zbb-publish-reusable.yml) (no lerna / no nx)
- **Per-package plugin:** [`zb.schema`](https://github.com/zerobias-org/util/blob/main/packages/build-tools/src/main/kotlin/zb.schema.gradle.kts) — extends `zb.content` with TS-twin generation against an ephemeral Neon Postgres branch
- **Third-party contributors:** start with [`CONTRIBUTING.md`](CONTRIBUTING.md). It covers both contribution lanes — fork-only, and org-first for ZeroBias platform users.

## Org-first: generate schemas for your own org

You don't need a PR to use this repo. Customers generating their own schemas fork it, author a
package, run the gate, and load it into **their own org** with `zbb publishOrg` — which publishes an
org-private rc (`X.Y.Z-rc.<orgId>.<n>`) and queues an org dataloader load, visible only to that org.
Opening a PR afterwards is how you *share* the schema with everyone else — optional for org-internal
models, encouraged for anything generic. The `/create-schema` skill drives the whole flow; see
[`CONTRIBUTING.md`](CONTRIBUTING.md) (Lane 2) and [`CLAUDE.md`](CLAUDE.md).

**Base-interface PRs are welcome.** The base schema
([`package/zerobias/zerobias/base`](package/zerobias/zerobias/base)) is deliberately
interface-heavy — collectors target its interfaces, and the platform materializes dynamic concrete
classes at ingest. If a generic concept is missing (an audit-log entry, a pipeline run, …), the
right move is to add a new interface to base and PR it to `main` — see
[`CLAUDE.md` → Extending the base schema](CLAUDE.md#extending-the-base-schema--interfaces-first).

## Local development

Build and validation go through **`zbb`**, the ZeroBias build CLI
([`zerobias-org/util`](https://github.com/zerobias-org/util/tree/main/packages/zbb), `packages/zbb`):

```bash
npm i -g @zerobias-org/zbb

# First time on a machine — lifecycle commands need a loaded slot
zbb slot create local     # allocates ports, pulls env/secrets from every zbb.yaml
zbb slot load local       # preflight checks, then a subshell with slot env loaded
```

`zbb slot load` drops you into a subshell (`[zb:local]:path$`); run everything below from inside it.
Without a loaded slot, `zbb gate` exits with `Not inside a loaded slot. Run: zbb slot load <name>`.
Schema is a content repo with no long-running services, so no stack needs starting.

**Use `zbb`, not `./gradlew` directly.** `zbb` pins the JDK toolchain to Java 21; a bare `./gradlew`
uses whatever JDK is on `PATH`, and on JDK 25 Gradle 8.10.2 aborts with an opaque `25.0.2` and
nothing else. That failure means `zbb` was bypassed — not that you need a different JDK.

```bash
# Validate + write gate stamp for a single schema.
# zbb detects the subproject from cwd and prefixes the task for you.
cd package/hl7/fhir && zbb gate

# Or address it explicitly from the repo root:
zbb :{vendor}:{code}:gate           # depth 2 (e.g. :hl7:fhir)
zbb :{vendor}:{group}:{code}:gate   # depth 3 (e.g. :zerobias:zerobias:base)

# Cheap stamp check — no build, no vault
zbb gateCheck

# Cross-cut: ensure no two schemas share a zerobias.package block name
zbb validateUniquePackageNames

# Whole-repo (matches CI) — note this rewrites every gate-stamp.json
zbb gate
zbb publish

# Org-first SDLC: org-private rc publish + org dataloader load
zbb publishOrg
```

The gate's `testDataloader` step loads the schema into an ephemeral Neon branch via the remote
dataloader service (`DATALOADER_SERVICE_URL`, default `https://app.zerobias.com/api/dataloader`),
authenticated by **`ZB_TOKEN`**. No local Neon credentials are needed. If `ZB_TOKEN` is unset or
blank the step is **skipped (not failed)** and the stamp is still written — it records
`"testDataloader": "skipped"` rather than `"passed"`, so check that field before trusting a green
gate. CI runs the full gate on push.

## Adding a new schema

```bash
mkdir -p package/{vendor}/{code}

# Scaffolds templates + .npmrc, substitutes {dashed}/{dotted}/{path},
# and writes the build.gradle.kts marker itself. Versions start at 1.0.0.
./scripts/createNewSchema.sh package/{vendor}/{code}

# Fill {name} / {description} in catalog.yml + package.json, author definitions, then:
cd package/{vendor}/{code} && zbb gate   # writes gate-stamp.json — commit it
```

A new schema's `package.json` ships with `@zerobias-org/schema-zerobias-zerobias-base` +
`@zerobias-com/schema-zerobias-zerobias-platform` (`latest`) and
`zerobias.imports: ["zerobias.zerobias.platform.schema", "zerobias.zerobias.base.schema"]`; add your
`@zerobias-org/product-{vendor}-{code}` dependency. See [`CLAUDE.md`](CLAUDE.md) for the full
definition reference.

## Layout

```
package/{vendor}/{code}/                # depth 2 (leaf)
package/{vendor}/{group}/{code}/        # depth 3 (leaf)
package/{vendor}/{code}/schema/         # umbrella over {vendor}.{code}
                                        # (npm name omits trailing "-schema";
                                        # validator recognises the convention)
```

## See also

- [`CLAUDE.md`](CLAUDE.md) — operational playbook + schema definition reference.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — the two contribution lanes (fork-only / org-first).
- `bundle/package.json` — `@zerobias-org/schema-bundle`, lists every published schema as a dep; auto-refreshed by the publish workflow.
- `zbb.yaml` — lifecycle map between zbb commands and gradle tasks.

## Prerequisites — GitHub token with `read:packages`

Required before **any** gradle / `zbb` command (compile, validation, tests,
`gate`, publish): the `zb.*` gradle plugins resolve from GitHub Packages
Maven, which refuses anonymous reads even though `com.zerobias.build-tools`
is public. Nothing needs granting to you and no org membership is involved —
but **being logged in to `gh` is not enough, the scope is separate**:

```bash
gh auth status 2>&1 | grep -q 'read:packages' && echo OK || echo 'MISSING read:packages'
gh auth refresh -s read:packages && export GITHUB_TOKEN=$(gh auth token)   # the fix
```

Without it the build fails on its first request with a 401 /
`Plugin [id: 'zb.workspace'] was not found`, before any package file is read.
See `CLAUDE.md` for the full note.
