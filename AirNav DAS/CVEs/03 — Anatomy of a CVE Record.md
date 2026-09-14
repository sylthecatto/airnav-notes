---
tags:
  - cybersecurity
  - cve
aliases:
  - CVE Record Format
  - CVE JSON 5.1
reading-order: 3
created: 2026-09-08
---

# Anatomy of a CVE Record

> [!abstract] The 30-second version
> A CVE Record is a **JSON document**. The top holds admin data (`cveMetadata`);
> the body holds one authoritative **`cna` container** written by the assigner,
> plus zero or more **`adp` containers** where others (mainly CISA) bolt on
> extra data. When reviewing an advisory, you read the record to answer: *what
> product, which versions, how bad, what weakness, is there a fix.*

## In plain words

Since format **5.1** (May 2024) every record is structured JSON with a strict
schema. You rarely see raw JSON — `cve.org`, the `NVD`, and vendor pages render
it — but knowing the shape tells you **where each fact lives** and **who is
responsible for it**.

The golden rule: the **`cna` container is authoritative**. If the `adp`
container (e.g. CISA) and the `cna` container disagree on CVSS or CWE, they're
two opinions — note both.

## The structure

```
CVE Record (JSON)
│
├─ dataType: "CVE_RECORD"
├─ dataVersion: "5.1"
│
├─ cveMetadata
│    ├─ cveId ............. CVE-2026-12345
│    ├─ assignerShortName . which CNA owns it
│    ├─ state ............. PUBLISHED | REJECTED
│    ├─ datePublished
│    └─ dateUpdated ....... ← check this; records change
│
└─ containers
     ├─ cna   ← the assigner's authoritative data (exactly one)
     └─ adp[] ← enrichment from others, e.g. CISA ADP (zero or more)
```

### Inside the `cna` container — the fields that matter to a reviewer

| Field | Holds | Why you care |
|---|---|---|
| `title` | one-line summary | fast triage |
| `descriptions[]` | the prose description (≥1, English required) | what the flaw *is* |
| `affected[]` | vendor, product, version ranges, `cpes` | **do we run this?** |
| `metrics[]` | `cvssV3_1` / `cvssV4_0` blocks + vector + `scenarios` | severity — see [[04 — CVSS Explained]] |
| `problemTypes[]` | CWE id(s) + text | the weakness class — see [[07 — Beyond CVSS — CWE, KEV & EPSS]] |
| `references[]` | URLs, each with `tags` (patch, exploit, vendor-advisory…) | fix + evidence |
| `solutions[]` / `workarounds[]` | remediation prose | what to do |
| `exploits[]` | notes on known exploit code / ITW use | urgency |
| `timeline[]` | disclosed / fixed / published dates | coordination context |
| `tags[]` | e.g. `disputed`, `unsupported-when-assigned` | red flags |
| `providerMetadata` | who wrote this + when | provenance |

### The `affected[]` shape (the applicability question)

```
affected: [
  { vendor: "ExampleCorp", product: "WidgetServer",
    versions: [
      { version: "0",   lessThan: "4.2.1", status: "affected", versionType: "semver" },
      { version: "4.2.1", status: "unaffected" }
    ],
    cpes: [ "cpe:2.3:a:examplecorp:widgetserver:*:*:*:*:*:*:*:*" ] }
]
```

Read it as: **everything below 4.2.1 is affected; 4.2.1 is the fix.** Ranges use
`lessThan` / `lessThanOrEqual`; `defaultStatus` plus a `changes` sub-array can
describe more complex patterns. `cpes` give you machine-matchable identifiers
for scanners.

### The `metrics[]` shape

```
metrics: [
  { cvssV3_1: { version: "3.1", baseScore: 9.8, baseSeverity: "CRITICAL",
                vectorString: "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H" } },
  { cvssV4_0: { version: "4.0", baseScore: 9.3, baseSeverity: "CRITICAL",
                vectorString: "CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N" } }
]
```

A record can carry **several** metric entries — different CVSS versions, or one
from the CNA and one from an ADP. `scenarios` text says when a given score
applies (e.g. "default configuration").

### ADP containers

Same shape as `cna`, but supplementary. The one you'll see most is **CISA's
"Vulnrichment" ADP**, which adds CVSS / CWE / CPE / SSVC data when NVD hasn't.
Multiple ADPs can attach; still only ever **one** `cna`.

> [!example] Where to actually read a record
> - Canonical: `https://www.cve.org/CVERecord?id=CVE-2021-44228`
> - Enriched + product data: `https://nvd.nist.gov/vuln/detail/CVE-2021-44228`
> - Raw JSON / history: the `cvelistV5` GitHub repo
> - The vendor's own advisory (linked in `references[]`) — usually the fullest

## How it connects to the rest

This is the object that [[02 — CNAs, Roots & the Record Lifecycle|CNAs and ADPs]]
produce. The `metrics` block is [[05 — CVSS v3.1 Metrics|CVSS v3.1]] /
[[06 — CVSS v4.0 Metrics|v4.0]]. `problemTypes` links to
[[07 — Beyond CVSS — CWE, KEV & EPSS|CWE]]. The whole record is step 1 of
[[08 — Reviewing a CVE Advisory]].

## Jargon buster

| Term | Plain meaning |
|---|---|
| Container | a block of record data attributed to one org |
| `cna` container | the authoritative data from the assigner |
| `adp` container | added data from a non-assigner (e.g. CISA) |
| CPE | `cpe:2.3:a:vendor:product:version:…` — structured product ID |
| `vectorString` | the compact CVSS metric string |
| `versionType` | how to compare versions (semver, rpm, …) |
| `tags` on a reference | hints: `patch`, `exploit`, `vendor-advisory`, `mailing-list` |

## Learn more

**Start here (beginner-friendly)**
- CVE — *Search / read records*: <https://www.cve.org/>
- NVD — *Vulnerabilities*: <https://nvd.nist.gov/vuln>

**Go deeper (the official sources)**
- CVE JSON Record Format schema + docs: <https://cveproject.github.io/cve-schema/schema/docs/>
- CVE — *Record Format announcement (5.1)*: <https://www.cve.org/AllResources/CveServices>
- CISA Vulnrichment (ADP data): <https://github.com/cisagov/vulnrichment>
- `cvelistV5` (the raw records): <https://github.com/CVEProject/cvelistV5>
