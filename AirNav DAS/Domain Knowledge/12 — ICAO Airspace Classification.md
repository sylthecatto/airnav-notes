---
tags:
  - aviation-domain
  - airspace
aliases:
  - ICAO Airspace Classification
  - ICAO Classification
  - Airspace Classification
  - Airspace Classes
  - Class A B C D E F G
reading-order: 12
created: 2026-09-01
---

# ICAO Airspace Classification

> [!abstract] The 30-second version
> [[01 — ICAO|ICAO]] defines **seven airspace classes, A to G**. The class of a piece of
> airspace tells you **who may fly there**, **what service [[03 — ATC|ATC]] gives**, and
> **what the entry requirements are**. Classes **A–E are "controlled"**;
> **F and G are "uncontrolled"**.

## In plain words

Not all airspace needs the same level of control. Over a major airport you
want everything talking to ATC and positively separated. Over open countryside
at low level, light aircraft flying visually can safely look after themselves.

The A–G system is a **menu of rule-sets**. Each piece of airspace is assigned
one letter, and that letter is shorthand for a whole package: are visual (VFR)
flights allowed, does ATC keep them apart from each other or just warn them
about each other, do you need a clearance to enter, do you need a radio.

## Why it exists

To describe airspace rules **consistently worldwide** with a single letter, so
a pilot or a flight-planning system instantly knows what applies.

## The parts you actually need to know

### Two quick definitions

- **IFR** — Instrument Flight Rules: navigate by instruments, always under ATC
  control in controlled airspace.
- **VFR** — Visual Flight Rules: navigate by looking outside, stay clear of
  cloud, "see and avoid".

"**Separation**" = ATC actively keeps two aircraft apart. "**Traffic
information**" = ATC just tells you about the other aircraft and you handle it.

### The class table

| Class | Controlled? | Who's allowed | ATC separates…                                                           | VFR clearance? |
| ----- | ----------- | ------------- | ------------------------------------------------------------------------ | -------------- |
| **A** | yes         | **IFR only**  | everyone from everyone                                                   | (no VFR)       |
| **B** | yes         | IFR + VFR     | **everyone from everyone**, including VFR from VFR                       | yes            |
| **C** | yes         | IFR + VFR     | IFR from IFR and IFR from VFR; VFR gets **traffic info** about other VFR | yes            |
| **D** | yes         | IFR + VFR     | IFR from IFR only; **traffic info** about VFR                            | yes            |
| **E** | yes         | IFR + VFR     | IFR from IFR; VFR **not** separated                                      | no             |
| **F** | no          | IFR + VFR     | IFR gets an **advisory** service (not separation)                        | no             |
| **G** | no          | IFR + VFR     | **nobody is separated**; flight information service only                 | no             |

> [!tip] A rough mnemonic
> **A** = airliners only. **B** = busiest airports, big protection.
> **C**/**D** = medium airports (C bigger than D). **E** = other controlled
> airspace. **F** = advisory only (being phased out). **G** = do-it-yourself.

![[airspace-classes-profile-FAA.png|600]]
*The classic "airspace profile". (FAA* Pilot's Handbook of Aeronautical
Knowledge*, Fig 15-1. This is the US version — the USA doesn't use Class F and
the altitude numbers are US-specific — but the A–G letters and their meaning
are the ICAO standard.)*

### Class F is being retired

ICAO has recommended countries stop using **Class F**, replacing it with Class
E plus published advisory routes, or with proper controlled airspace. You'll
still see it in some countries' publications.

### Special activity airspace (not a class)

Published alongside A–G — see [[28 — AMC Tables|AMC Tables]]:

| Type | Meaning |
|---|---|
| **P — Prohibited** | no flight at all |
| **R — Restricted** | flight only under stated conditions |
| **D — Danger** | activity dangerous to aircraft may be present (advisory) |

## How it connects to the rest

Airspace class is a core attribute of every airspace volume in the [[13 — AIP|AIP]]
(section ENR 1.4) and in [[21 — AIXM|AIXM]]. It's assigned to the pieces inside a
[[10 — FIR|FIR]] and a [[11 — TMA|TMA]], and it constrains what a [[19 — FPL|flight plan]] may do.

## Jargon buster

| Term | Plain meaning |
|---|---|
| IFR / VFR | Instrument / Visual Flight Rules |
| Controlled airspace | Airspace where ATC provides separation (classes A–E) |
| Clearance | ATC's permission to enter/proceed |
| VMC / IMC | Visual / Instrument Meteorological Conditions |
| Special use airspace | Prohibited / restricted / danger areas (separate from A–G) |

## Learn more

**Start here (beginner-friendly)**
- GlobeAir — *Airspace Classifications*: <https://www.globeair.com/g/airspace-classifications>
- Pilot Institute — *Airspace Classes Explained*: <https://pilotinstitute.com/airspace-explained/>
- SKYbrary — *Classification of Airspace*: <https://skybrary.aero/articles/classification-airspace>
- Boldmethod — short visual airspace explainers: <https://www.boldmethod.com>

**Go deeper (the official sources)**
- ICAO Annex 11 — *Air Traffic Services*, Appendix 4 *ATS Airspace Classes*: <https://www.icao.int>
- FAA — *AIP ENR 1.4, ATS Airspace Classification*: <https://www.faa.gov/air_traffic/publications/atpubs/aip_html/part2_enr_section_1.4.html>
