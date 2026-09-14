---
tags:
  - gis
  - geoserver
  - ops
created: 2026-09-09
---

# 13 — Production and Ops

> [!abstract] The 30-second version
> Running GeoServer well is mostly **JVM tuning**, **request throttling**,
> **monitoring**, and a **disciplined upgrade path**. The data directory is the
> single unit of state — back it up, version it, and you can rebuild the server
> anywhere. Scale by adding stateless GeoServer nodes behind a load balancer,
> all pointed at the same config + database + tile cache.

## JVM and memory

GeoServer is a JVM app; most "it's slow / it fell over" is heap or GC.

```
-Xms2g -Xmx4g            # set equal-ish; 4–8g typical, more for heavy raster
-XX:+UseG1GC             # G1 is the sane default
-XX:+UseStringDeduplication
-Dfile.encoding=UTF-8
-Djava.awt.headless=true
-Dorg.geotools.referencing.forceXY=true
-DGEOSERVER_DATA_DIR=/var/opt/geoserver/data
```

- **Native JAI / ImageIO** speeds up raster + rendering — install if you serve
  coverages heavily.
- **Marlin renderer** is bundled and default in modern GeoServer (fast
  anti-aliased vector rendering).
- Watch: heap usage, GC pause time, PostGIS pool exhaustion, open file handles.

## Control Flow — protect the server from load

Install the **control-flow** extension, `controlflow.properties`:

```
ows.global=100          # max concurrent OWS requests
ows.wms.getmap=50       # ... of which GetMap
ows.wfs.getfeature=30
user=6                  # per-client (cookie/IP) concurrent
timeout=60              # seconds queued before 503
ows.gwc=1000
```

Without this, a burst of `GetMap`s (or an abusive client) pins every CPU and
everything times out.

## Monitoring & logging

| Tool | Gives you |
|---|---|
| **Monitoring extension** | per-request audit (who, what layer, bbox, bytes, ms, status) to a DB or files — feed to the SIEM |
| **`GeoServer.log`** (`logging.xml`) | app log; set a sane level (`PRODUCTION_LOGGING` profile), rotate, ship it |
| **`/rest/about/status`, `/about/system-status`** | modules loaded, memory, uptime — scrape for health checks |
| **Metrics** | JMX / Micrometer via the container; GeoServer Cloud exposes Prometheus |
| container access logs | the raw HTTP picture — essential for incident review ([[12 — Hardening and the CVE Track]]) |

Health check for a load balancer: `GET /geoserver/web/` or a cheap
`GetCapabilities`, expect 200 + a known string.

## Upgrades

1. **Read the release notes** for every version you skip — config migrations,
   removed modules, changed defaults.
2. Stage: copy the **data directory** to a test box, deploy the new WAR +
   **version-matched extensions**, start, check logs for migration messages.
3. Smoke test: `GetCapabilities` for each service, one `GetMap`, one
   `GetFeature`, app-schema `DescribeFeatureType` ([[09 — Serving AIXM]]).
4. Roll forward in prod; keep the previous WAR + a data-dir snapshot to roll
   back.
5. GeoServer data dirs are **forward-compatible, not backward** — a newer
   server upgrades the config in place; you can't then open it with the old
   one.

## Backup

- **Backup & Restore** extension for the catalog config
  ([[10 — REST API and Config-as-Code]]).
- **`tar`/snapshot the whole data directory** on a schedule as the
  belt-and-braces copy.
- Back up **PostGIS** separately (`pg_dump` / PITR) — it's the data of record.
- Back up the **GWC blob store** only if reseeding is expensive; otherwise just
  reseed.

## Scaling / HA

| Pattern | How |
|---|---|
| **Vertical** | bigger heap + native JAI + control-flow — goes a long way |
| **Tile-heavy** | put **GeoWebCache** (or a CDN) in front; most traffic never reaches rendering |
| **Horizontal (classic)** | N stateless GeoServer nodes, **shared** data dir (read-only or with the JMS **clustering** module for config sync), shared PostGIS, shared/S3 blob store, load balancer |
| **Cloud-native** | **GeoServer Cloud** — the services split into independently-scalable containers, config in a config service |

## Sources

- GeoServer — *Production*: <https://docs.geoserver.org/latest/en/user/production/index.html>
- GeoServer — *Control flow*: <https://docs.geoserver.org/latest/en/user/extensions/controlflow/index.html>
- GeoServer — *Monitoring*: <https://docs.geoserver.org/latest/en/user/extensions/monitoring/index.html>
- GeoServer — *Advanced logging* / *status*: <https://docs.geoserver.org/latest/en/user/logging.html>
- GeoServer Cloud: <https://geoserver.org/geoserver-cloud/>
