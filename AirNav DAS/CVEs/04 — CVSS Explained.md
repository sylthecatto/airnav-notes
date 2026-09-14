---
tags:
  - cybersecurity
  - cvss
aliases:
  - CVSS
  - Common Vulnerability Scoring System
  - CVSS score
  - severity rating
reading-order: 4
created: 2026-09-08
---

# CVSS Explained

> [!abstract] The 30-second version
> **CVSS** turns a vulnerability's technical characteristics into a number from
> **0.0 to 10.0** and a **vector string** that shows the working. It measures
> **severity**, roughly "how bad is this in a reasonable worst case" — **not
> risk**, and not "how bad is it *for us*". It's owned by **FIRST**, it's free,
> and the current version is **4.0** (2023), though **3.1** is still everywhere.

## In plain words

You need a consistent way to say "this one's worse than that one" across
thousands of vulnerabilities from hundreds of vendors. CVSS is that yardstick.

An analyst answers a fixed set of multiple-choice questions — *Can it be
attacked over the network? Does it need a logged-in user? Does it leak data,
corrupt data, or take the system down?* — and a formula converts the answers
into a score and a severity band.

The **vector string** is the record of those answers, e.g.:

```
CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H   →  9.8  CRITICAL
```

Anyone can re-derive the 9.8 from that string, and — more importantly — see
*why*: network-reachable (`AV:N`), no privileges (`PR:N`), no user interaction
(`UI:N`), total confidentiality/integrity/availability loss (`C:H/I:H/A:H`).

> [!tip] Always read the vector, not just the number
> Two `7.5` vulnerabilities can be completely different — one a data leak, one
> a denial of service. The number is a lossy summary; the vector is the fact.

## Why it exists

To provide "a way to capture the principal characteristics of a vulnerability
and produce a numerical score reflecting its severity" (FIRST), in a form
that's open, reproducible, and vendor-neutral.

## The parts you actually need to know

### The three (or four) metric groups

| Group | Answers | Who sets it | Changes over time? |
|---|---|---|---|
| **Base** | intrinsic, worst-case severity of the flaw itself | CNA / vendor / NVD | no — fixed properties |
| **Temporal** (v3.1) / **Threat** (v4.0) | is there working exploit code / active exploitation | analyst, from threat intel | yes |
| **Environmental** | how it maps to *your* deployment and asset value | the end-user org | yes, per environment |
| **Supplemental** (v4.0 only) | extra context (safety, recoverability…) — **no score effect** | provider | — |

**Base is mandatory. The rest are optional and only ever *modify* the Base
picture.** Almost every CVSS score you see published is **Base only**.

### The severity bands (v3.0, v3.1 and v4.0 — identical)

| Score | Severity |
|---|---|
| 0.0 | None |
| 0.1 – 3.9 | Low |
| 4.0 – 6.9 | Medium |
| 7.0 – 8.9 | High |
| 9.0 – 10.0 | Critical |

> [!warning] v2 bands are different
> CVSS **v2** had only Low (0.0–3.9) / Medium (4.0–6.9) / High (7.0–10.0) and
> no "Critical". Don't compare a v2 number to a v3/v4 number.

### Version history

| Version | Year | Custodian / note |
|---|---|---|
| v1 | 2005 | NIAC; FIRST made custodian |
| v2 | 2007 | first broadly adopted version |
| v3.0 | 2015 | added Scope, reworked impact |
| **v3.1** | **June 2019** | clarifications only, no new metrics — still the most common in the wild |
| **v4.0** | **1 Nov 2023** | current. New `AT` metric, Scope replaced, Temporal→Threat, Supplemental group — see [[06 — CVSS v4.0 Metrics]] |

Adoption of v4.0 is gradual: many CNAs still publish v3.1, some publish both,
NVD historically scored in v3.1. Expect **mixed versions** in any advisory.

### What CVSS is *not*

> [!warning] Severity ≠ risk. This is the single biggest misuse.
> - A **Critical 9.8** in a product you don't run is **not your problem**.
> - A **Medium 5.3** that is **[[07 — Beyond CVSS — CWE, KEV & EPSS|in CISA KEV]]**
>   and internet-facing on your perimeter **is** your problem.
> - CVSS Base is a **"reasonable worst case"** — it deliberately assumes the
>   unluckiest plausible configuration.
> - The FIRST spec itself says Base scores "should not be used alone to assess
>   risk". Combine with exploitation data (KEV, EPSS) and your own context
>   (Environmental metrics) — that's [[08 — Reviewing a CVE Advisory]].
q
### Who scored it matters

The same CVE often has **different scores** from the vendor CNA, from CISA's
ADP, and from NVD — because scoring involves judgement (especially Attack
Complexity and Scope/subsequent-system). When they differ, understand *why*
before trusting one.

## How it connects to the rest

CVSS lives in the `metrics[]` block of [[03 — Anatomy of a CVE Record|the CVE record]].
The mechanics are in [[05 — CVSS v3.1 Metrics]] and [[06 — CVSS v4.0 Metrics]].
For prioritisation you pair it with [[07 — Beyond CVSS — CWE, KEV & EPSS|KEV and EPSS]].

## Jargon buster

| Term | Plain meaning |
|---|---|
| Base score | the standard 0–10 severity number |
| Vector string | the compact record of every metric choice |
| Reasonable worst case | the scoring assumption behind Base metrics |
| Temporal / Threat | metrics for exploit availability, change over time |
| Environmental | metrics that tailor the score to one organisation |
| CVSS-B / CVSS-BT / CVSS-BTE | v4.0 shorthand for *which* groups were scored |
| FIRST | the body that owns and publishes the CVSS standard |

## Learn more

**Start here (beginner-friendly)**
- FIRST — *CVSS*: <https://www.first.org/cvss/>
- SANS — *What is CVSS*: <https://www.sans.org/blog/what-is-cvss>
- Wikipedia — *Common Vulnerability Scoring System*: <https://en.wikipedia.org/wiki/Common_Vulnerability_Scoring_System>

**Go deeper (the official sources)**
- FIRST — *CVSS v4.0 Specification*: <https://www.first.org/cvss/v4.0/specification-document>
- FIRST — *CVSS v3.1 Specification*: <https://www.first.org/cvss/v3.1/specification-document>
- FIRST — *CVSS v4.0 User Guide*: <https://www.first.org/cvss/v4.0/user-guide>
- NVD — *CVSS calculators*: <https://nvd.nist.gov/vuln-metrics/cvss>
