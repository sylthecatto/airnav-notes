---
tags:
  - gis
  - geoserver
  - ops
created: 2026-09-09
---

# 02 — Install and Run

> [!abstract] The 30-second version
> Three ways to run it: the **platform-independent binary** (bundled Jetty —
> fastest to try), a **WAR** deployed into **Tomcat** (the classic
> production layout on RHEL), or the **Docker image** (`docker.osgeo.org/geoserver`).
> Whichever you pick, the thing that matters is the **data directory** — an
> external folder holding all configuration. First login is
> **`admin` / `geoserver`** — change it immediately.

## The three deployment options

| Option | What it is | Use for |
|---|---|---|
| **Binary** (`geoserver-*-bin.zip`) | GeoServer + an embedded Jetty; `bin/startup.sh` | learning, a dev box |
| **WAR** (`geoserver-*-war.zip`) | `geoserver.war` you drop in Tomcat/`webapps` | the standard RHEL production setup, alongside a managed Tomcat + JVM |
| **Docker** (`docker.osgeo.org/geoserver:<version>`) | official image, config via env vars + a mounted data dir volume | containers / Kubernetes; reproducible; easy version pinning |

> [!tip] Version scheme
> GeoServer releases as `2.<minor>.<patch>` roughly quarterly. Each minor line
> gets patches for ~6 months. **Match GeoServer and its extensions to the exact
> same version** — mixing versions breaks it. Grab extensions as separate
> `.zip`s and unzip the jars into `WEB-INF/lib`.

## The data directory — the one concept to internalise

`GEOSERVER_DATA_DIR` is an **external folder** that holds:

```
<data_dir>/
├── global.xml, logging.xml            server-wide settings
├── security/                          users, roles, service/data rules, keystores
├── workspaces/<ws>/<store>/…          every workspace, store, layer, as XML
├── styles/                            SLD/CSS files + their .xml metadata
├── gwc/                               tile-cache config
├── data/                              (optional) file data shipped with it
└── logs/
```

- It is the **entire state** of the server. Everything you click in the admin
  UI writes a file here.
- **Always set it explicitly and put it *outside* the webapp** (env var
  `GEOSERVER_DATA_DIR=/var/opt/geoserver/data`), so a redeploy/upgrade can't
  wipe your config.
- **Backup = tar the data directory** (see [[10 — REST API and Config-as-Code]]
  for the proper Backup/Restore extension).
- The default bundled data dir is full of **sample layers and demos** — remove
  those in production ([[12 — Hardening and the CVE Track]]).

## Production layout on RHEL (typical)

```
RHEL host
├── OpenJDK 17 (or 11 for older GeoServer)      dnf install java-17-openjdk-headless
├── Apache Tomcat 9/10  →  systemd service, runs as user `tomcat` (non-root)
│     └── webapps/geoserver.war
├── GEOSERVER_DATA_DIR=/var/opt/geoserver/data   (chown tomcat, mode 750)
├── nginx / httpd  →  reverse proxy, TLS termination, path /geoserver
└── PostgreSQL + PostGIS  (same host or separate)
```

Set JVM options in Tomcat's `setenv.sh`:

```
export JAVA_OPTS="-Xms2g -Xmx4g -XX:+UseG1GC \
  -DGEOSERVER_DATA_DIR=/var/opt/geoserver/data \
  -Dorg.geotools.referencing.forceXY=true \
  -DGEOSERVER_CONSOLE_DISABLED=false"
```

(`-Xmx` sizing and GC live in [[13 — Production and Ops]].)

## First-run checklist

1. Browse to `http://host:8080/geoserver/web/` → log in `admin` / `geoserver`.
2. **Change the admin password** (Security → Users) — and the **master
   password**.
3. Set **Proxy Base URL** (Global Settings) to the public URL, so Capabilities
   documents advertise the right links behind the proxy.
4. Delete the sample workspaces (`topp`, `sf`, `tiger`, `nurc`, `cite`) and the
   sample styles.
5. Set **Global Services** you don't need to *off*; set service level to
   **Basic** ([[12 — Hardening and the CVE Track]]).
6. Note the version (bottom of the page / `web/`) — you'll compare it to the
   [security advisories](https://geoserver.org/vulnerability/).

## Docker quick form

```
docker run -d --name geoserver -p 8080:8080 \
  -e GEOSERVER_ADMIN_PASSWORD='<strong>' \
  -e SKIP_DEMO_DATA=true \
  -e INSTALL_EXTENSIONS=true -e STABLE_EXTENSIONS='app-schema,importer,control-flow' \
  -v /srv/geoserver_data:/opt/geoserver_data \
  docker.osgeo.org/geoserver:2.27.0
```

## Sources

- GeoServer — *Installation*: <https://docs.geoserver.org/latest/en/user/installation/index.html>
- GeoServer — *Data Directory*: <https://docs.geoserver.org/latest/en/user/datadirectory/index.html>
- GeoServer — *Docker*: <https://docs.geoserver.org/latest/en/user/installation/docker.html>
- Official Docker image: <https://github.com/geoserver/docker>
