---
tags: [devops, podman, containers, oci, containerfile]
parent: "[[00 — CI-CD Master Guide]]"
docs: https://docs.podman.io/en/latest/
---

# Podman

> [!abstract] Daemonless, rootless, and pod-native
> Podman runs containers as **child processes of your shell**, not as children
> of a root daemon. No `dockerd`, no socket, no `docker` group. `podman` is
> otherwise CLI-compatible with `docker` — `alias docker=podman` works for
> almost everything.

---

## Podman vs Docker — what actually differs

| | Docker | Podman |
|---|---|---|
| Architecture | client → **root daemon** → containers | client **forks** containers directly |
| Runs as | daemon is root | your uid (rootless by default) |
| `docker` group | = passwordless root on the host | no equivalent needed |
| Default image format | Docker v2 | **OCI** |
| Build file | `Dockerfile` | `Containerfile` (reads either) |
| Compose | built in | `podman-compose`, or Kubernetes YAML |
| systemd | awkward | first-class (`podman generate systemd`, Quadlet) |
| Pods | ✗ | ✓ native, same concept as Kubernetes |

> [!bug] The default-format difference bites immediately
> OCI has no `HEALTHCHECK` instruction. Build without `--format docker` and
> Podman **warns and drops it** — the build still succeeds:
> ```
> level=warning msg="HEALTHCHECK is not supported for OCI image format and will be ignored. Must use `docker` format"
> ```

---

## The Containerfile line by line

Annotating `~/Documents/wings-portal/Containerfile`.

### Stage 1 — builder

```dockerfile
FROM python:3.12-slim AS builder
```
`AS builder` names the stage so stage 2 can copy from it. `-slim` is Debian
minus the toolchain docs and extras — ~80 MB smaller than the default tag.

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
```
- `DONTWRITEBYTECODE` — `.pyc` files bloat layers and are never reused.
- `UNBUFFERED` — **the important one.** Python buffers stdout when it is not a
  TTY, so without this your logs appear only when the process exits.
  `podman logs` and `kubectl logs` would show nothing during a hang.

```dockerfile
COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt
```
Requirements copied **alone**, so this layer's cache key is that file only.
`--no-cache-dir` stops pip writing ~50 MB of wheels into the layer.

### Stage 2 — runtime

```dockerfile
FROM python:3.12-slim AS runtime
ARG APP_VERSION=0.0.0-dev
ARG GIT_SHA=local
ENV APP_VERSION=${APP_VERSION} GIT_SHA=${GIT_SHA}
```

> [!important] ARG vs ENV
> | | `ARG` | `ENV` |
> |---|---|---|
> | Available | build time only | build **and** run time |
> | Set by | `--build-arg` | `-e` / manifest |
> | In `podman inspect` | no | yes |
>
> The app reads `os.environ`, so the ARG must be promoted to an ENV. `ARG` alone
> and the value silently vanishes at runtime.
>
> **Never put a secret in either.** Both are readable in image metadata and in
> every layer. Use a mounted file or a Kubernetes Secret.

```dockerfile
RUN groupadd --gid 1001 appuser && \
    useradd --uid 1001 --gid 1001 --no-create-home --shell /usr/sbin/nologin appuser
```

> [!bug] Why not `--system`
> `useradd --system --uid 1001` warns
> `appuser's uid 1001 is greater than SYS_UID_MAX 999`. System accounts live
> below 1000; Kubernetes' `runAsNonRoot` convention wants ≥1000. Drop
> `--system` and keep the high uid. Hit and fixed during this build.

```dockerfile
COPY --from=builder /opt/venv /opt/venv
COPY --chown=appuser:appuser app/ ./app/
USER appuser
```
`--from=builder` is the multi-stage payoff — only the venv crosses over.
`--chown` at copy time avoids a second `RUN chown` layer that would duplicate
every file.

```dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", \
     "--access-logfile", "-", "--error-logfile", "-", "app.main:app"]
```
- **Exec form** → gunicorn is PID 1 and receives `SIGTERM`. Shell form would
  interpose `/bin/sh`, which swallows it.
- `0.0.0.0`, not `127.0.0.1` — binding to loopback *inside* the container makes
  it unreachable from outside, and this is a very common "the app is running
  but nothing connects" cause.
- `--access-logfile -` → logs to **stdout**, which is where container runtimes
  collect them. Never log to a file inside a container.

---

## Build, run, inspect

```bash
podman build --format docker -t wings-portal:1.0.0 -f Containerfile .
podman images
podman history wings-portal:1.0.0        # per-layer sizes — find the fat one
podman inspect wings-portal:1.0.0 --format '{{json .Config.Env}}' | python3 -m json.tool

podman run -d --name wp -p 8888:8080 -e APP_ENV=staging wings-portal:1.0.0
podman logs -f wp
podman exec -it wp /bin/bash
podman stats --no-stream                 # real memory use → sets your k8s limits
podman rm -f wp
```

> [!tip] `podman stats` is how you pick resource limits
> Run the container, exercise it, read the peak. Set the Kubernetes memory
> **limit above peak, not above average** — a limit is an instant kill
> threshold, and traffic spikes above steady state.

---

## Rootless: the parts that surprise people

> [!bug] `localhost` fails, `127.0.0.1` works — and you cannot fix it
> ```
> $ curl http://localhost:8888/health
> curl: (56) Recv failure: Connection reset by peer
> ```
> `getent ahosts localhost` returns `::1` first; the `pasta` backend forwards
> **IPv4 only**. Tested on this laptop:
>
> | Attempt | Outcome |
> |---|---|
> | `-p 9001:8080` (default) | listens `*:9001`, `localhost` fails, `127.0.0.1` → 200 |
> | `-p 127.0.0.1:9002:8080 -p '[::1]:9002:8080'` | **both** sockets listen; `curl -6 [::1]` still fails |
> | `--network slirp4netns` | both families fail |
>
> Bind explicitly to `127.0.0.1` and use it everywhere in scripts. Making the
> host address part of the command is the fix; making `localhost` work is not
> available.

**Ports below 1024** need a sysctl, because unprivileged processes cannot bind
them:

```bash
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
```

**Volume permissions** — your uid maps to a different uid inside the container.
Use `:U` to have Podman fix ownership, or `:Z` for SELinux relabelling (Fedora
needs this constantly):

```bash
podman run -v ./data:/data:U,Z myimage
```

**`subuid`/`subgid` ranges** must exist for the user running Podman. This is why
Jenkins needs the `usermod --add-subuids` step in
[[00 — CI-CD Master Guide#1.2 Jenkins]]:

```bash
grep "^$USER:" /etc/subuid /etc/subgid
```

---

## Pods — Podman's namesake

A **pod** is a group of containers sharing a network namespace. Identical
concept to Kubernetes, which is what makes it a good local rehearsal:

```bash
podman pod create --name web -p 8080:8080
podman run -d --pod web --name api  wings-portal:1.0.0
podman run -d --pod web --name side alpine sleep 1000
podman pod ps
```

Containers in a pod reach each other on **`localhost`** — exactly like sidecars
in Kubernetes.

> [!tip] Generate Kubernetes YAML from a running pod
> ```bash
> podman generate kube web > pod.yaml
> podman play kube pod.yaml           # and back again
> ```
> Good for scaffolding and for *seeing* the mapping. Not a substitute for the
> hand-written Deployment — it emits a bare Pod with no replicas, probes,
> resources or rollout strategy.

---

## Running as a systemd service

The modern route is **Quadlet** — a unit file that Podman expands at boot.

`~/.config/containers/systemd/portal.container`:

```ini
[Unit]
Description=WINGS Portal

[Container]
Image=docker.io/sylthecatto/wings-portal:v1.0.0
PublishPort=8080:8080
Environment=APP_ENV=production

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user start portal
loginctl enable-linger $USER     # survive logout
```

> [!note] `podman generate systemd` is deprecated
> It still works and you will see it in older docs and repos, but Quadlet is
> the supported path now. Worth knowing both names.

---

## Cleanup

```bash
podman ps -a
podman image prune -f            # dangling only
podman system prune -a --volumes # everything unused — destructive
podman system df                 # where the disk went
```

---

See also: [[00 — CI-CD Master Guide]] · [[03 — Kubernetes]] · [[05 — Troubleshooting]]
