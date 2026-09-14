---
tags:
  - cybersecurity
  - cvss
aliases:
  - CVSS v4.0
  - CVSS 4.0 metrics
  - CVSS-B
  - CVSS-BTE
reading-order: 6
created: 2026-09-08
---

# CVSS v4.0 Metrics

> [!abstract] The 30-second version
> v4.0 (Nov 2023) keeps the same 0–10 bands but reworks the metrics: adds
> **Attack Requirements (AT)**, splits impact into **Vulnerable System
> (VC/VI/VA)** and **Subsequent System (SC/SI/SA)** — killing the old Scope
> flag — slims Temporal down to one **Threat** metric, and adds a
> score-neutral **Supplemental** group. New naming (**CVSS-B / BT / BE / BTE**)
> tells you which groups were used.

## Why v4.0 exists

Three complaints about v3.1: Base scores clustered too high, **Scope** was
inconsistently applied, and there was nowhere to record safety impact or
automation potential. v4.0 addresses each.

## The four groups

| Group | Metrics | Scores it? |
|---|---|---|
| **Base** | AV, AC, **AT**, PR, UI, VC, VI, VA, SC, SI, SA | yes (mandatory) |
| **Threat** | Exploit Maturity (E) | yes (optional) |
| **Environmental** | CR, IR, AR + Modified Base metrics | yes (optional) |
| **Supplemental** | S, AU, R, V, RE, U | **no** — context only |

## Base — Exploitability

| Metric | Values | Change from v3.1 |
|---|---|---|
| **Attack Vector (AV)** | N / A / L / P | same |
| **Attack Complexity (AC)** | L / H | now specifically "did the attacker have to defeat a security mitigation" |
| **Attack Requirements (AT)** | **N**one / **P**resent | **NEW** — deployment conditions the attacker can't control (race window, specific config, MITM position) |
| **Privileges Required (PR)** | N / L / H | same |
| **User Interaction (UI)** | **N**one / **P**assive / **A**ctive | **split** — `P` = incidental (just viewing a page), `A` = deliberate action |

Splitting AC into AC + AT is the key fix: v3.1 crammed "hard to do" and "needs
special conditions" into one metric.

## Base — Impact (this replaces Scope)

Every impact is scored **twice**: on the vulnerable system, and on any
*subsequent* system it lets you reach.

| Metric | Values | Meaning |
|---|---|---|
| **VC / VI / VA** | H / L / N | Confidentiality / Integrity / Availability impact on the **Vulnerable System** (the thing with the bug) |
| **SC / SI / SA** | H / L / N | …impact on a **Subsequent System** (anything downstream — the host OS, another service, the wider network) |

> [!tip] Vulnerable vs Subsequent, quickly
> The **Vulnerable System** contains the flaw and its security policy is
> directly broken. A **Subsequent System** is harmed by exploitation but
> doesn't contain the flaw. VM guest bug that reads host files → `VC:H` (guest)
> **and** `SC:H` (host).

## Threat — Exploit Maturity (E)

| Value | Meaning |
|---|---|
| **X** – Not Defined | no threat data (default; treated as "Attacked" for scoring) |
| **A** – Attacked | exploitation observed in the wild, or exploit is trivially available |
| **P** – Proof-of-Concept | PoC exists, no confirmed in-the-wild use |
| **U** – Unreported | no known PoC or exploitation |

Setting a realistic `E` value **lowers** an over-cautious Base score. (v3.1's
Remediation Level and Report Confidence are **gone**.)

## Environmental

| Metric | Values | Meaning |
|---|---|---|
| **CR / IR / AR** | X / H / M / L | your Confidentiality / Integrity / Availability requirements for the asset |
| **Modified Base metrics** | mirror every Base metric, + X | override Base to reflect your environment; **MSI / MSA** additionally allow **S** (Safety) |

## Supplemental — context only, never changes the score

| Metric | Values | Captures |
|---|---|---|
| **Safety (S)** | X / Present / Negligible | can exploitation cause physical harm to people |
| **Automatable (AU)** | X / No / Yes | can an attacker script this at scale (worm-friendly) |
| **Recovery (R)** | X / Automatic / User / Irrecoverable | how the system comes back after exploitation |
| **Value Density (V)** | X / Diffuse / Concentrated | how much value one exploited target holds |
| **Vulnerability Response Effort (RE)** | X / Low / Moderate / High | how hard remediation is for defenders |
| **Provider Urgency (U)** | X / Red / Amber / Green / Clear | the provider's own priority signal |

## Nomenclature — always say which groups you used

| Label | Groups scored |
|---|---|
| **CVSS-B** | Base only ← what most published scores are |
| **CVSS-BT** | Base + Threat |
| **CVSS-BE** | Base + Environmental |
| **CVSS-BTE** | Base + Threat + Environmental |

So "the CVSS-B score is 9.3" is precise; "the CVSS score is 9.3" is not.

## Scoring & severity

Bands are **identical to v3.1**: None 0.0 · Low 0.1–3.9 · Medium 4.0–6.9 ·
High 7.0–8.9 · Critical 9.0–10.0.

The maths is different though: v4.0 has **no closed formula**. It maps your
vector to a "MacroVector" (a bucket of similar vectors), looks up a scored
value, and **interpolates**. Use the calculator.

A v4.0 vector always starts `CVSS:4.0/` and must contain all 11 Base metrics:

```
CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N   → 9.3  CRITICAL
```

> [!warning] Don't compare v3.1 and v4.0 numbers
> Same vulnerability, different methodology — a v3.1 `9.8` and a v4.0 `9.3` are
> not "a downgrade". Track which version produced the score (it's in the vector
> prefix and the record's `metrics` block).

## How it connects to the rest

The `cvssV4_0` block in [[03 — Anatomy of a CVE Record|a record]]. Builds on
[[05 — CVSS v3.1 Metrics|v3.1]]. The Threat metric overlaps conceptually with
[[07 — Beyond CVSS — CWE, KEV & EPSS|KEV / EPSS]] data. Applied in
[[08 — Reviewing a CVE Advisory]].

## Jargon buster

| Term | Plain meaning |
|---|---|
| AT | Attack Requirements — target-side conditions for exploitation |
| Vulnerable System | the component that has the bug |
| Subsequent System | something else harmed when the bug is exploited |
| Threat group | v4.0's slimmed replacement for Temporal metrics |
| Supplemental | extra context metrics that never move the score |
| MacroVector | the bucket-and-interpolate method v4.0 uses instead of a formula |
| CVSS-B / BT / BE / BTE | which metric groups a score was built from |

## Learn more

**Start here (beginner-friendly)**
- FIRST — *CVSS v4.0*: <https://www.first.org/cvss/v4.0/>
- FIRST — *CVSS v4.0 User Guide*: <https://www.first.org/cvss/v4.0/user-guide>

**Go deeper (the official sources)**
- FIRST — *CVSS v4.0 Specification Document*: <https://www.first.org/cvss/v4.0/specification-document>
- FIRST — *CVSS v4.0 Examples*: <https://www.first.org/cvss/v4.0/examples>
- FIRST — *CVSS v4.0 calculator*: <https://www.first.org/cvss/calculator/4.0>
