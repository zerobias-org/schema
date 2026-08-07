# @zerobias-org/schema-microsoft-azure-azureresourcegraph

AuditgraphDB schema for the `microsoft.azure.azureresourcegraph` product —
concrete classes for the rows the Azure Resource Graph collectorbot emits.

Depends on the published Azure suite schema
(`@auditlogic/schema-microsoft-azure`, block `microsoft.azure.schema`) for its
link targets. Note the dataloader resolves `extends` against **interfaces
only**, so these classes extend base interfaces directly and declare their
suite-class links locally (uniLink — the suite package cannot grow reverse
links from here).

| Class | Extends | Links to suite | ARG source |
|---|---|---|---|
| `AzureResourceGraph` | `InventoryApplication` | `tenant → AzureTenant` | the connection's application root (one per Azure AD tenant) |
| `AzureResourceGraphResource` | `InventoryItem` | `subscription`, `resourceGroup`, `resourceProvider`, `resourceType` | `Resources` table rows (`listResources`) |
| `AzureResourceGraphSubscription` | `CloudService` | `tenant → AzureTenant` | `ResourceContainers` rows of type `microsoft.resources/subscriptions` |
| `AzureResourceGraphResourceGroup` | — | `subscription → AzureSubscription` | `ResourceContainers` rows of type `microsoft.resources/subscriptions/resourcegroups` |
| `AzureResourceGraphManagementGroup` | — | — | `ResourceContainers` rows of type `microsoft.management/managementgroups` |

The ARG `type` column lands on the inherited `assetType` property
(`field: asset.type` via `InventoryItem`). Product-level additions are
deliberately small: `region` (base `cloud.region`), `kind` and `managedBy`.

Deliberate v1 scope cuts (enrich later if wanted): `sku`, `plan`, `identity`,
`zones` and the per-type `properties` bag are collected by the module but not
yet modelled; `AzureResourceGraphManagementGroup` carries no links because its
natural link targets belong to the suite schema, and adding a management-group
concept there is a suite-level decision.
