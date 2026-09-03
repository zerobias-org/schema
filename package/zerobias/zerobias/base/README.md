# Base Schema for the ZeroBias Platform

`@zerobias-org/schema-zerobias-zerobias-base` (`zerobias.zerobias.base.schema`) — the canonical
base schema every other schema package builds on.

The base is **interface-heavy by design**: 125+ interfaces (`Account`, `Asset`, `Repository`,
`Application`, `Backup`, `Pipeline`, …) and only a handful of concrete classes (`CAPEC`,
`CapecCategory`, `CVE`, `CWE`, `DynamicBackup`, `ServiceEndpoint`, `X509Certificate`). Collectors
and modules target the **interfaces**; the platform materializes a dynamic concrete class per
interface at ingest, so data flows before any vendor-specific class exists. Vendor packages then
`extends` these interfaces when they add concrete classes.

**New generic interfaces are welcome — PR them to `main`.** If a concept any vendor could yield
(an audit-log entry, a pipeline run, a software package, …) is missing from `interfaces/`, adding
it here is the default move, not an exception. See
[`CLAUDE.md` → Extending the base schema](../../../../CLAUDE.md#extending-the-base-schema--interfaces-first)
for design guidance and blast-radius rules.

## You can

- Add new interfaces (and, rarely, concrete classes) for generic concepts
- Add properties and fields to existing interfaces
- Add documentation, `viewProperties`, and `links: models:` catalog annotations

## You cannot

- Remove or rename published interfaces, classes, or fields (deprecate via `deprecated.yml` instead)
- Redefine a published field's type
- Change existing field or enumeration values — collected data already conforms to them
