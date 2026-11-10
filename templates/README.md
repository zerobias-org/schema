# {name} Schema

{description}

Published as `@zerobias-org/schema-{dashed}` (catalog package `{dotted}.schema`);
TypeScript twin `@zerobias-org/schema-{dashed}-ts`.

## Classes

| Class | Extends | What it is |
|---|---|---|
| `<Vendor>Thing` | `<BaseInterface>` | one line |

## Package interfaces (what base lacks, declared here)

| Interface | Extends | Adds | Promotion candidate? |
|---|---|---|---|
| `<Vendor><Base>Base` | `<Base>` | property / link | yes / no — why |

## Links

| From | To | Cardinality | T3 |
|---|---|---|---|

## Decisions

- **Sources:** which module `api.yml` / collector / vendor API reference the shapes come from.
- **Parents:** why each class extends the interface it does; what else was considered.
- **Base gaps:** each `<Vendor><Base>Base` interface and the property/link it carries.
- **Enums:** where the complete value lists come from.
