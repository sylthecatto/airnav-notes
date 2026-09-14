---
tags:
  - cybersecurity
  - cvss
aliases:
  - CVSS v3.1
  - CVSS 3.1 metrics
  - CVSS v3.1 vector
reading-order: 5
created: 2026-09-08
---

# CVSS v3.1 Metrics

> [!abstract] The 30-second version
> v3.1 has **8 Base metrics** in a vector like
> `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`. Four describe *how hard the
> attack is* (AV, AC, PR, UI), one is the **Scope** switch, three describe the
> *impact* (C, I, A). Temporal and Environmental metrics are optional add-ons
> that only ever adjust the Base result. This is the version you'll see most
> often today.

## The Base metrics

### Exploitability — "how hard is the attack?"

| Metric | Values | Meaning |
|---|---|---|
| **Attack Vector (AV)** | **N**etwork / **A**djacent / **L**ocal / **P**hysical | where the attacker must be. `N` = routable across the internet; `A` = same subnet/Bluetooth/etc; `L` = local shell or tricking a local user; `P` = hands on the device |
| **Attack Complexity (AC)** | **L**ow / **H**igh | `H` = success needs conditions outside the attacker's control (specific config, winning a race, defeating a mitigation). `L` = just do it |
| **Privileges Required (PR)** | **N**one / **L**ow / **H**igh | account level the attacker needs *before* attacking |
| **User Interaction (UI)** | **N**one / **R**equired | must a *separate* human do something (open a file, click a link)? |

### Scope (S) — "does the blast cross a security boundary?"

| Value | Meaning |
|---|---|
| **U** (Unchanged) | impact stays within the same security authority as the vulnerable component |
| **C** (Changed) | the vulnerable component can be used to impact resources **beyond** its own security scope (classic case: VM escape, or a sandbox breakout) |

`S:C` raises the score and changes the formula. It was the trickiest,
most-argued metric — v4.0 **replaced it** with explicit subsequent-system
metrics ([[06 — CVSS v4.0 Metrics]]).

### Impact — "what happens if it works?" (scored on the *impacted* component)

| Metric | Values | Meaning |
|---|---|---|
| **Confidentiality (C)** | **H**igh / **L**ow / **N**one | information disclosure. `H` = total loss / all data |
| **Integrity (I)** | **H**igh / **L**ow / **N**one | unauthorised modification. `H` = attacker can change anything |
| **Availability (A)** | **H**igh / **L**ow / **N**one | loss of access to the service. `H` = full, sustained outage |

> [!example] Decoding `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` → 9.8
> Attack over the network, no special conditions, no account, no user needed,
> scope unchanged, and total loss of confidentiality + integrity + availability.
> The textbook unauthenticated remote code execution. This is the highest an
> `S:U` vector can reach.

## Temporal metrics (optional — reflect *right now*)

Multiplicative; they can only **lower or hold** the Base score, never raise it.

| Metric | Values | Meaning |
|---|---|---|
| **Exploit Code Maturity (E)** | X / High / Functional / Proof-of-Concept / Unproven | how ready is working exploit code |
| **Remediation Level (RL)** | X / Unavailable / Workaround / Temporary Fix / Official Fix | is there a fix yet |
| **Report Confidence (RC)** | X / Confirmed / Reasonable / Unknown | how sure are we this is real |

(`X` = "Not Defined" = ignore this metric.) v4.0 keeps only the first of these,
renamed — see [[06 — CVSS v4.0 Metrics]].

## Environmental metrics (optional — reflect *your* org)

| Metric | Values | Meaning |
|---|---|---|
| **Security Requirements — CR / IR / AR** | X / High / Medium / Low | how much *you* care about Confidentiality / Integrity / Availability for this asset |
| **Modified Base metrics** (MAV, MAC, MPR, MUI, MS, MC, MI, MA) | same as Base + X | override any Base metric to reflect your mitigations or exposure |

Example: a `C:H` data-leak flaw on a box that holds only public data → set
`CR:L`, and your Environmental score drops.

## The formula (v3.1)

> [!tip] You don't compute this by hand — use the FIRST/NVD calculator.
> But seeing it demystifies the score.

**Metric weights:**

| Metric | Values → weight |
|---|---|
| AV | N 0.85 · A 0.62 · L 0.55 · P 0.20 |
| AC | L 0.77 · H 0.44 |
| PR | N 0.85 · L 0.62 *(0.68 if S:C)* · H 0.27 *(0.50 if S:C)* |
| UI | N 0.85 · R 0.62 |
| C / I / A | H 0.56 · L 0.22 · N 0.00 |

**Equations:**

```
ISS  = 1 − [(1 − C) × (1 − I) × (1 − A)]

Impact  =  6.42 × ISS                                    (Scope Unchanged)
        =  7.52 × (ISS − 0.029) − 3.25 × (ISS − 0.02)¹⁵  (Scope Changed)

Exploitability = 8.22 × AV × AC × PR × UI

BaseScore = 0                                    if Impact ≤ 0
          = Roundup( min[ Impact + Exploitability , 10 ] )        if S:U
          = Roundup( min[ 1.08 × (Impact + Exploitability) , 10 ] ) if S:C
```

`Roundup` = round **up** to 1 decimal place (Roundup(4.02) = 4.1;
Roundup(4.00) = 4.0). This precise definition is the one thing v3.1 fixed
versus v3.0.

## How it connects to the rest

This is the `cvssV3_1` block in [[03 — Anatomy of a CVE Record|the record]].
The concepts carry into [[06 — CVSS v4.0 Metrics|v4.0]], which reshapes several
of these metrics. Use it in [[08 — Reviewing a CVE Advisory|review]] by reading
the vector, not the number.

## Jargon buster

| Term | Plain meaning |
|---|---|
| ISS | Impact Sub-Score — the combined C/I/A term |
| Scope Changed | the flaw can hit things outside the vulnerable component |
| `X` / Not Defined | "skip this metric" — the default for optional metrics |
| Modified metric (M-) | an Environmental override of a Base metric |
| Roundup | round up to one decimal place |

## Learn more

**Start here (beginner-friendly)**
- FIRST — *CVSS v3.1 User Guide*: <https://www.first.org/cvss/v3.1/user-guide>
- NVD — *CVSS v3.1 calculator*: <https://nvd.nist.gov/vuln-metrics/cvss/v3-calculator>

**Go deeper (the official sources)**
- FIRST — *CVSS v3.1 Specification Document*: <https://www.first.org/cvss/v3.1/specification-document>
- FIRST — *CVSS v3.1 Examples*: <https://www.first.org/cvss/v3.1/examples>
- NVD — *CVSS v3.1 equations*: <https://nvd.nist.gov/vuln-metrics/cvss/v3-calculator/v31/equations>
