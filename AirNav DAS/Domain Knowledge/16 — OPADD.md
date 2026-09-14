---
tags:
  - aviation-domain
  - ais-aim
  - dynamic-data
aliases:
  - OPADD
  - Operating Procedures for AIS Dynamic Data
reading-order: 16
created: 2026-09-01
---

# OPADD

> [!abstract] The 30-second version
> **OPADD** = *Operating Procedures for AIS Dynamic Data*. It's a
> **EUROCONTROL guidelines document** that spells out, in fine detail, **how
> to write, structure, replace, cancel and handle [[15 — NOTAMs|NOTAMs]]** so they're
> consistent and machine-processable across countries. [[01 — ICAO|ICAO]] Annex 15 says
> *"issue NOTAMs"*; OPADD says *exactly how*.

## In plain words

The ICAO standard tells you a NOTAM must have fields A) to G) and a Q-code —
but it doesn't tell you, keystroke by keystroke, how to phrase a runway
closure, which Q-code to pick for a specific situation, or how to chain a
replacement to the NOTAM it supersedes. OPADD is that missing manual.

It's officially a European document, but because it fills the practical gap so
well, NOTAM offices and system vendors **around the world** treat it as the
de-facto reference.

## Why it exists

Because inconsistent NOTAMs are a safety problem. If two offices describe the
same kind of event differently, briefing systems can't filter reliably and
pilots waste time decoding. OPADD makes NOTAM writing **uniform**.

## The parts you actually need to know

### "Dynamic data" = NOTAMs

- **Static data** → the [[13 — AIP|AIP]] (permanent, on the [[14 — AIRAC|AIRAC]] calendar).
- **Dynamic data** → temporary / short-notice information: **NOTAMs**, plus
  SNOWTAM and ASHTAM. OPADD covers the dynamic side.

### What OPADD pins down

| Area | Examples |
|---|---|
| **NOTAM composition** | exact use of each field, approved abbreviations, how to write coordinates and heights |
| **Q-code selection** | how to choose the right code (defined in ICAO Doc 8400, rationalised in Doc 8126) and qualify it via the NOTAM Selection Criteria |
| **Series & numbering** | how to allocate series letters and number ranges; checklists |
| **Replacement & cancellation** | when to use `NOTAMR` vs `NOTAMC`; how to reference the old one |
| **Estimated / permanent** | rules for `EST` end dates and converting a NOTAM to `PERM` |
| **Cross-border cases** | who issues what when an event spans two [[10 — FIR\|FIRs]] |
| **Worked scenarios** | runway works, beacon outage, airspace reservation, obstacle, GNSS outage |

### Current edition

**Edition 4.1 (7 December 2020)**, ref. *EUROCONTROL-GUID-121*. It aligned
OPADD with current ICAO SARPs ([[01 — ICAO|Annex 15]] 16th ed., Doc 10066 PANS-AIM),
notably the new **SNOWTAM** format and the *Global Reporting Format* for
runway surface conditions, and added the **NOTAM Checklist**.

### Good vs bad, in one example

> [!example] Weak
> `E) RWY WORK IN PROGRESS` — which runway? how long? affecting what? No usable
> Q-code, so a briefing system can't filter it correctly.

> [!example] OPADD-style
> `Q) .../QMRLC/IV/NBO/A/000/999/...`
> `A) <aerodrome>  B) 2609010600  C) 2609151800`
> `E) RWY 09L/27R CLOSED DUE WIP. TWY B AVBL AS BYPASS.`
> Specific runway, clear times, correct `QMRLC` (runway closed), scope `A`.

### Getting the Q-line right — the qualifier trap

> [!warning] Why customers care about this line specifically
> Briefing systems filter on the **Q-line**, never the free text. Wrong
> qualifiers → the NOTAM reaches the wrong flights, or none. So every NOF and
> system vendor validates the Q-line against a fixed table of **allowed
> combinations** — and most rejections happen here, not in the E) text.

The Q-line is eight fields:

`Q) FIR / Qcode / Traffic / Purpose / Scope / Lower / Upper / Coord+Radius`

Fields **3–5 (Traffic, Purpose, Scope)** are the ones with legality rules.
They are **not free choice** — the NSC gives each NOTAM Code a **default**
Traffic, Purpose and Scope, and you deviate only in the exceptional cases OPADD
spells out (and then it's the publishing NOF's call).

> [!tip] The authority is a lookup table, not the prose
> The **NOTAM Selection Criteria (NSC)** — set out in **ICAO Doc 8126,
> Chapter 6, Appendix B** (and partly in Doc 10066 PANS-AIM, Appendix 3) —
> associate every NOTAM Code with its default **Traffic, Purpose and Scope**.
> The Q-codes themselves are defined in **ICAO Doc 8400** and rationalised in
> Doc 8126; EUROCONTROL also carries the list in the [[21 — AIXM|AIXM]] code lists.
> OPADD's job is to tell you *how to apply* the NSC. So the NSC table, not the
> chapter text, is what a validator enforces and what you practise from.

**Traffic — `I` / `V` / `IV`** (plus `K` for a checklist)

| Value | When the subject is… |
|---|---|
| `I` | IFR-only — ILS/RNAV procedures, en-route navaids, upper airspace |
| `V` | VFR-only — visual reporting points, low-level visual hazards, VFR routes |
| `IV` | affects both — runways, aerodrome, most airspace and warnings (**the default**) |

The NSC sets the default; where the subject or text clearly demands otherwise
the publishing NOF overrides it (e.g. `QAPCI` *VFR reporting point ID changed*
is `IV` in the NSC but published `V`).

**Purpose — `N` `B` `O` `M`, plus `K`**

| Value | Meaning |
|---|---|
| `N` | immediate attention of flight crew — only ever in `NBO` |
| `B` | operationally significant — goes into the [[17 — PIB\|PIB]] |
| `O` | concerns flight operations — only ever in `BO` / `NBO` |
| `M` | miscellaneous — not briefed, retrievable on request |
| `K` | checklist NOTAM (pairs with scope `K`, traffic `K`) |

> [!warning] Only five purpose values are legal
> Lowest → highest operational significance:
> **`K`** (checklist) · **`M`** (admin / non-operational) · **`B`** (briefed) ·
> **`BO`** (briefed + flight-ops) · **`NBO`** (briefed + flight-ops + immediate
> attention). A validator rejects `N`, `NB`, `NO`, `O`, `OM`, `BM`, … And don't
> up- or down-grade the ICAO classification to push a NOTAM into or out of a
> briefing.

**Scope — `A` / `E` / `W` / `K`, plus `AE` `AW`**

| Value | When… |
|---|---|
| `A` | effect is at the aerodrome — taxiway, apron, lighting, local rules; Item A) is the aerodrome |
| `E` | effect is en-route — an airway, an en-route navaid, an airspace change; Item A) is FIR(s) |
| `W` | navigation **warning** — restrictions (`QR…`) and activities/hazards (`QW…`): drones, firing, airshow, parachuting, laser; Item A) is FIR(s) |
| `AE` | affects both aerodrome and en-route operations — a navaid serving both, a CTR change; OPADD's own example is `QNMAS` VOR/DME U/S |
| `AW` | a warning on or beside a field, briefed for both aerodrome and en-route traffic in one NOTAM; Item A) is the aerodrome |
| `K` | checklist, with purpose `K` and traffic `K`; Item A) is FIR(s) |

> [!tip] Scope has to agree with the Q-code subject
> - `QM…` / `QL…` (movement area, lighting) → `A` or `AE`, **never `W`**
> - `QI…` / `QN…` (ILS, navaids) → `A`, `E` or `AE`, **never `W`**
> - `QR…` / `QW…` (restrictions, activities, hazards) → `W`, or `AW` on/near a
>   field — **never plain `A` or `E`**
>
> Where the NSC default is `AE` you may narrow it — `A` if the subject only
> touches arriving/departing traffic, `E` if only overflying traffic (OPADD
> lists `QOB` obstacle, `QAT` TMA, `QAC` CTR, `QSP` APP … as examples).
>
> Limits follow scope: a pure-`A` NOTAM uses **`000/999`** and the aerodrome
> ARP; any `E` / `W` / `AE` / `AW` NOTAM carries the **real band as flight
> levels** (lower rounded down, upper rounded up) and the centre/radius of the
> affected volume — and for `QW…` / `QR…` those must equal Items F) and G) (see
> the drone example in [[15 — NOTAMs]]).

> [!example] The three-question check before you submit
> 1. **Is the Q-code the real, best-fit code?** (ICAO Doc 8400 / 8126 — not a
>    guess, and not `QXXXX` unless nothing genuinely fits.)
> 2. **Do Traffic + Purpose + Scope match what the table allows for that
>    code?** e.g. `QWULW` (unmanned act, will take place) → `IV / BO / W`; the
>    same `W` subject with scope `E` is illegal.
> 3. **Are the limits sane?** Lower ≤ Upper (`000/040`, never `040/000`);
>    `000/999` only for pure-`A`; a real volume whenever scope carries `E`
>    or `W`.

### How to work a document this size

> [!tip] OPADD is a reference, not a textbook — don't read it front to back
> - **Know the chapter map.** Ch.1 intro · **Ch.2 NOTAM Creation** — the
>   item-by-item rules for A)–G) and Q); this is your working chapter · Ch.3
>   NOTAM Processing (what a *receiving* unit does) · Ch.4 coherence messages ·
>   Ch.5 SNOWTAM / ASHTAM · Ch.6 European arrangements (multi-part NOTAM) ·
>   Ch.7 PIB. The appendices are only system parameters + glossary.
> - **The Q-line rules are all in Ch.2 §2.3** (Item Q). But the
>   Traffic/Purpose/Scope *lookup itself is not in OPADD* — it's the **NSC in
>   ICAO Doc 8126, Ch.6 App B**. Keep both open while you draft, plus your
>   customer's own accepted-combination profile.
> - **Learn from the worked examples.** Ch.2 is full of them — cover the
>   Q-line, rebuild it from the E) text, and justify every field against the
>   NSC. That is the skill customers actually test.
> - **Use a validator as your feedback loop.** Run every practice NOTAM through
>   a syntax/semantic checker ([[25 — EAD|EAD]]'s, or any NOTAM validator) and
>   *read the rejection text* — the fastest way to learn which combinations a
>   given customer forbids.
> - **Keep a personal cheat-sheet** of the combos that got rejected and why.
>   After ~20 NOTAMs the patterns repeat.

## How it connects to the rest

OPADD is the rulebook behind [[15 — NOTAMs|NOTAMs]]. Following it is what makes text
NOTAMs reliable enough to convert into **digital NOTAM** ([[21 — AIXM|AIXM]] events,
using the [[22 — AIXM Temporality Model|AIXM Temporality Model]]) and what systems like [[25 — EAD|EAD]] expect.

## Jargon buster

| Term | Plain meaning |
|---|---|
| OPADD | Operating Procedures for AIS Dynamic Data |
| Dynamic data | Temporary / short-notice information (NOTAMs) |
| ECAC | European Civil Aviation Conference (endorses OPADD) |
| GRF | Global Reporting Format (a standard way to report runway surface state) |
| NOF | (International) NOTAM Office; OPADD says *Publishing NOF* — the office that creates the original NOTAM |
| Q-line qualifiers | Traffic (`I`/`V`/`IV`), Purpose (`N`/`B`/`O`/`M`/`K`), Scope (`A`/`E`/`W`/`K` + `AE`/`AW`) |
| NSC | NOTAM Selection Criteria — the ICAO Doc 8126 table mapping each Q-code to its default traffic / purpose / scope |

## Learn more

**Start here (beginner-friendly)**
- SKYbrary — *Notice to Airmen (NOTAM)* (context for why OPADD exists): <https://skybrary.aero/articles/notice-airmen-notam>
- EUROCONTROL — *OPADD* landing page (overview): <https://www.eurocontrol.int/publication/eurocontrol-guidelines-operating-procedures-ais-dynamic-data-opadd>

**Q-line / qualifier validation**
- Wikipedia — *NOTAM code* (full Q-code list with the subject/condition pairs): <https://en.wikipedia.org/wiki/NOTAM_code>
- FAA — *International NOTAM (Q) Codes* (Appendix B — lists valid purpose & scope per code): <https://www.faa.gov/air_traffic/publications/atpubs/notam_html/appendix_b.html>
- EUROCONTROL — *AIXM* (the NOTAM code list is published as an AIXM code list): <https://www.aixm.aero>

**Go deeper (the official sources)**
- EUROCONTROL — *OPADD Edition 4.1* (PDF): <https://www.eurocontrol.int/sites/default/files/2021-07/eurocontrol-guidelines-opadd-ed4-1.pdf> — Item Q) rules in Ch.2 §2.3
- ICAO Doc 8400 — *ICAO Abbreviations and Codes* (defines the NOTAM Code): <https://store.icao.int>
- ICAO Doc 8126 — *AIS Manual*, Chapter 6 Appendix B holds the **NOTAM Selection Criteria**: <https://store.icao.int>
- ICAO Doc 10066 — *PANS-AIM*, Appendix 3 (NOTAM format) & Appendix 4 (SNOWTAM): <https://store.icao.int>
