---
tags:
  - aviation-domain
  - cns
aliases:
  - NAVAIDs
  - NAVAID
  - Navigational Aids
  - Navigation Aid
  - Radio Navigation Aid
reading-order: 8
created: 2026-09-01
---

# NAVAIDs

> [!abstract] The 30-second version
> A **NAVAID (navigational aid)** is a ground station or satellite system that
> tells an aircraft **where it is** and **which way to go**. Traditional ones
> (VOR, DME, NDB, ILS) broadcast radio signals from a known surveyed point;
> modern navigation increasingly uses **GNSS** (satellites).

## In plain words

Out of sight of land, in cloud, at night — a pilot can't navigate by looking
outside. So the ground (and now space) provides reference signals. A beacon
broadcasts, the aircraft's receiver measures the signal, and from that the
aircraft works out a **direction to the beacon**, a **distance to it**, or a
**precise path down to a runway**.

Every NAVAID is also a **data record**: an identifier, a frequency, an exact
position, a coverage volume, operating hours. Routes and [[09 — Waypoints|Waypoints]] are
often defined *relative to* NAVAIDs, so a wrong NAVAID coordinate corrupts
everything built on it. NAVAID outages are one of the most common
[[15 — NOTAMs|NOTAM]] subjects.

## Why they exist

To let aircraft navigate accurately and fly repeatable, predictable paths —
which is what makes organised routes, instrument approaches and ATC separation
possible.

## The parts you actually need to know

### The main types

| NAVAID | Full name | What it gives the aircraft |
|---|---|---|
| **NDB** | Non-Directional Beacon | a bearing *to* the station (oldest, least accurate) |
| **VOR** | VHF Omnidirectional Range | a precise **radial** — a magnetic bearing *from* the station |
| **DME** | Distance Measuring Equipment | the **distance** to the station |
| **VOR/DME**, **VORTAC** | co-located VOR + DME | bearing **and** distance from one place |
| **ILS** | Instrument Landing System | a precise approach path to a runway: **localizer** (left/right) + **glideslope** (up/down) |
| **GNSS** | Global Navigation Satellite System | position anywhere, from satellites (GPS, Galileo, GLONASS, BeiDou) |

### Line of sight

VHF/UHF NAVAIDs (VOR, DME, ILS) travel in straight lines. The aircraft must be
high enough to be "visible" to the antenna, so a VOR's usable range grows with
altitude (roughly 40–130 NM by class).

![[navaid-vhf-line-of-sight-FAA.png|300]]
*Line-of-sight: an aircraft too low or too far behind the horizon receives
nothing. (FAA PHAK, Fig 16-28.)*

### How a VOR is used

The station projects 360 **radials** like spokes of a wheel. A cockpit
instrument (the **CDI**, or an HSI) shows which radial you're on, whether
you're left or right of a selected course, and a **TO / FROM** flag.

![[navaid-vor-cdi-indicator-FAA.png|300]]
*A course deviation indicator for VOR navigation. (FAA PHAK, Fig 16-29.)*

### Satellite navigation and PBN

- **PBN (Performance-Based Navigation)** — instead of "fly from beacon to
  beacon", the aircraft is only required to **stay within a stated accuracy**
  (e.g. **RNAV 1** = within 1 NM, 95% of the time) using whatever sensors it
  has. This is why modern routes are lists of [[09 — Waypoints|Waypoints]] (latitude/
  longitude) rather than beacon-to-beacon legs.
- The long-term ICAO plan is **GNSS as the primary means**, with a small
  network of conventional NAVAIDs kept as backup.

### What's in a NAVAID record

Identifier (2–3 letters, sent in Morse) · type · frequency/channel · position
in **WGS-84** (see [[20 — GIS|GIS]]) · elevation · magnetic variation · coverage ·
hours. Published in **[[13 — AIP|AIP]] section ENR 4** and modelled in [[21 — AIXM|AIXM]].

## How it connects to the rest

NAVAIDs are operated by the [[02 — ANSP|ANSP]], published by [[05 — AIS|AIS]], used to define
[[09 — Waypoints|Waypoints]] and [[07 — Aerodromes|aerodrome]] approach procedures, and are a
frequent [[15 — NOTAMs|NOTAM]] subject when one goes unserviceable.

## Jargon buster

| Term | Plain meaning |
|---|---|
| VOR / DME / NDB / ILS | see the table above |
| GNSS / GPS | Global Navigation Satellite System / the US one specifically |
| PBN | Performance-Based Navigation |
| RNAV / RNP | Area Navigation / Required Navigation Performance |
| Radial | A magnetic bearing outward from a VOR |
| CDI / HSI | Course Deviation Indicator / Horizontal Situation Indicator (cockpit instruments) |

## Learn more

**Start here (beginner-friendly)**
- GlobeAir — *Navigational Aids (Navaids)*: <https://www.globeair.com/g/navigational-aids-navaids>
- GlobeAir — *Instrument Landing System (ILS)*: <https://www.globeair.com/g/instrument-landing-system-ils>
- SKYbrary — *NAVAID*: <https://skybrary.aero/articles/navaid>
- FAA — *Pilot's Handbook of Aeronautical Knowledge*, Ch. 16 *Navigation*: <https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/phak>

**Go deeper (the official sources)**
- ICAO Annex 10 — *Aeronautical Telecommunications*, Vol I (Radio Navigation Aids): <https://www.icao.int>
- ICAO Doc 9613 — *Performance-Based Navigation (PBN) Manual*: <https://store.icao.int>
- SKYbrary — *Performance Based Navigation (PBN)*: <https://skybrary.aero/articles/performance-based-navigation-pbn>
