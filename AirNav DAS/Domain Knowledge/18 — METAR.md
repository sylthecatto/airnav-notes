---
tags:
  - aviation-domain
  - met
aliases:
  - METAR
  - Meteorological Aerodrome Report
  - Aviation Routine Weather Report
reading-order: 18
created: 2026-09-01
---

# METAR

> [!abstract] The 30-second version
> A **METAR** is the **standard coded weather report for an airport**, observed
> and issued **every hour** (with a **SPECI** in between if conditions change
> sharply). It packs wind, visibility, cloud, temperature and pressure into
> one line that means the same thing in every country.

## In plain words

Pilots need to know the actual weather at their departure, destination and
alternate airports. A METAR is that snapshot, written in a terse code so it's
compact and language-independent. Once you learn the pattern, you can read one
at a glance.

METAR is a **meteorology (MET)** product, not an [[05 — AIS|AIS]] one — but aeronautical
information work touches it constantly, because it travels on the same
messaging network as [[15 — NOTAMs|NOTAMs]] ([[24 — AMHS|AMHS]]) and appears in the [[17 — PIB|PIB]].

## Why it exists

To give a **standard, worldwide, machine-readable** description of current
airport weather for flight planning and safety.

## The parts you actually need to know

### The skeleton

A METAR is always the same groups in the same order — learn the order and you
can read any of them:

`TYPE · STATION · DAY/TIME Z · [AUTO/COR] · WIND · VIS · [RVR] · [WEATHER] · SKY · TEMP/DEW · ALTIMETER · [RMK …]`

Bracketed groups appear only when relevant.

### A worked example (US format)

```text
METAR KINK 121845Z 11012G18KT 15SM SKC 25/17 A3000 RMK AO2 SLP125
```

| Group            | Reads as                                                                 |
| ---------------- | ------------------------------------------------------------------------ |
| `METAR`          | routine hourly report (`SPECI` = special, off-schedule)                  |
| `KINK`           | station — ICAO location indicator (Winkler County, TX)                   |
| `121845Z`        | day **12**, **18:45 UTC** ("Z" = Zulu = UTC)                             |
| `11012G18KT`     | wind **from 110°**, **12 kt**, gusting **18 kt**                         |
| `15SM`           | visibility **15 statute miles**                                          |
| `SKC`            | **sky clear**, no cloud                                                  |
| `25/17`          | temperature **25 °C**, dew point **17 °C** (`M` prefix = minus)          |
| `A3000`          | altimeter **30.00 inHg** (decimal implied)                               |
| `RMK AO2 SLP125` | remarks: automated with precip sensor; sea-level pressure **1012.5 hPa** |

### Wind

- `dddssKT` — direction (**true** north, 3 digits) then speed; `G` adds a
  gust: `24018G30KT`. Direction is **magnetic** only when spoken (ATIS/tower).
- `00000KT` = **calm**. `VRB03KT` = direction **variable** (used when ≤ 6 kt).
- Direction varying ≥ 60° with wind > 6 kt → an extra group: `21015KT 180V250`.

### Visibility and RVR

- **US:** statute miles + `SM` — `10SM`, `1 1/2SM`, `1/2SM`, `M1/4SM`
  ("less than ¼").
- **ICAO:** metres — `9999` = 10 km +, `0800` = 800 m.
- **RVR** (added when visibility or ceiling is low): `R06/2000FT` = runway 06
  touchdown-zone RVR 2,000 ft; a trailing `U` / `D` / `N` = trend up / down /
  no change.

### Present weather — build it left to right

`[intensity][descriptor][phenomenon]`

**Intensity / proximity:** `-` light · *(none)* moderate · `+` heavy ·
`VC` in the **vicinity** (5–10 SM from the field, not at it)

| Descriptors | Precipitation | Obscurations | Other |
|---|---|---|---|
| `MI` shallow · `BC` patches · `PR` partial · `DR` low drifting · `BL` blowing · `SH` showers · `TS` thunderstorm · `FZ` freezing | `DZ` drizzle · `RA` rain · `SN` snow · `SG` snow grains · `PL` ice pellets · `GR` hail · `GS` small hail / snow pellets · `IC` ice crystals · `UP` unknown (auto) | `BR` mist (vis ⅝–6 SM) · `FG` fog (vis < ⅝ SM) · `HZ` haze · `FU` smoke · `DU` dust · `SA` sand · `VA` volcanic ash | `PO` dust/sand whirls · `SQ` squall · `FC` funnel cloud (`+FC` tornado) · `SS` / `DS` sand / dust storm |

> [!example] Decoding weather groups
> `-RA` light rain · `+TSRA` heavy thunderstorm with rain · `FZRA` freezing
> rain · `FZFG` freezing fog · `SHSN` snow showers · `VCTS` thunderstorm in
> the vicinity · `BLSN` blowing snow · `MIFG` shallow fog · `BR` mist ·
> `FG` fog

### Sky condition and ceiling

Cloud is reported by **eighths of the sky (oktas)** covered, lowest layer
first, height in **hundreds of feet above the station**:

| Code | Amount | Oktas |
|---|---|---|
| `FEW` | few | 1–2 |
| `SCT` | scattered | 3–4 |
| `BKN` | broken | 5–7 |
| `OVC` | overcast | 8 |

- `SKC` sky clear (manual) · `CLR` no cloud below 12,000 ft (automated) ·
  `VV004` sky obscured, **vertical visibility** 400 ft.
- Append `CB` (cumulonimbus) or `TCU` (towering cumulus): `BKN020CB`.
- Multiple layers stack: `SCT020 BKN030 OVC080`.

> [!tip] Ceiling
> The **ceiling** is the height of the **lowest `BKN`, `OVC`, or `VV` layer** —
> the lowest layer covering **more than half** the sky. In
> `FEW015 SCT025 BKN040` the ceiling is **4,000 ft**, even though there is
> cloud below it. `FEW` and `SCT` layers are never a ceiling.

### Temperature, dew point, altimeter

- `25/17` = **+25 / +17 °C**; `M06/M12` = **−6 / −12 °C**. Automated reports
  may drop the dew point. Exact tenths are in `RMK` (`T02500172`).
- Altimeter: **US `A3000`** = 30.00 inHg (decimal implied); **ICAO `Q1013`** =
  1013 hPa.

### Remarks (`RMK`)

| Remark | Meaning |
|---|---|
| `AO1` / `AO2` | automated station — **without** / **with** a precipitation sensor |
| `SLP125` | sea-level pressure **1012.5 hPa** (prefix 9 or 10 toward 1013, decimal before last digit) |
| `RAB35` / `RAE47` | rain **began** :35 / **ended** :47 past the hour |
| `PK WND 29045/1547` | **peak wind** 290° at 45 kt, at 15:47 |
| `WSHFT 1530` | **wind shift** at 1530Z |
| `PRESRR` / `PRESFR` | pressure **rising / falling rapidly** |
| `T02500172` | precise temp **25.0** / dew point **17.2 °C** (leading digit `1` = negative) |
| `10267 20144` | 6-hour **max 26.7 °C / min 14.4 °C** |
| `P0018` | **precipitation** in the last hour = 0.18 in |
| `COR` / `$` | corrected report / station needs maintenance |

### METAR vs SPECI

- **METAR** — routine, issued in the few minutes **before each hour**.
- **SPECI** — an unscheduled report when something crosses a threshold: a
  ceiling or visibility **category change**, a thunderstorm or tornado
  begins or ends, a significant **wind shift**, and so on.
- **`AUTO`** = fully automated, no human augmentation; **`COR`** = a correction
  to a previous report.

> [!note] ICAO vs US, in one example
> ```text
> METAR EGLL 010650Z 22012KT 9999 FEW018 SCT025 12/07 Q1013 NOSIG
> ```
> Metres not statute miles (`9999` = 10 km +), **`Q`** (hectopascals) not
> **`A`** (inHg), and a **trend** appended (`NOSIG` = no significant change in
> 2 h; also `BECMG`, `TEMPO`). `CAVOK` replaces the visibility / weather /
> cloud groups when all three are good (vis ≥ 10 km, no cloud below 5,000 ft or
> the MSA, no significant weather).

### The MET report family

| Product | What it is | Horizon |
|---|---|---|
| **METAR / SPECI** | *observed* surface conditions at an aerodrome | current |
| **PIREP** (`UA` routine / `UUA` urgent) | *observed* conditions from a **crew in flight** — cloud tops/bases, turbulence, icing, wind | current |
| **TAF** | *forecast* for an aerodrome, in METAR-like code with `FM` / `TEMPO` / `BECMG` / `PROB` change groups | 24–30 h |
| **Winds / Temps Aloft** (`FB`, formerly `FD`) | *forecast* wind and temperature at fixed levels over navaids/points | 6–24 h |
| **SIGMET** | warning of *en-route hazards* (thunderstorms, turbulence, ash, icing) | as issued |
| **AIRMET** | less-severe en-route hazards, mainly for low-level flight | as issued |

> [!example] PIREP — the test example decoded
> `UA /OV OKC-TUL /TM 1800 /FL120 /TP BE90 /SK BKN018-TOP055/OVC072-TOP089
> /TA M07 /WV 08021KT /TB LGT 055-072 /IC LGT-MOD RIME 072-089`
> Routine PIREP, on the OKC→TUL route, 1800Z, at **12,000 ft**, a Beech King
> Air: broken layer base 1,800 ft / tops 5,500 ft, overcast 7,200–8,900 ft,
> **−7 °C**, wind **080° / 21 kt**, **light turbulence** 5,500–7,200 ft,
> **light-to-moderate rime ice** 7,200–8,900 ft.

### TAF — the same code, forecast forward

A **TAF** uses the METAR groups (wind, vis, weather, sky) but for a **future
period**, with change groups layered on:

```text
TAF KOKC 051130Z 0512/0618 14008KT 5SM BR BKN030
     TEMPO 0513/0516 1 1/2SM BR
     FM051600 16010KT P6SM SKC
     BECMG 0522/0524 20013G20KT 4SM SHRA OVC020
     PROB40 0600/0604 2SM TSRA OVC008CB
     FM060400 21015G25KT P6SM SCT040
```

| Element | Reads as |
|---|---|
| `051130Z` | issued 5th at 11:30Z |
| `0512/0618` | valid 5th 12:00Z → 6th 18:00Z (**30 h**) |
| *(base line)* | 140°/8 kt, 5 SM mist, broken 3,000 ft |
| `TEMPO 0513/0516` | **temporary** dips (come-and-go, < 1 h each) 13–16Z: vis 1½ SM in mist |
| `FM051600` | **from** 16:00Z a rapid, lasting change: 160°/10, 6 SM +, sky clear |
| `BECMG 0522/0524` | conditions **become** (transition over that window) 200°/13G20, 4 SM showers, overcast 2,000 |
| `PROB40 0600/0604` | **40 % probability** 00–04Z of 2 SM thunderstorm/rain, overcast 800 ft CB |
| `FM060400` | from 04:00Z: 210°/15G25, 6 SM +, scattered 4,000 |

`P6SM` = "more than 6 SM". Only `PROB30` / `PROB40` are used (a 50 %+ chance
just goes in the forecast).

### Winds and temperatures aloft (`FB`)

- Direction in tens of degrees + speed in knots, then a signed **temperature**
  (°C) at higher levels: `0507` = **050° / 7 kt** (no temp near the station);
  `2712-04` = **270° / 12 kt, −4 °C**.
- No wind/temp is forecast for a level within ~1,500 ft of the station, and no
  temperature within ~2,500 ft. Above ~24,000 ft the temperature is always
  negative, so the minus sign is **dropped** (`241960` = 240° / 19 kt, −60 °C).
- **Strong wind:** if the coded direction is **51–86**, subtract 50 from the
  direction and add 100 to the speed. `730649` at 30,000 ft = **230° / 106 kt,
  −49 °C**. `9900` = light and variable (< 5 kt); 100–199 kt uses this trick,
  199 kt means "199 or more".

### The digital future: IWXXM

The traditional alphanumeric code is being complemented, then replaced for
system-to-system exchange, by **IWXXM** — an XML/GML representation of
METAR/TAF/SIGMET, and a sister exchange model to [[21 — AIXM|AIXM]] and [[23 — FIXM|FIXM]] for
[[26 — SWIM|SWIM]]. (New editions of ICAO Annex 3 and the first PANS-MET became
applicable in late 2025.)

## How it connects to the rest

METAR is distributed over [[24 — AMHS|AMHS]] as "OPMET" data, bundled into the [[17 — PIB|PIB]],
shown on [[03 — ATC|ATC]] displays, and — as IWXXM — is a key early [[26 — SWIM|SWIM]] service.

## Jargon buster

| Term | Plain meaning |
|---|---|
| METAR | Meteorological Aerodrome Report |
| SPECI | A special, off-schedule report when conditions change |
| TAF | Terminal Aerodrome Forecast |
| PIREP | Pilot Report — weather observed from an aircraft (`UA` routine, `UUA` urgent) |
| FB / FD | Winds and Temperatures Aloft Forecast |
| SIGMET / AIRMET | Significant / Airmen's Meteorological Information (en-route hazards) |
| OPMET | Operational Meteorological data (the category METARs travel in) |
| okta | one eighth of the sky — the unit for `FEW`/`SCT`/`BKN`/`OVC` |
| ceiling | height of the lowest `BKN`/`OVC`/`VV` layer |
| RVR | Runway Visual Range — measured visibility down a specific runway |
| AUTO / AO2 | fully automated report / automated station with a precipitation sensor |
| SLP | Sea-Level Pressure, given in remarks to 0.1 hPa |
| QNH | The pressure setting that makes the altimeter read height above sea level |
| CAVOK | "Ceiling And Visibility OK" |
| Z / Zulu | UTC — all report times are in UTC |

## Learn more

**Start here (beginner-friendly)**
- GlobeAir — *Meteorological Aerodrome Report (METAR)*: <https://www.globeair.com/g/meteorological-aerodrome-report-metar>
- SKYbrary — *Meteorological Aerodrome Report (METAR)*: <https://skybrary.aero/articles/meteorological-aerodrome-report-metar>
- FAA — *Pilot's Handbook of Aeronautical Knowledge*, Ch. 13 *Aviation Weather Services*: <https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/phak>
- NOAA Aviation Weather Center (live METARs + decoder): <https://aviationweather.gov/>

**Decoding reference (the raw-format detail)**
- FAA — *AC 00-45 Aviation Weather Services* (the canonical METAR/TAF/PIREP/FB decode): <https://www.faa.gov/regulations_policies/advisory_circulars/index.cfm/go/document.information/documentID/1041288>
- NWS — *Aviation Weather Center: METAR/TAF codes*: <https://aviationweather.gov/data/metar/>

**Go deeper (the official sources)**
- ICAO Annex 3 — *Meteorological Service for International Air Navigation*: <https://www.icao.int>
- ICAO Doc 10157 — *PANS-MET*: <https://www.icao.int>
- WMO — *Manual on Codes (WMO-No. 306), Volume I.1*: <https://library.wmo.int/records/item/35713-manual-on-codes-volume-i-1-international-codes>
- WMO — *IWXXM*: <https://community.wmo.int/iwxxm>
