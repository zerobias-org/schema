# @zerobias-org/schema-stellarcyber-stellarcyber

AuditgraphDB schema for **Stellar Cyber** Open XDR.

Defines `StellarCyberFinding` — a correlated threat finding (case) that `extends`
the base `Finding` interface and adds Stellar Cyber-specific context (MITRE ATT&CK
tactic/technique, case score, affected-resource ARN, AWS account/region).

Populated by the Stellar Cyber collectorbot from the module's `CaseApi` operations.
