# @zerobias-org/schema-microsoft-azure-azureresourcegraph

AuditgraphDB schema for the `microsoft.azure.azureresourcegraph` product —
concrete classes for the rows the Azure Resource Graph collectorbot emits.

| Class | Extends | ARG source |
|---|---|---|
| `AzureResourceGraph` | `AzureResourceManagement` | the connection's application root (one per Azure AD tenant) |
| `AzureResourceGraphResource` | `AzureInventoryItem` | `Resources` table rows (`listResources`) |
| `AzureResourceGraphSubscription` | `AzureSubscription` | `ResourceContainers` rows of type `microsoft.resources/subscriptions` |
| `AzureResourceGraphResourceGroup` | `AzureResourceGroup` | `ResourceContainers` rows of type `microsoft.resources/subscriptions/resourcegroups` |
| `AzureResourceGraphManagementGroup` | — | `ResourceContainers` rows of type `microsoft.management/managementgroups` |

The ARG `type` column lands on the inherited `assetType` property
(`field: asset.type` via `InventoryItem`); subscription / resource group /
provider / resource type relationships land on the link properties inherited
from `AzureInventoryItem`. Product-level additions are deliberately small:
`region` (base `cloud.region`), `kind` and `managedBy`.

Deliberate v1 scope cuts (enrich later if wanted): `sku`, `plan`, `identity`,
`zones` and the per-type `properties` bag are collected by the module but not
yet modelled; `AzureResourceGraphManagementGroup` carries no links because its
natural link targets (subscriptions, tenant) belong to the suite schema, which
is a verbatim port — adding a management-group concept there is a suite-level
decision.
