# create-schema — file templates

Exact file shapes for a schema package. The scaffolder
(`scripts/createNewSchema.sh package/<vendor>/[<group>/]<code>`) produces
the first four from `templates/`, substituting the path-derived
`{dashed}`/`{dotted}`/`{path}` placeholders and writing the gradle marker;
you fill `{name}` / `{description}`. The definition-file shapes below are
the quick reference — the full authoring rules (link catalog, per-artifact
constraints, viewProperties, validation errors) live in the repo
[CLAUDE.md](../../../CLAUDE.md) Schema Definition Reference.

## package.json

```jsonc
{
  "name": "@zerobias-org/schema-<v>-<c>",       // dash-joined path segments
  "version": "1.0.0",                            // start; CI owns all bumps
  "description": "<Human Name>",
  "author": "team@zerobias.com",
  "license": "ISC",
  "type": "module",
  "repository": {
    "type": "git",
    "url": "git@github.com:zerobias-org/schema.git",
    "directory": "package/<v>/<c>/"
  },
  "publishConfig": { "registry": "https://npm.pkg.github.com/" },
  "files": [
    "classes/**", "interfaces/**", "fields/**", "documents/**", "enums/**",
    "catalog.yml", "README.md"
  ],
  "dependencies": {
    "@zerobias-com/schema-zerobias-zerobias-platform": "latest",
    "@zerobias-org/schema-zerobias-zerobias-base": "latest",
    "@zerobias-org/product-<v>-<c>": "latest"    // the catalog entry this
                                                 // schema describes (suite
                                                 // pkg for umbrella schemas)
  },
  "zerobias": {
    "dataloader-version": "1.0.0",
    "import-artifact": "schema",
    "package": "<v>.<c>.schema",                 // dot-joined path + .schema
    "imports": [
      "zerobias.zerobias.platform.schema",
      "zerobias.zerobias.base.schema"
    ]
    // + "orgId": "<target-org-uuid>" during the org-first flow (Phase 3);
    //   DELETED again before the PR (Phase 7)
  }
}
```

No `scripts` block — gradle owns the lifecycle. Never add `nx:*` /
`validate` / `correct:deps` entries (lerna-era, removed).

## catalog.yml

```yaml
Schema:
  name: "<Human Name>"
  package: "<v>.<c>.schema"
  description: |-
    <one-paragraph description>
```

## build.gradle.kts (the discovery marker — scaffolder writes it)

```kotlin
plugins { id("zb.schema") }
```

## .npmrc (copied from repo root by the scaffolder)

```
@auditlogic:registry=https://pkg.zerobias.org
@zerobias-org:registry=https://pkg.zerobias.org
@zerobias-com:registry=https://pkg.zerobias.org
//pkg.zerobias.org/:always-auth=true
//pkg.zerobias.org/:_authToken=${ZB_TOKEN}
```

## Definition files — quick shapes

Note the property list's YAML quirk: each entry is a single-key null map
(`- name:`) whose SIBLING keys carry the config. Copy a real neighbor
rather than typing from memory.

**Every file starts with `id:`** (enums/documents also `fieldId:`) — the
dataloader refuses files without one. See [Generating ids](#generating-ids).

### interfaces/<Name>.yml (PascalCase)

```yaml
id: 8f5b80d9-3429-5069-84d2-db188c6797d6   # UUIDv5(NIL, "Commit") — deterministic from the name
description: A single revision in a source-control repository
extends:
  - Component
properties:
  - sha:
    field: scm.sha
  - committed:
    field: timeCreated
  - repo:
    linkTo: Repository
    required: true
viewProperties:
  "SHA":
    jsonata: sha
    sort: sha
```

### classes/<Name>.yml (PascalCase — concrete, extends interfaces)

```yaml
id: b746fd06-5b16-5feb-bdcd-62a48b50bafc   # UUIDv5(NIL, "GitHubRepository")
description: Describes a GitHub Repository
extends:
  - Repository        # base interface — what collectors target
  - GitHubObject      # package-local interface for shared vendor props
properties:
  - fullName:
    field: repository.fullName
viewProperties:
  "Name":
    jsonata: name
    sort: name
```

### fields/<prefix>.<name>.yml (camelCase dot-notation)

```yaml
id: 413a401d-2a82-4f40-90b3-846b87dd75d2   # UUIDv4 — mint once, never copy
description: 'The full name of the repository (owner/name)'
displayName: 'Full Name'
type: string          # string|boolean|number|integer|date|datetime
```

Reuse order: an existing base field → a new package field → only then a
new base field (Mode B). Check `package/zerobias/zerobias/base/fields/`
before minting anything.

### enums/<prefix>.<name>.yml — values MUST be ALL_CAPS

```yaml
id: 503dc9ff-df6e-42c2-a0e7-33235bb098f6        # UUIDv4 — the data type
fieldId: c21df330-e4f0-4210-888d-2dc3bf01d525   # UUIDv4 — the backing field
description: The level of privacy this team should have.
displayName: Privacy
values:
  - SECRET: 'Only visible to organization owners and members of this team.'
  - CLOSED: 'Visible to all members of this organization.'
```

### documents/<prefix>.<name>.yml (compound type)

```yaml
id: 33d7fd18-41ca-44c2-acca-dff724ed55a2        # UUIDv4 — the data type
fieldId: 44fa56f7-5d44-4aa4-bff1-6a599ca620fd   # UUIDv4 — the backing field
description: "Organization billing plan"
displayName: "Plan"
properties:
  - company:
    field:
      type: string
```

## Generating ids

| File kind | Scheme | One-liner |
|---|---|---|
| `classes/`, `interfaces/` | **UUIDv5 with the NIL namespace and the name** — the dataloader's own derivation, so it is reproducible (`Account` → `1a32e499-4e51-5bae-9e39-70f6c2e4184a`) | `python3 -c 'import uuid,sys;print(uuid.uuid5(uuid.UUID(int=0),sys.argv[1]))' <Name>` |
| `fields/` | UUIDv4, minted once | `python3 -c 'import uuid;print(uuid.uuid4())'` |
| `enums/`, `documents/` | `id` (data type) **and** `fieldId` (backing field), both UUIDv4 | same v4 one-liner, twice |

Sanity check for a class/interface id you were handed:
`python3 -c 'import uuid;print(uuid.uuid5(uuid.UUID(int=0),"Account"))'`
must print the id in `package/zerobias/zerobias/base/interfaces/Account.yml`.

Rules: ids are permanent — never change one after publish, never mint a
second one for a name that already exists (the load refuses the mismatch),
and never copy an id from another file. macOS `uuidgen` cannot do v5; the
python one-liners work on macOS and Ubuntu alike.

## Naming triangulation (the gate enforces this)

```
directory:        package/<v>/[<g>/]<c>/
npm name:         @zerobias-org/schema-<v>[-<g>]-<c>
zerobias.package: <v>[.<g>].<c>.schema
```

Segments: `^[a-z0-9]+$` only. Umbrella schemas (`…/schema/` directory):
the trailing segment is dropped from the npm name; the block is
`<parent>.schema`. **Never rename** any of these after publish.
