---
tags:
  - cybersecurity
  - cve
aliases:
  - CNA
  - CVE Numbering Authority
  - Root CNA
  - ADP
  - Authorized Data Publisher
reading-order: 2
created: 2026-09-08
---

# CNAs, Roots & the Record Lifecycle

> [!abstract] The 30-second version
> A **CNA** (CVE Numbering Authority) is an organisation the CVE Program has
> authorised to hand out CVE IDs and publish records **for its own scope**
> (its products, or a slice of the ecosystem). **Roots** recruit and govern
> CNAs. **ADPs** add extra data to records that already exist. A record's life
> is simple: **Reserved → Published**, and rarely **→ Rejected**.

## In plain words

MITRE cannot possibly analyse every vulnerability on Earth. So the program is
**federated**: well over 400 organisations across 40-plus countries (and
growing steadily) each look after part of the problem.

- **Microsoft** is a CNA for Microsoft products.
- **Red Hat**, **Google**, **Apple**, **GitHub**, **Cisco** — CNAs for theirs.
- **curl**, **Python**, the **Linux kernel** — open-source projects are CNAs too.
- **National CSIRTs** (JPCERT/CC, INCIBE, CERT-In) are CNAs for their country.
- Bug-bounty platforms (**HackerOne**, **Bugcrowd**) are CNAs for what's
  reported through them.

When a flaw doesn't fall under any CNA's scope, a **CNA of Last Resort**
handles it.

## Why it's structured this way

The vendor of a product almost always knows it best, can validate the flaw,
and controls the fix timeline. Pushing ID assignment and description out to
them makes records **faster, more accurate, and coordinated with the patch**.

## The parts you actually need to know

### The role hierarchy

```
Top-Level Root ─── MITRE        (and)   CISA
     │                                    │
   Roots  ── Red Hat, ENISA, INCIBE, JPCERT/CC, Google, …
     │
   CNAs   ── the ~450+ orgs that assign IDs within a scope
     │
   CNA-LR ── "of Last Resort": catches anything no CNA covers
```

| Role | What it does |
|---|---|
| **CNA** | reserves CVE IDs, writes + publishes records, in its **scope**. Well over 400 exist |
| **Root** | "recruitment, training, and governance" of the CNAs / ADPs / sub-Roots beneath it, for a scope |
| **Top-Level Root (TL-Root)** | top of a hierarchy; sets rules, arbitrates disputes. Currently **MITRE** and **CISA** |
| **CNA-LR** | a CNA that covers gaps. **MITRE** = overall last resort; **CISA** = last resort for **ICS / OT / medical devices** |
| **ADP** | *Authorized Data Publisher* — enriches an **already-published** record with extra data (scores, affected lists, references) in a defined scope |

### Scope

Every CNA has a written **scope** statement — e.g. "all Fortinet products" or
"vulnerabilities in open-source software not covered by another CNA". It
decides who assigns an ID for a given bug. Two CNAs assigning IDs for the same
flaw causes a **duplicate**, which is later resolved by REJECTing one.

### The one ADP you'll meet: CISA "Vulnrichment"

Since 2024 CISA runs an ADP container that adds **CVSS, CWE, CPE and SSVC /
KEV decision data** to records the [[07 — Beyond CVSS — CWE, KEV & EPSS|NVD]]
hasn't got to. In a modern record you'll often see a `cna` block *and* an
`adp` block from CISA — see [[03 — Anatomy of a CVE Record]].

### The record lifecycle

```
(CNA needs an ID)
      │  reserve
      ▼
  ┌────────┐   publish (add description + ≥1 reference)   ┌───────────┐
  │RESERVED│ ─────────────────────────────────────────►   │ PUBLISHED │
  └────────┘                                              └───────────┘
      │                                                        │  update
      │ withdraw                                               ▼  (any time:
      ▼                                                   new refs, fixed
  ┌──────────┐   (or a published record later found       versions, better
  │ REJECTED │ ◄── invalid / duplicate)                   description, CVSS)
  └──────────┘
```

- **Reserved** — ID allocated, contents embargoed until coordinated disclosure.
- **Published** — public. Must have ID + description + ≥1 public reference.
- **Rejected** — do not use. Stays visible, marked REJECTED, reason given.
- **Updated** — Published records change often. Always check `dateUpdated`.

> [!warning] Records are living documents
> A CVSS score, the CWE, the "known exploited" flag and the affected-version
> list can all appear or change **days or weeks after** first publication.
> A review done on day 1 may need revisiting.

### Operational rules

CNAs operate under the **CNA Operational Rules** (v4.1.0 as of 2025) — timelines
for publishing, what counts as a vulnerability, dispute handling, how to reject.
Worth skimming once if you review advisories regularly.

## How it connects to the rest

The CNA is the `assignerOrgId` and the authoritative `cna` container in
[[03 — Anatomy of a CVE Record|the record]]. **Which** CNA scored a CVE matters
for [[04 — CVSS Explained|CVSS]] — a vendor CNA and the NVD frequently disagree
on the same CVE. National bodies that issue advisories (NCSC, CISA) are often
Roots or CNAs themselves.

## Jargon buster

| Term | Plain meaning |
|---|---|
| CNA | org authorised to assign CVE IDs in a scope |
| Root | org that governs a group of CNAs |
| TL-Root | MITRE or CISA — top of the tree |
| CNA-LR | the catch-all CNA for un-scoped flaws |
| ADP | org that adds data to an existing record |
| Vulnrichment | CISA's ADP program filling the NVD enrichment gap |
| Scope | the written boundary of what a CNA covers |
| Assigner | the CNA that owns a specific CVE ID |

## Learn more

**Start here (beginner-friendly)**
- CVE Program — *CNAs*: <https://www.cve.org/ProgramOrganization/CNAs>
- CVE Program — *Glossary* (Root, ADP, CNA-LR): <https://www.cve.org/ResourcesSupport/Glossary>

**Go deeper (the official sources)**
- CVE — *CNA Operational Rules v4.1.0* (PDF): <https://www.cve.org/Resources/Roles/Cnas/CNA_Rules_v4.1.0.pdf>
- CVE Program — *List of Partners*: <https://www.cve.org/PartnerInformation/ListofPartners>
- CISA — *Vulnrichment* (ADP): <https://github.com/cisagov/vulnrichment>
- CVE Program — *Roles and Responsibilities*: <https://www.cve.org/ProgramOrganization/Roles>
