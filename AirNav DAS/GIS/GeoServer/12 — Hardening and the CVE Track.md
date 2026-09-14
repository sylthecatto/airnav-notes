---
tags:
  - gis
  - geoserver
  - security
  - cve
created: 2026-09-09
---

# 12 — Hardening and the CVE Track

> [!abstract] The 30-second version
> GeoServer is a **recurring high-severity target** — several CVSS 9.8 RCEs,
> multiple in **CISA KEV**, all reachable through ordinary OGC request
> parameters. If your team runs it for a client, it's a machine **you patch
> and harden** — the same job as `CVEs/`. This note is the production
> hardening checklist plus GeoServer's CVE history and what it teaches.

## Why GeoServer keeps getting popped

The dangerous surface is **user input that reaches an evaluator**:

| Input | Reaches | Example CVE |
|---|---|---|
| **property name** in a WFS/WMS request | XPath / jxpath eval | **CVE-2024-36401** — RCE, CVSS **9.8**, **in CISA KEV**, mass-exploited |
| **CQL / OGC filter** | SQL, on PostGIS/other JDBC stores | **CVE-2023-25157** — SQLi, CVSS **9.8** (companion **CVE-2023-25158** in GeoTools). *Not* in KEV, but PoCs are public |
| **SLD / WPS Jiffle script** | a scripting engine (`jt-jiffle` in **JAI-EXT**) | **CVE-2022-24816** — RCE, CVSS **9.8**, **in CISA KEV** |
| **XML request body** | entity resolution | **CVE-2024-34711** (SSRF), older XXE |
| **demo / test endpoints** | outbound HTTP | **CVE-2024-29198**, **CVE-2021-40822** (SSRF via `TestWfsPost`) |
| **REST endpoints** | file system / config | **CVE-2023-51444** (file upload), **CVE-2025-27505** (missing authz on `/rest`) |

Root causes usually live in **GeoTools / JAI-EXT / commons-jxpath**, not
GeoServer's own code — so a GeoServer patch = a bump of those libs. (Confirm any
CVE's KEV/EPSS status yourself at triage time — this table is a snapshot.)

## CVE-2024-36401 — the one to understand

- **What:** unauthenticated RCE. GeoTools (the underlying `GHSA` is
  **CVE-2024-36404**) passed feature-type **property names** unsafely to
  `commons-jxpath`, which evaluates XPath — and jxpath can execute Java.
  CVSS **9.8** (`AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`).
- **Affects *every* GeoServer**, not only complex-feature ones — the unsafe
  path runs for simple feature types too.
- **Reachable via:** WFS `GetFeature`, WFS `GetPropertyValue`, WMS `GetMap`,
  WMS `GetFeatureInfo`, WMS `GetLegendGraphic`, WPS `Execute` — the normal API,
  no auth.
- **Affected / fixed:** vulnerable `2.24.0–<2.24.4`, `2.25.0–<2.25.2`,
  `2.23.0–<2.23.6`, and everything `<2.22.6`. **Fixed in 2.24.4 / 2.25.2 /
  2.23.6 / 2.22.6.** Added to **CISA KEV**; mass-exploited within weeks
  (cryptominers, webshells, botnets).
- **The workaround trap:** you *can* delete `gt-complex-<ver>.jar` to strip the
  vulnerable path — **but that breaks [[08 — App-Schema and Complex Features|app-schema]]**
  (and CSW, and the MongoDB store), which is exactly what an AIXM deployment
  needs. So for your team's use case, **patching was the only option**. The
  lesson: know which mitigations your architecture forecloses *before* the
  incident.

> [!example] How this would land on your desk
> NCSC / vendor advisory drops → check `GET /geoserver/web/` or
> `/rest/about/version` for the version → compare to fixed releases →
> it's in **KEV**, **EPSS** high, internet-reachable, `gt-complex` in use →
> **emergency change**: patch to the fixed minor, restart Tomcat, verify
> version, check logs for prior exploitation (`GeoServer.log`, access logs for
> odd `propertyName=` / `exec(` payloads). Document per your workflow
> ([[08 — Reviewing a CVE Advisory]]).

## Production hardening checklist

**Identity & access**
- [ ] Change `admin` **and** master passwords; delete default/sample accounts.
- [ ] Admin console **not internet-facing** — proxy allow-list by IP, or an
      internal-only vhost.
- [ ] HTTPS only; `Secure` + `HttpOnly` session cookies; set **Proxy Base URL**.
- [ ] Own roles; `ROLE_ANONYMOUS` gets nothing beyond intended public layers;
      data rule default `*.*.r=ROLE_AUTHENTICATED`, `mode=HIDE` ([[11 — Security Model]]).
- [ ] REST writes = `ROLE_ADMINISTRATOR` only.

**Surface reduction**
- [ ] Disable unused services (WCS, WPS, WMS-1.1 if not needed); WFS
      **service level = Basic** (no transactions) unless WFS-T is required.
- [ ] **Do not install WPS** unless a use case demands it.
- [ ] Remove sample data / demo workspaces; disable the **Demo requests**,
      **Layer preview** and **GWC home** pages in production
      (`GEOSERVER_CONSOLE_DISABLED` for console, config flags for demos).
- [ ] Enable the **security sandbox** (file + script) — restrict `file://`,
      external graphics, scripting reach.
- [ ] `ENTITY_RESOLUTION_ALLOWLIST` set tight (XXE/SSRF hardening).

**Data layer**
- [ ] PostGIS via a **read-only** DB role; `preparedStatements=true`
      ([[04 — Connecting Data]]).
- [ ] Turn off WFS Transaction at the DB and service level if not used.

**Platform**
- [ ] Run Tomcat as a **non-root** service user; data dir `750`, owned by it.
- [ ] Reverse proxy: rate-limit, size-limit request bodies, block
      `/geoserver/web/` and `/rest/` from the public path if only OGC is public.
- [ ] Install **Control Flow** (throttle concurrent/per-IP requests) and
      **Monitoring** (audit) extensions.
- [ ] Central logging; ship `GeoServer.log` + access logs to the SIEM.

**Patching**
- [ ] Track the installed version; subscribe to the GeoServer
      **security announcements**.
- [ ] Patch cadence: **security releases immediately**, minor releases on a
      schedule. Extensions must match the core version exactly.
- [ ] After patching: confirm version, smoke-test a `GetMap` + `GetFeature`,
      re-run any app-schema check ([[09 — Serving AIXM]]).

## Where this connects

- Feeds into your `Roadmap.md` **Track 1** (vuln management) and **Track 3**
  (aviation cyber — a GeoServer serving a client ANSP is in scope for
  **ED-205A** ground-system security certification and **EASA Part-IS**).
- The triage workflow is the same as [[08 — Reviewing a CVE Advisory]];
  the CVSS decode is [[05 — CVSS v3.1 Metrics]] / [[06 — CVSS v4.0 Metrics]];
  KEV/EPSS is [[07 — Beyond CVSS — CWE, KEV & EPSS]].

## Sources

- GeoServer — *Running in a production environment*: <https://docs.geoserver.org/latest/en/user/production/index.html>
- GeoServer — *Security advisories*: <https://geoserver.org/security/> · <https://geoserver.org/vulnerability/>
- CVE-2024-36401 advisory: <https://geoserver.org/vulnerability/2024/09/12/cve-2024-36401.html>
- GitHub Advisory Database — GeoServer: <https://github.com/advisories?query=geoserver>
- CISA KEV: <https://www.cisa.gov/known-exploited-vulnerabilities-catalog>
