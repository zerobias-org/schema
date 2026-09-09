# Base Schema for the ZeroBias Platform

`@zerobias-org/schema-zerobias-zerobias-base` (`zerobias.zerobias.base.schema`) — the canonical
base schema every other schema package builds on.

The base is **interface-heavy by design**: 130+ interfaces (`Account`, `Asset`, `Repository`,
`Application`, `Backup`, `PhysicalSpace`, …) and only a handful of concrete classes. Vendor
packages give those interfaces concrete classes — a `WizUser extends User` — and the interfaces give
the vendor data its generic meaning to every base-level consumer.

**Nobody edits this package in a contribution PR.** What base lacks (an interface, a property, a
link) is declared in the vendor package as a `<Vendor><Base>Base` interface that `extends` the base
one; concrete classes extend that; links toward base types are `uniLink` only. zb owners decide at PR
review whether to promote it into base and make that change themselves. See
[`CLAUDE.md` → Extending the base schema](../../../../CLAUDE.md#extending-the-base-schema--extend-it-in-your-package-never-edit-it).

## Conventions

- Every definition file starts with `id:` — classes and interfaces `UUIDv5(NIL, Name)`, fields a
  UUIDv4 minted once, enums and documents `id` + `fieldId`, both UUIDv4. Ids are permanent.
- Additive changes only: never remove or rename a published interface, class or field (retire via
  `deprecated.yml`), never redefine a published field's type, never rewrite enum values in place.
- Enum values are `ALL_CAPS`; links are two-way unless the other side cannot know about this one
  (`uniLink: true`); a link attribute is a `t3:` document or field declared on one side.
