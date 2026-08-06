# @zerobias-org/schema-microsoft-azure

AuditgraphDB umbrella schema for Microsoft Azure — the suite-level classes shared
by every `microsoft.azure.*` product schema (subscriptions, resource groups,
resource providers/types, tenants, and the Azure inventory-item lineage).

Ported from the proprietary `@auditlogic/schema-microsoft-azure@1.0.0` package
(`auditlogic/schema` → `package/microsoft/azure/common`), adapted to the
`zerobias-org` gradle pipeline conventions:

- suite dependency switched to `@zerobias-org/suite-microsoft-azure` (^2.0.1)
- platform/base dependencies and `zerobias.imports` follow this repo's migrated
  package shape
- `dataloader-version` 1.0.0

Class content is otherwise a verbatim port, including the `resoruceGroup` /
`resoruceGroups` property-name typos on `AzureInventoryItem` / `AzureSubscription`
— these are load-bearing (published lineage) and tracked separately upstream; do
not fix them here without platform-team coordination.
