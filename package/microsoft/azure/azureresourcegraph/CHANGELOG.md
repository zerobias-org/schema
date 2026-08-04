# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 1.0.0 (2026-08-04)

Initial release. Product schema for `microsoft.azure.azureresourcegraph`,
mirroring the `@auditlogic/schema-amazon-aws-rexplorer` precedent: three
extends-only classes (`AzureResourceGraph`, `AzureResourceGraphResource`,
`AzureResourceGraphResourceType`) with no declared properties. The root
class's second `extends` entry (an `AzureService` equivalent) is pending a
suite-schema decision tracked upstream.
