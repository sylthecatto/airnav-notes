---
tags:
  - cybersecurity
  - cve
  - prioritisation
aliases:
  - CWE
  - KEV
  - EPSS
  - NVD
  - SSVC
reading-order: 7
created: 2026-09-08
---

# Beyond CVSS — CWE, KEV & EPSS

> [!abstract] The 30-second version
> [[04 — CVSS Explained|CVSS]] tells you *how severe* a flaw is. To decide what
> to fix first you need three more signals: **CWE** (what *class* of bug —
> guides detection/mitigation), **KEV** (is it being exploited *right now*),
> and **EPSS** (how *likely* is exploitation in the next 30 days). The **NVD**
> is the database that historically tied these together — but since 2024 its
> coverage is patchy, so read the CNA record and multiple sources.

## CWE — Common Weakness Enumeration

**What it is:** a MITRE-run catalogue of ~900 **weakness types** — the root-cause
categories that vulnerabilities belong to.

**CVE vs CWE:**

```
CWE-89  "SQL Injection"            ← the class of mistake
   └─ CVE-2026-11111 in ShopApp    ← one concrete instance
   └─ CVE-2025-22222 in BillingX   ← another instance of the same class
```

**Why a reviewer cares:** the CWE on a record (`problemTypes[]`) instantly tells
you the *shape* of the problem and the standard countermeasures — CWE-79 (XSS)
→ output encoding / CSP; CWE-787 (out-of-bounds write) → memory-safety, likely
RCE potential; CWE-22 (path traversal) → input canonicalisation.

**Worth knowing:** the annual **CWE Top 25 Most Dangerous Software Weaknesses**
is a good "what actually bites people" list.

## KEV — CISA Known Exploited Vulnerabilities Catalog

**What it is:** CISA's authoritative list of CVEs with **reliable evidence of
active exploitation**. Started November 2021 under US Binding Operational
Directive 22-01.

**Inclusion criteria (all three required):**
1. has a **CVE ID**;
2. **reliable evidence of active exploitation** — "execution of malicious code
   … by an actor … without permission of the system owner" (attempted *or*
   successful);
3. **clear remediation guidance** (usually: apply the vendor patch).

> [!warning] KEV is about *observed* exploitation, not exploitability
> A public PoC alone does **not** get a CVE into KEV. If it's in KEV, someone
> is being attacked with it. That makes KEV the strongest single prioritisation
> signal there is — a Medium-CVSS CVE in KEV outranks a Critical-CVSS CVE that
> isn't.

US federal civilian agencies have mandatory remediation deadlines for KEV
entries; everyone else is "strongly urged" to treat it as a priority list.
KEV also flags **known ransomware use**.

## EPSS — Exploit Prediction Scoring System

**What it is:** a machine-learning model run by a **FIRST** Special Interest
Group that estimates "the probability that a … CVE will be exploited in the
wild in the next 30 days".

| Output | Range | Meaning |
|---|---|---|
| **EPSS probability** | 0.00 – 1.00 | e.g. `0.92` = ~92% chance of exploitation activity in 30 days |
| **EPSS percentile** | 0 – 100% | how this CVE ranks against all scored CVEs (e.g. 99th percentile = worse than 99% of them) |

- Recomputed **daily** for every published CVE.
- Current model is **EPSS v3** (introduced 2023); check FIRST for updates.
- It's a **forecast**, not a severity or a fact — pair it with CVSS.

> [!tip] CVSS × EPSS × KEV, together
> - **In KEV** → patch now, regardless of scores.
> - **High CVSS + high EPSS** → urgent even if not yet in KEV.
> - **High CVSS + low EPSS** → real but not on fire; schedule it.
> - **Low CVSS + high EPSS** → investigate; the model sees something.

## SSVC — a decision framework (context)

**Stakeholder-Specific Vulnerability Categorization** (CISA / CMU-SEI) is a
decision-tree alternative to "sort by CVSS number". It asks: is it exploited?
is it automatable? what's the mission/safety impact? → and outputs an **action**
(*Track / Track\* / Attend / Act*) rather than a score. CISA's ADP data includes
its SSVC decision. You don't need to run it, but you'll see the vocabulary.

## NVD — National Vulnerability Database

**What it is:** NIST's database built on the CVE List, historically adding CVSS
scores, CWE mappings, and **CPE** product identifiers to every CVE.

> [!warning] The NVD enrichment gap (2024 → now)
> NVD fell badly behind on enrichment starting February 2024 (tens of
> thousands of CVEs left un-scored). Per **NIST (April 2026)**, NVD now fully
> enriches only CVEs that are **in KEV**, in federal-government software, or
> designated critical under EO 14028 — everything else is marked *Lowest
> Priority* with no NVD-supplied CVSS / CWE / CPE.
> **Consequence for reviewers:** don't treat "no NVD score" as "not serious".
> Most CNAs now supply CVSS *in the record itself* (>90% coverage), and CISA's
> ADP fills more gaps. Read the `cna` container and the vendor advisory first.

## How it connects to the rest

CWE comes from `problemTypes[]` in [[03 — Anatomy of a CVE Record|the record]].
KEV / EPSS / SSVC sit *alongside* the record, keyed by
[[01 — CVE Program|CVE ID]]. Together with [[04 — CVSS Explained|CVSS]] they are
the inputs to [[08 — Reviewing a CVE Advisory]].

## Jargon buster

| Term | Plain meaning |
|---|---|
| CWE | catalogue of weakness *types* (root causes) |
| CWE Top 25 | annual list of the most impactful weakness classes |
| KEV | CISA's list of CVEs with proven active exploitation |
| BOD 22-01 | the US directive that created KEV |
| EPSS | daily 0–1 probability of exploitation in 30 days |
| EPSS percentile | rank of a CVE vs all others |
| SSVC | decision-tree method that outputs an action, not a score |
| NVD | NIST's enriched database on top of the CVE List |
| CPE | structured `cpe:2.3:…` product identifier used for matching |

## Learn more

**Start here (beginner-friendly)**
- CISA — *Known Exploited Vulnerabilities Catalog*: <https://www.cisa.gov/known-exploited-vulnerabilities-catalog>
- FIRST — *EPSS*: <https://www.first.org/epss/>
- MITRE — *About CWE*: <https://cwe.mitre.org/about/>

**Go deeper (the official sources)**
- MITRE — *CWE Top 25*: <https://cwe.mitre.org/top25/>
- FIRST — *EPSS model & data*: <https://www.first.org/epss/data_stats>
- CISA — *SSVC*: <https://www.cisa.gov/stakeholder-specific-vulnerability-categorization-ssvc>
- NIST — *NVD program news / status*: <https://nvd.nist.gov/general/news>
- NIST — *"NIST Updates NVD Operations to Address Record CVE Growth"* (Apr 2026): <https://www.nist.gov/news-events/news/2026/04/nist-updates-nvd-operations-address-record-cve-growth>
