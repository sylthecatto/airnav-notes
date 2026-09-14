---
tags:
  - gis
  - geoserver
  - reference
created: 2026-09-09
---

# 14 — Learning Resources

> [!abstract] The 30-second version
> The **official user manual** is genuinely good and the primary source.
> **GeoSolutions' free training modules** are the best structured course.
> For the AIXM job specifically, pair the **app-schema docs** with the
> **HALE / Complex Features** module. There's no polished "GeoServer for
> aviation" course — you assemble it.

## Official (start here)

| Resource | What |
|---|---|
| **GeoServer User Manual** | the reference — install, data, services, styling, security, production. Read the sections matching notes 02–13. <https://docs.geoserver.org/latest/en/user/> |
| **GeoServer REST API reference** (OpenAPI) | every endpoint <https://docs.geoserver.org/latest/en/api/> |
| **geoserver.org** | downloads, the **blog** (release notes, deep-dives), **security advisories** <https://geoserver.org> |
| **Developer manual** — *Security Procedure* | how the project handles CVEs (useful context for [[12 — Hardening and the CVE Track]]) <https://docs.geoserver.org/latest/en/developer/policies/security.html> |

## Structured training (free)

| Resource | What |
|---|---|
| **GeoSolutions — GeoServer Training** | the 3–4 day course, online: first steps → styling → security → production → performance. Written by core devs. <https://geoserver.geosolutionsgroup.com/edu/en/> |
| — *Complex Features with GeoServer and HALE* | the module for the AIXM/app-schema path <https://geoserver.geosolutionsgroup.com/edu/en/complex_features/index.html> |
| **geoserver.org/tutorials** | short focused walk-throughs (video + text) <https://geoserver.org/tutorials/> |
| **GeoSolutions blog** | practical write-ups on tuning, styling, security |

## Books

- *GeoServer Beginner's Guide* (Packt) — dated but the concepts hold.
- *Mastering GeoServer* (Packt) — production, security, clustering.
- *GeoServer Cookbook* (Packt) — task recipes.
- *PostGIS in Action* — for the database half you'll lean on ([[04 — Connecting Data]]).

## The database & standards underneath

| Topic | Resource |
|---|---|
| **PostGIS** | manual <https://postgis.net/documentation/> · *Introduction to PostGIS* workshop <https://postgis.net/workshops/postgis-intro/> |
| **SLD / Symbology Encoding** | OGC standard <https://www.ogc.org/standards/se/> + the GeoServer SLD **cookbook** |
| **OGC services** | WMS/WFS/WCS/WMTS + OGC API specs <https://www.ogc.org/standards/> |
| **CQL / ECQL** | GeoServer filter reference <https://docs.geoserver.org/latest/en/user/filter/ecql_reference.html> |

## AIXM-specific

| Topic | Resource |
|---|---|
| AIXM spec + primer + XSDs | <https://aixm.aero> — and the AIXM GitHub (Donlon, XSLT) |
| AIXM Coding Guidelines (geometry, GML profile, temporality) | EUROCONTROL AIXM Confluence <https://ext.eurocontrol.int/aixm_confluence/> |
| GML Profile for Aviation | OGC 12-028r1 |
| EUROCONTROL **IM-AIXM** e-learning | the modelling course (you're registered) — see [[08 — Learning QGIS\|QGIS 08]] and `Roadmap.md` |
| hale studio | <https://www.wetransform.to/products/halestudio/> + its docs |

## Communities

- GeoServer users mailing list / the OSGeo Discourse.
- `gis.stackexchange.com` `[geoserver]` tag.
- The GeoServer GitHub issues (and the security advisories there).

## A learning order for you

1. Notes **01–07** here + skim the matching User Manual sections.
2. Stand up GeoServer + PostGIS ([[02 — Install and Run]], [[04 — Connecting Data]])
   and publish the Donlon GeoPackage as WMS/WFS — verify in QGIS as a client.
3. Style it in QGIS, export SLD, clean it, load it in GeoServer
   ([[06 — Styling — SLD and CSS]]).
4. GeoSolutions **training** modules 1–5.
5. **app-schema**: the GeoServer tutorial (GeoSciML), then the HALE module,
   then [[09 — Serving AIXM]] against Donlon.
6. **Harden it** ([[11 — Security Model]], [[12 — Hardening and the CVE Track]])
   and script the whole build ([[10 — REST API and Config-as-Code]]).

## Sources

- GeoServer docs: <https://docs.geoserver.org/>
- GeoSolutions training: <https://geoserver.geosolutionsgroup.com/edu/en/>
- geoserver.org: <https://geoserver.org>
