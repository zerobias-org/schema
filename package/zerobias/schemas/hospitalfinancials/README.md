# Hospital Financials Schema

`@zerobias-org/schema-zerobias-schemas-hospitalfinancials` · `zerobias.schemas.hospitalfinancials.schema`

AuditgraphDB model for hospital financial data, built first for **lab send-out economics**:
for each send-out test, what it costs the hospital, what each payer actually pays, and the gap.
Every class is a hospital-owned record and extends `Object`. All classes carry the `Hospital` prefix.

**Third-party code sets are not modeled here.** CPT/HCPCS procedure codes, ICD-10-CM diagnosis codes,
CARC/RARC adjustment reason codes and CLFS rate lines are published by AMA, CMS and X12 — on this
platform they are `Element`s of a `Standard`, loaded from the `standard/` repo. Hospital records keep the
code *as received* (a plain string) plus a one-way `uniLink` to the published `Element`
(`procedureElement`, `reasonCodeElement`, `HospitalDiagnosis.element`).

## Why this exists

Today the apps assemble these joins in browser memory. The HL7 collector already captures
CPT and test name but Auditgraph has nowhere to store them. This schema is the storage
structure — the atomic inputs only. Derived measures (allowed, net paid, margin, annualized)
are computed downstream.

## Reference entities (shared lists, loaded once)

| Class | Keys | Effective-dated | Source |
|---|---|---|---|
| `HospitalLabTest` | `testCode` | | LIS send-out config · HL7 OBR-4 |
| `HospitalReferenceLab` | `labCode` | | LIS / contract |
| `HospitalReferenceLabTest` | `labTestCode`, `isPanel` | | Reference lab test directory |
| `HospitalChargemasterItem` | `chargeCode`, `chargeAmount`, `revenueCode` | ✓ | Chargemaster |
| `HospitalPayer` | `payerId`, `financialClass`, `remitDeliveryPath` | | 837 NM1\*PR · 835 N1\*PR |
| `HospitalLocation` | `locationCode`, `department` | | HL7 PV1-3 |
| `HospitalReferenceLabFeeScheduleRate` | `contractedPrice` | ✓ | Reference lab client fee schedule (**cost**) |
| `HospitalPayerContractRate` | `expectedAllowable` | ✓ | Payer contract |

## Event entities (transactions)

| Class | Keys | PHI | Source |
|---|---|---|---|
| `HospitalEncounter` | `visitNumber`, `patientClass`, `financialClass` | ✓ | HL7 ADT PV1 |
| `HospitalCoverage` | `planId`, `coveragePriority` | ✓ | HL7 IN1 |
| `HospitalDiagnosis` | `code`, `sequence` | ✓ | HL7 DG1 |
| `HospitalLabOrder` | `placerOrderNumber`, `orderTime`, `isCancelled` | ✓ | HL7 ORC/OBR |
| `HospitalLabResult` | `accessionNumber`, `resultTime`, `notPerformedReason` | ✓ | HL7 ORU |
| `HospitalChargeTransaction` | `transactionId`, `chargeAmount` | ✓ | HL7 DFT^P03 FT1 |
| `HospitalReferenceLabInvoiceLine` | `accessionNumber`, `cost` | | Reference lab invoice (**cost**) |
| `HospitalClaim` | `patientControlNumber`, `claimType`, `billType`, `totalCharge` | ✓ | 837 CLM (**billed**) |
| `HospitalClaimLine` | `lineNumber`, `units`, `lineCharge`, `serviceDate` | | 837 SV1/SV2 |
| `HospitalClaimRejection` | `acknowledgmentType`, `statusCode` | | TA1 · 999 · 277CA |
| `HospitalRemittanceAdvice` | `traceNumber`, `paymentAmount`, `paymentDate` | | 835 BPR/TRN |
| `HospitalRemittanceClaim` | `patientControlNumber`, `claimStatusCode`, `paidAmount` | ✓ | 835 CLP (**paid**) |
| `HospitalRemittanceServiceLine` | `submittedCharge`, `paidAmount`, `allowedAmount` | | 835 SVC / AMT\*B6 |
| `HospitalRemittanceAdjustment` | `groupCode` (CO/PR/OA/PI/CR), `amount` | | 835 CAS |
| `HospitalProviderLevelAdjustment` | `amount`, `fiscalPeriodDate` | | 835 PLB |

## The join spine

1. `HospitalLabOrder` → `HospitalLabResult` — **accession number**
2. `HospitalLabResult.accessionNumber` = `HospitalReferenceLabInvoiceLine.accessionNumber` — **cost**
3. `HospitalLabTest` → `HospitalChargemasterItem.procedureCode`; `HospitalReferenceLabTest.procedureCodes` for panel fan-out — both resolve to the HCPCS/CPT `Element`
4. `HospitalEncounter.visitNumber` = `HospitalClaim.patientControlNumber`; `HospitalClaimLine.procedureCode` + `serviceDate` — **billed**
5. `HospitalClaim` → `HospitalRemittanceClaim` → `HospitalRemittanceServiceLine` — **paid**
6. procedure `Element` + `serviceDate` → the CLFS rate in force — **benchmark** (CLFS lives with the published standards, not here)

Every hospital↔hospital link is declared on both ends (`Class.id.pairedProperty`); links to published `Element`s are one-way (`uniLink: true`).

## Enums

`hospital.patientClass`, `hospital.coveragePriority`, `hospital.claimType`,
`hospital.acknowledgmentType`, `hospital.adjustmentGroupCode`,
`hospital.remitDeliveryPath`.

## Not stored here (derived downstream)

Allowed amount, net paid (after PLB and secondary/crossover), denied lines vs rejected claims,
cost at date of service, volume net of cancels, panel-to-CPT allocation, margin, annualized.
