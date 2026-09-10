# Snyk Schema

AuditgraphDB schema for the Snyk developer security platform: organizations, targets,
projects, organization members and the issues Snyk reports (open source, code, container,
IaC, cloud and secrets).

Published as `@zerobias-org/schema-snyk-snyk` (catalog package `snyk.snyk.schema`);
TypeScript twin `@zerobias-org/schema-snyk-snyk-ts`.

## Classes

| Class | Extends | What it is |
|---|---|---|
| `SnykOrganization` | `Application` | The Snyk org: scope that owns targets, projects, issues and members; `slug` keyed |
| `SnykUser` | `Account` | A user as a member of one org: identity + org role + membership details |
| `SnykTarget` | `Component` | The imported thing Snyk scans (repo, image, cloud account, CLI dir) |
| `SnykProject` | `Component` | One scannable unit in a target (manifest / image / IaC set / code base) + scan settings |
| `SnykIssue` | `SnykIssueBase` | An issue reported against a project; `key` keyed |

## Package interfaces (what base lacks, declared here)

| Interface | Extends | Adds | Promotion candidate? |
|---|---|---|---|
| `SnykIssueBase` | `Finding` | `severity` (core type), `ignored`, `resolvedAt`, unilinks `cves → CVE`, `cwes → CWE` | yes — every scanner finding has a severity, a suppression flag, a resolution time and CVE/CWE references; base `Finding` has none |

## Links

| From | To | Cardinality | T3 |
|---|---|---|---|
| `SnykOrganization.members` | `SnykUser.organization` | 1 ⟷ n | — |
| `SnykOrganization.targets` | `SnykTarget.organization` | 1 ⟷ n | — |
| `SnykOrganization.projects` | `SnykProject.organization` | 1 ⟷ n | — |
| `SnykOrganization.issues` | `SnykIssue.organization` | 1 ⟷ n | — |
| `SnykTarget.projects` | `SnykProject.target` | 1 ⟷ n | — |
| `SnykProject.importer` | `SnykUser.importedProjects` (hidden) | n ⟷ 1 | — |
| `SnykProject.owner` | `SnykUser.ownedProjects` (hidden) | n ⟷ 1 | — |
| `SnykProject.issues` | `SnykIssue.project` | 1 ⟷ n | — |
| `SnykIssueBase.cves` | base `CVE` | n → n, uniLink | — |
| `SnykIssueBase.cwes` | base `CWE` | n → n, uniLink | — |

Inherited base links also apply: `SnykUser.app` ⟷ `SnykOrganization.accounts`
(`Account` ⟷ `Application`), and `SnykIssue.components` ⟷ `SnykProject.findings` /
`SnykTarget.findings` (`Finding` ⟷ `Component`).

## Field mapping (Snyk REST → schema)

| Snyk | Property |
|---|---|
| org `id` / `name` / `slug` / `is_personal` / `group_id` / `created_at` / `updated_at` | `id` / `name` / `slug` / `isPersonal` / `groupId` / `dateCreated` / `dateLastModified` |
| user `id` / `name` / `username` / `email` / `active` | `id` / `name` / `login` / `email` / `status` (`ACTIVE` / `INACTIVE`) |
| membership `role.attributes.name` / `role.id` / `created_at` / `strategy` / `login_method` | `orgRole` / `orgRoleId` / `membershipCreated` / `membershipStrategy` / `loginMethod` |
| target `id` / `display_name` / `url` / `is_private` / `created_at` / `integration.{id,attributes.integration_type}` | `id` / `name` / `url` / `isPrivate` / `dateCreated` / `integrationId`, `integrationType` |
| project `id` / `name` / `type` / `origin` / `status` / `read_only` / `target_file` / `target_reference` / `target_runtime` / `created` / `business_criticality[]` / `environment[]` / `lifecycle[]` / `tags[]` | `id` / `name` / `projectType` / `origin` / `status` / `readOnly` / `targetFile` / `targetReference` / `targetRuntime` / `dateCreated` / `businessCriticality` / `environment` / `lifecycle` / `tag` |
| project `settings.recurring_tests.frequency` / `settings.pull_requests.is_enabled` / `meta.cli_monitored_at` | `testFrequency` / `pullRequestChecksEnabled` / `cliMonitoredAt` |
| issue `id` / `key` / `key_asset` / `title` / `description` / `type` / `status` / `ignored` / `effective_severity_level` / `created_at` / `updated_at` / `tool` | `id` / `key` / `keyAsset` / `name` / `description` / `issueType` / `state` (`open→ACTIVE`, `resolved→RESOLVED`) / `ignored` / `severity` / `dateCreated` / `dateLastModified` / `tool` |
| issue `resolution.{type,resolved_at,details}` | `resolutionType` / `resolvedAt` / `resolutionDetails` |
| issue `risk.score.{value,model}` / `severities[0].{score,vector,version}` / `exploit_details.{maturity_levels[].level,sources}` | `riskScore`, `riskScoreModel` / `cvssScore`, `cvssVectorString`, `cvssVersion` / `exploitMaturity`, `exploitSources` |
| issue `coordinates[].{reachability,is_*,last_introduced_at}` / `representations[].dependency.package_name` / `representations[].{sourceLocation.file,resourcePath}` | `reachability`, `isUpgradeable`…`isFixableUpstream`, `lastIntroducedAt` / `packageName` / `filePath` |
| issue `problems[]` where `source = CVE` / `classes[]` where `source = CWE` / `relationships.ignore.data.id` | `cves` / `cwes` / `ignoreId` |
| issue `relationships.organization` / `relationships.scan_item` (type `project`) | `organization` / `project` |

## Decisions

- **Sources:** no Snyk Hub module or collectorbot exists in the org (zb-knowledge: zero hits), so
  shapes come from the Snyk REST OpenAPI `2024-10-15` (`https://api.snyk.io/rest/openapi/2024-10-15`),
  cross-checked against `2026-03-25` (identical schemas for these five resources), plus Snyk user
  docs for project `type` / `origin` value lists and pre-defined role names.
- **Parents:** `SnykOrganization → Application`: the org is the SaaS scope that holds accounts and
  the scanned components, the same shape base gives a GitHub org (`SourceCodeMgmt → Application`);
  base `Organization` (a business entity / Party) was rejected — a Snyk org is a workspace, not a
  legal party. `SnykUser → Account` (base has no `User` interface; `Account` carries login, email,
  status and the `app` link). `SnykTarget` / `SnykProject → Component`: both are scanned units
  that expose findings; `Repository` was rejected for targets because targets are heterogeneous
  (images, cloud accounts, CLI directories). `SnykIssue → Finding` via `SnykIssueBase`, following
  the Stellar Cyber precedent (schema PR #60); `SourceCodeMgmtFinding` was rejected because Snyk
  issues are not limited to SCM (container, cloud, IaC).
- **Base gaps:** `SnykIssueBase` carries what `Finding` lacks — `severity` (platform core type;
  Snyk `critical/high/medium/low` map 1:1, `info` → `Low`), `ignored`, `resolvedAt`, and
  unilinks to base `CVE` / `CWE` for the `problems[]` / `classes[]` references.
- **Issue status:** Snyk `open` / `resolved` is mapped onto the inherited `Finding.state`
  (`ACTIVE` / `RESOLVED`) instead of a duplicate `status` enum.
- **Per-org user:** `SnykUser` mirrors `GET /orgs/{org_id}/users/{id}` — one object per user per
  org membership, carrying that org's role. Role names are free strings in the API (custom roles),
  so `orgRole` is a string, not an enum.
- **Open strings, not enums:** project `type` and `origin` and target `integration_type` are free
  strings in the OpenAPI (only the list filters carry enums, and the docs mark the value lists as
  non-exhaustive), so they stay strings; exploit maturity levels and sources likewise.
- **Enums:** every closed enum in the spec is declared verbatim, ALL_CAPS: membership strategy,
  project status / business criticality / environment / lifecycle, recurring-test frequency, issue
  type / resolution type / reachability. No catch-all values.
- **Skipped:** `meta.latest_issue_counts` and `latest_dependency_total` (volatile counters),
  `coordinates[].remedies`, `code_flows`, cloud-resource representations, PR/auto-remediation
  settings beyond `pull_requests.is_enabled`, and the Snyk group (out of scope; `groupId` kept).
- **`links: models:`** not declared — the `snyk.snyk` product carries no `segments` in the catalog.
- **Collector note:** platform `Finding` requires `testCase` and `discovered` (Test) links; the
  collector must supply a Snyk test case / test execution per issue or the platform must relax
  them — flagged for review, not a schema concern.
