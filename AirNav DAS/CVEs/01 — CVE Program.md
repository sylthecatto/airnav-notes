---
tags:
  - cybersecurity
  - cve
aliases:
  - CVE
  - Common Vulnerabilities and Exposures
  - CVE ID
  - CVE Record
reading-order: 1
created: 2026-09-08
---

# CVE Program

> [!abstract] The 30-second version
> **CVE** = *Common Vulnerabilities and Exposures*. It gives every publicly
> disclosed vulnerability **one unique ID** (like `CVE-2021-44228`) and a
> short **record** describing it. That's almost all it does — one name,
> everyone uses it, so a vendor bulletin, a scanner, a news article and a
> patch note are provably talking about the *same* flaw. It is a **dictionary,
> not a database**: the deep detail (scores, product lists) is added by others.

## In plain words

Before 1999, every security vendor had its own name for the same bug. Tool A
said "Apache chunked-encoding overflow", Tool B said "#4212", and nobody could
tell if they matched. **MITRE** proposed a shared list of identifiers; the
**CVE List** launched in **September 1999** with 321 entries.

Today it is run as the **CVE Program**: a non-profit-style effort **operated by
MITRE** (the "Secretariat") and **sponsored by CISA**, the US government cyber
agency. It is free, and the whole catalogue is published openly (as JSON files
on GitHub).

One vulnerability → one CVE Record. The record is deliberately thin: an ID, a
prose description, and at least one public reference. Anything richer — a
severity score, the exact affected versions, a fix — is *enrichment* layered on
top by the [[07 — Beyond CVSS — CWE, KEV & EPSS|NVD, CISA and vendors]].

## Why it exists

To be a **common language for vulnerabilities**: stable identifiers that let
independent parties "discuss, share, and correlate information about a specific
vulnerability, knowing they are referring to the same thing" (CVE Program).

## The parts you actually need to know

### The CVE ID

Format: **`CVE-YYYY-NNNN…`**

- `YYYY` — the year the ID was **reserved**, *not* necessarily when the flaw
  was found, disclosed or published. A `CVE-2024-…` can be published in 2026.
- `NNNN…` — an arbitrary sequence number, **minimum 4 digits**, more when
  needed (5, 6, 7+). Leading zeros pad to 4.
- The "at least 4 digits" rule came in with the **syntax change effective
  1 January 2014** (old IDs were fixed 4 digits, capping a year at 9 999).

> [!example] Reading an ID
> `CVE-2021-44228` — reserved in 2021, sequence 44228 (so >9 999 that year).
> This is Log4Shell. The ID tells you nothing about severity — you need
> [[04 — CVSS Explained|CVSS]] for that.

### CVE Record vs CVE List vs CVE Program

| Term | What it is |
|---|---|
| **CVE ID** | the unique identifier string |
| **CVE Record** | the ID **plus** its description and references |
| **CVE List** | the full catalogue of every CVE Record |
| **CVE Program** | the people, rules and infrastructure that produce the List |

### A record has three possible states

- **Reserved** — an ID has been handed to a [[02 — CNAs, Roots & the Record Lifecycle|CNA]]
  for an issue they're working on; details are not yet public.
- **Published** — the CNA has filled in description + reference; the record is
  live and public.
- **Rejected** — the ID should not be used (duplicate, not a real
  vulnerability, withdrawn). It stays on the List, marked REJECTED, so the
  number is never silently reused.

More on how records move between states: [[02 — CNAs, Roots & the Record Lifecycle]].

### CVE is *not* a vulnerability database

> [!warning] Common misconception
> The CVE List has **no CVSS scores, no risk ratings, no fix data of its own**
> as a guarantee. It is an index. The **[[07 — Beyond CVSS — CWE, KEV & EPSS|NVD]]**
> (NIST) is the database that adds scoring and product data on top — and since
> 2024 its enrichment is heavily backlogged, so increasingly that data comes
> straight from the CNA in the record itself.

### Governance

- **CVE Board** — sets strategy and rules, reviews the program (members from
  industry, academia, government, research).
- **Secretariat (MITRE)** — day-to-day operation, tooling, the "CVE Services"
  API, CNA onboarding.
- **CISA** — US sponsor and funder; also a Root and an
  [[02 — CNAs, Roots & the Record Lifecycle|ADP]] in its own right.

## How it connects to the rest

The CVE ID is the **join key** for everything else in this folder.
[[02 — CNAs, Roots & the Record Lifecycle|CNAs]] mint IDs and publish
[[03 — Anatomy of a CVE Record|records]]; [[04 — CVSS Explained|CVSS]] scores
attach to the ID; [[07 — Beyond CVSS — CWE, KEV & EPSS|CWE, KEV, EPSS]] all
reference it; national bodies like **NCSC** issue advisories that are, in
effect, curated lists of CVE IDs with context.

## Jargon buster

| Term | Plain meaning |
|---|---|
| Secretariat | MITRE, in its role running the program's operations |
| Reserved / Published / Rejected | the three states a record can be in |
| Enrichment | scores, product lists, weakness tags added *after* publication |
| Disputed | a party (often the vendor) publicly disagrees it's a real vuln |
| Assigner | the CNA that owns and reserved a given ID |

## Learn more

**Start here (beginner-friendly)**
- CVE Program — *Overview*: <https://www.cve.org/About/Overview>
- CVE Program — *Glossary*: <https://www.cve.org/ResourcesSupport/Glossary>
- Wikipedia — *Common Vulnerabilities and Exposures*: <https://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures>

**Go deeper (the official sources)**
- CVE Program — *Process*: <https://www.cve.org/About/Process>
- CVE — *CVE ID Syntax* (archived): <https://www.cve.org/Resources/Media/Archives/OldWebsite/cve/identifiers/syntaxchange.html>
- The CVE List on GitHub (`cvelistV5`): <https://github.com/CVEProject/cvelistV5>
- CVE JSON record schema docs: <https://cveproject.github.io/cve-schema/schema/docs/>
