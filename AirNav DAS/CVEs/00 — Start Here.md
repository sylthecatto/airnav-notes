---
tags:
  - cybersecurity
  - cve
  - moc
aliases:
  - CVE MOC
  - CVE Notes Index
reading-order: 0
created: 2026-09-08
---

# Start Here — CVEs, CVSS & Advisory Review

> [!abstract] The 30-second version
> A **CVE** is a public ID + short record for one disclosed software/hardware
> vulnerability. **CVSS** is the 0–10 score that rates how *severe* it is.
> Around those two sits a small ecosystem — **CNAs** who write the records,
> **CWE** for the bug class, **KEV** for "is it being exploited", **EPSS** for
> "will it be". This folder explains each piece and ends with a **workflow for
> reviewing an advisory** (which is the actual job).

## What this folder is

A study track on the vulnerability-cataloguing world, written to be read in
order. It exists so that reviewing an incoming CVE advisory (an NCSC alert, a
vendor bulletin, a spreadsheet of IDs) is a understood process, not a
guess.

Every fact here is checked against the **primary source** — the CVE Program
(`cve.org`), FIRST (`first.org`), NIST NVD (`nvd.nist.gov`), MITRE CWE
(`cwe.mitre.org`), and CISA (`cisa.gov`). Each note ends with those links.

## The notes

| # | Note | What it answers |
|---|---|---|
| 01 | [[01 — CVE Program]] | What a CVE *is*, the ID format, the record, the history |
| 02 | [[02 — CNAs, Roots & the Record Lifecycle]] | Who creates records and how; Reserved → Published → Rejected |
| 03 | [[03 — Anatomy of a CVE Record]] | The JSON record's fields, and where to read one |
| 04 | [[04 — CVSS Explained]] | What the score means, the versions, the severity bands, the traps |
| 05 | [[05 — CVSS v3.1 Metrics]] | Every Base / Temporal / Environmental metric + the formula |
| 06 | [[06 — CVSS v4.0 Metrics]] | The 2023 redesign: Base / Threat / Environmental / Supplemental |
| 07 | [[07 — Beyond CVSS — CWE, KEV & EPSS]] | The enrichment layer and how to prioritise |
| 08 | [[08 — Reviewing a CVE Advisory]] | The step-by-step triage workflow |

## The mental model

```
CWE  ──►  the weakness class      (e.g. CWE-89 SQL injection)
CVE  ──►  one concrete instance   (e.g. CVE-2026-12345 in ProductX 2.1)
CVSS ──►  how severe that instance is, worst-case   (0.0–10.0 + vector)
KEV  ──►  is it being exploited right now?   (yes / not listed)
EPSS ──►  how likely is exploitation in 30 days?   (0–1 probability)
NVD  ──►  the database that bolts scores + product data onto the CVE list
```

Severity (CVSS) is **not** risk. Risk = severity **+** is it exploitable in
*our* environment **+** is it actually being exploited. Notes 07 and 08 are
about closing that gap.

## Jargon buster (the acronym wall)

| Term | Expansion | One line |
|---|---|---|
| CVE | Common Vulnerabilities and Exposures | the ID + record for one vulnerability |
| CVSS | Common Vulnerability Scoring System | the 0–10 severity score |
| CNA | CVE Numbering Authority | an org allowed to assign CVE IDs |
| ADP | Authorized Data Publisher | an org that enriches an existing record |
| CWE | Common Weakness Enumeration | catalogue of weakness *types* |
| NVD | National Vulnerability Database | NIST's enriched build of the CVE list |
| KEV | Known Exploited Vulnerabilities | CISA's list of CVEs exploited in the wild |
| EPSS | Exploit Prediction Scoring System | FIRST's 30-day exploitation probability |
| CPE | Common Platform Enumeration | structured product/version identifiers |
| FIRST | Forum of Incident Response and Security Teams | owns CVSS and EPSS |
| CISA | Cybersecurity and Infrastructure Security Agency | US agency; sponsors CVE, runs KEV |
| NCSC | National Cyber Security Centre (UK) | issues national advisories that bundle CVEs |

## Learn more

**Start here (beginner-friendly)**
- CVE Program — *Overview*: <https://www.cve.org/About/Overview>
- FIRST — *CVSS*: <https://www.first.org/cvss/>
- CISA — *Known Exploited Vulnerabilities Catalog*: <https://www.cisa.gov/known-exploited-vulnerabilities-catalog>

**Go deeper (the official sources)**
- CVE Program site: <https://www.cve.org/>
- NIST NVD: <https://nvd.nist.gov/>
- MITRE CWE: <https://cwe.mitre.org/>
- FIRST EPSS: <https://www.first.org/epss/>
