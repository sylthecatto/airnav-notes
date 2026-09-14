---
tags:
  - cybersecurity
  - cve
  - workflow
aliases:
  - CVE triage
  - advisory review
  - vulnerability triage workflow
reading-order: 8
created: 2026-09-08
---

# Reviewing a CVE Advisory

> [!abstract] The 30-second version
> An advisory (an NCSC alert, a vendor bulletin, a spreadsheet of CVE IDs)
> lands. The job is to turn a list of IDs into **decisions**: *do we run this,
> how bad is it for us, is it being exploited, what's the fix, what priority,
> by when.* This note is the repeatable checklist, plus the traps that cause
> wrong calls.

## Where advisories come from

| Source | What it is |
|---|---|
| **National CSIRT** (UK **NCSC**, US **CISA**) | curated alerts bundling CVEs relevant to a sector or a live campaign; often the trigger for a review cycle |
| **Vendor advisory** | the authoritative detail for that vendor's CVEs — usually the fullest source, linked from the record's `references[]` |
| **NVD / CVE feeds** | the raw records; good for automation, thin on "so what" |
| **Threat intel / news** | early warning, but verify against the record before acting |

Many CSIRTs are themselves [[02 — CNAs, Roots & the Record Lifecycle|CNAs or Roots]]
(ENISA runs the EU Root; NCSC-EU sits under it), so their advisories tend to
track the canonical records closely.

## The workflow

```
1 IDENTIFY ─► 2 APPLICABILITY ─► 3 SEVERITY ─► 4 EXPLOITATION
                                                      │
        7 RECORD & WATCH ◄─ 6 PRIORITISE ◄─ 5 REMEDIATION
```

### 1 — Identify

- Extract every **CVE ID**; sanity-check the format (`CVE-YYYY-NNNN…`).
- Pull the **canonical record**: `cve.org/CVERecord?id=…`.
- Note the **state** — skip `REJECTED`; for `RESERVED` there's nothing public
  yet, park it.
- Cross-reference **NVD** and the **vendor advisory**. Note `dateUpdated`.

### 2 — Applicability — *do we even run this?*

- Read `affected[]`: vendor, product, and the **version ranges** (`lessThan` /
  `lessThanOrEqual`). Match against your actual inventory / CMDB / SBOM.
- Check **configuration gating**: does it need a feature enabled, a specific
  OS, a particular deployment? (In [[06 — CVSS v4.0 Metrics|v4.0]] this shows
  up as **Attack Requirements**; vendor advisories spell it out.)
- **Not affected → document why and stop.** This is most of the list, and
  writing down "we don't run X" is a valid, auditable outcome.

### 3 — Severity — *read the vector, not the number*

- Find the **CVSS vector** in `metrics[]`. Note the **version** (`CVSS:3.1/…`
  vs `CVSS:4.0/…`) — [[04 — CVSS Explained|don't compare across versions]].
- Note **who scored it**: CNA, CISA ADP, NVD. If they disagree, read the
  vectors and decide which assumptions fit reality.
- Decode the vector ([[05 — CVSS v3.1 Metrics|v3.1]] / [[06 — CVSS v4.0 Metrics|v4.0]]):
  network-reachable? needs auth? needs a user? what's the actual impact —
  disclosure, tampering, or outage?

### 4 — Exploitation — *is it real-world, right now?*

| Check | Source | Weight |
|---|---|---|
| In **CISA KEV**? | [[07 — Beyond CVSS — CWE, KEV & EPSS|KEV catalog]] | **highest** — active exploitation confirmed |
| **EPSS** probability / percentile | FIRST EPSS | high EPSS = model expects exploitation soon |
| Public **PoC / exploit**? | record `references[]` (tag `exploit`), `exploits[]` | raises urgency below KEV |
| Vendor says "aware of exploitation"? | vendor advisory | treat as KEV-equivalent |

### 5 — Remediation

- **Fixed version** from `affected[]` (`status: unaffected`) or the vendor
  advisory.
- **Workaround / mitigation** (`workarounds[]`, `solutions[]`) — config change,
  WAF rule, disable a feature — for when you can't patch immediately.
- Note if the product is **end-of-life** (`tags: unsupported-when-assigned`) —
  no fix is coming; the answer is compensating controls or replacement.

### 6 — Prioritise

Combine, roughly in this order of pull:

```
in KEV / vendor-confirmed exploitation      → emergency change
high CVSS + internet-facing + high EPSS      → urgent
high CVSS + internal only                    → standard SLA
medium/low CVSS + low EPSS + not exposed     → routine / batch
not applicable                               → close with rationale
```

Feed your context back in as [[05 — CVSS v3.1 Metrics|Environmental metrics]]
if you want a defensible adjusted score (asset value via CR/IR/AR, exposure via
Modified Attack Vector).

### 7 — Record the decision & watch for change

- Log: CVE ID, applicable Y/N, adjusted severity, exploitation status, action,
  owner, due date, **rationale**.
- **Records change.** Re-check anything left open when `dateUpdated` moves — a
  CVSS score can land, a CWE can be added, KEV status can flip.

## The traps

> [!warning] What causes wrong calls
> - **Severity ≠ risk.** A Critical you don't run is noise; a Medium in KEV on
>   your DMZ is an incident.
> - **Trusting the number, not the vector.** `AV:N` vs `AV:L` changes
>   everything and the score alone hides it.
> - **Mixing CVSS versions.** A v4.0 `8.5` and a v3.1 `9.1` aren't on the same
>   scale.
> - **"No NVD score" ≠ "not serious."** Post-2024 NVD only fully enriches
>   KEV/critical CVEs — use the CNA record and vendor advisory.
> - **Disputed / Rejected CVEs.** Check `tags` and `state`; don't chase a
>   withdrawn or vendor-disputed ID.
> - **Duplicates.** The same flaw can briefly get two IDs before one is
>   REJECTed.
> - **Reserved ≠ nothing.** An ID with no detail may be a coordinated
>   disclosure about to drop — note it, revisit.
> - **Single source.** Cross-check record ↔ NVD ↔ vendor before deciding.
> - **Stale review.** A day-1 assessment can be invalidated by a day-10 update.

## How it connects to the rest

This note is the payoff for [[01 — CVE Program]] through
[[07 — Beyond CVSS — CWE, KEV & EPSS]]. Step 1 uses
[[03 — Anatomy of a CVE Record]]; step 3 uses [[04 — CVSS Explained|CVSS]];
step 4 uses [[07 — Beyond CVSS — CWE, KEV & EPSS|KEV/EPSS]].

## Jargon buster

| Term | Plain meaning |
|---|---|
| Applicability / triage | deciding whether a CVE affects your estate |
| Compensating control | a mitigation used when you can't patch |
| SLA | the deadline your policy sets for a given severity |
| Emergency change | out-of-cycle patching for an active threat |
| EOL / unsupported | no fix will be issued for this product |
| Rationale | the written reason for a decision — the audit trail |

## Learn more

**Start here (beginner-friendly)**
- NCSC (UK) — *Vulnerability management guidance*: <https://www.ncsc.gov.uk/collection/vulnerability-management>
- CISA — *Known Exploited Vulnerabilities Catalog*: <https://www.cisa.gov/known-exploited-vulnerabilities-catalog>

**Go deeper (the official sources)**
- CISA — *SSVC* (decision-tree prioritisation): <https://www.cisa.gov/stakeholder-specific-vulnerability-categorization-ssvc>
- FIRST — *CVSS v4.0 User Guide* (scoring in context): <https://www.first.org/cvss/v4.0/user-guide>
- FIRST — *EPSS user guide*: <https://www.first.org/epss/user-guide>
- NIST SP 800-40r4 — *Guide to Enterprise Patch Management Planning*: <https://csrc.nist.gov/pubs/sp/800/40/r4/final>
