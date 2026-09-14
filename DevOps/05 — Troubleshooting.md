---
tags: [devops, troubleshooting, kubernetes, podman, jenkins, argocd, runbook]
parent: "[[00 — CI-CD Master Guide]]"
---

# Troubleshooting

> [!abstract] Method first, lookup second
> Diagnose **outside-in along the request path**, and collect *every* fault
> before fixing any of them — faults mask each other, and fixing one at a time
> makes you re-diagnose from scratch after each.

```
you ─▶ DNS ─▶ Ingress ─▶ Service ─▶ Endpoints ─▶ Pod ─▶ container ─▶ app
                                                   ▲
                            kubelet ─▶ containerd ─▶ registry ─▶ image:tag
                                                   ▲
                                    ArgoCD ─▶ git (config repo)
```

## The fixed sequence

1. `kubectl get pods -n NS -o wide` — **STATUS names the layer.**
2. `kubectl describe pod POD -n NS` — the **Events** block is the single
   highest-value output in Kubernetes. Read the *exact* image string, the
   *exact* probe path and port.
3. `kubectl logs POD -n NS` / `--previous` — what port did the app say it bound?
4. `kubectl get endpoints -n NS` — `<none>` means selector mismatch **or** no
   pod is Ready.
5. `kubectl get svc -o yaml` — `targetPort` vs the real `containerPort`.
6. `kubectl get ingress -o yaml` — class set? host right? Then
   `curl -H "Host: …" http://NODE-IP/health` to test routing without DNS.
7. Node / registry — reproduce the pull with `crictl pull`.
8. ArgoCD — `.status.conditions` holds the real error text.

> [!important] Three rules
> - **One change at a time**, then re-observe.
> - **Every fix goes in git**, not `kubectl edit` — `selfHeal` reverts you.
> - **Write the finding down** before moving on. You will forget fault #3 while
>   deep in fault #9.

---

## Podman

| Symptom | Cause | Fix |
|---|---|---|
| `curl: (56) Recv failure` on `localhost` | rootless `pasta` forwards IPv4 only; `localhost` → `::1`. Dual-bind and slirp4netns **both tested, neither helps** | bind `-p 127.0.0.1:PORT:PORT` and curl `127.0.0.1` |
| `HEALTHCHECK … will be ignored` | OCI format has no HEALTHCHECK; it is only a **warning**, so the build stays green | `--format docker`, and run `make verify` to fail the build when it is missing |
| `uid 1001 is greater than SYS_UID_MAX` | `useradd --system` with a high uid | drop `--system` |
| `permission denied` on a bind mount | uid mapping / SELinux | `-v ./d:/d:U,Z` |
| `cannot bind to port 80` | unprivileged port floor | `sysctl net.ipv4.ip_unprivileged_port_start=80` |
| `no subuid ranges found` | user lacks namespace ranges | `sudo usermod --add-subuids 200000-265535 --add-subgids 200000-265535 USER` |
| Logs empty until exit | Python buffering | `ENV PYTHONUNBUFFERED=1` |
| Container ignores `podman stop` | shell-form `CMD` swallows SIGTERM | exec form: `CMD ["a","b"]` |
| Rebuild reinstalls all deps | source copied before `requirements.txt` | copy requirements alone first |

---

## Jenkins

| Symptom | Cause | Fix |
|---|---|---|
| Stage green but nothing ran | multi-line `sh` without `-e` | `set -eux` at the top of every `sh` |
| Trigger never fires | Jenkins must read the Jenkinsfile once to learn it exists | run one build manually |
| `command not found` | `jenkins` user's `PATH` ≠ yours | absolute path, or set it in `environment` |
| Podman fails only under Jenkins | no subuid/subgid or `XDG_RUNTIME_DIR` for `jenkins` | `usermod --add-subuids`, `loginctl enable-linger jenkins` |
| Secret visible in the build log | double-quoted `sh` block interpolated it | single-quote the `sh` body |
| `docker login` in `ps` output | `-p "$PASS"` | `--password-stdin` |
| Tag contains a newline | missing `.trim()` on `returnStdout` | `.trim()` |
| State lost after a workspace wipe | artifacts kept in the workspace | store under `/var/lib/jenkins/…` |
| Two builds corrupt each other | concurrent runs share state | `disableConcurrentBuilds()` |

---

## Registry and image pull

| Error in `describe` | Cause | Fix |
|---|---|---|
| `Back-off pulling image "localhost:5000/…"` | `localhost` on a node means *that node* | use a reachable registry host |
| `manifest unknown` / `not found` | tag was never pushed | `podman search --list-tags …`; push it |
| `http: server gave HTTP response to HTTPS client` | containerd assumes HTTPS | see below |
| `x509: certificate signed by unknown authority` | untrusted CA | add `ca_file`, or use insecure |
| `unauthorized: authentication required` | private repo, no pull secret | `kubectl create secret docker-registry …` + `imagePullSecrets` |

> [!bug] k3s insecure registry — edit the source, not the generated file
> `/etc/rancher/k3s/registries.yaml`:
> ```yaml
> mirrors:
>   "192.168.122.1:5000":
>     endpoint: ["http://192.168.122.1:5000"]
> configs:
>   "192.168.122.1:5000":
>     tls:
>       insecure_skip_verify: true
> ```
> ```bash
> sudo systemctl restart k3s        # k3s-agent on workers
> ```
> Editing `/var/lib/rancher/k3s/agent/etc/containerd/certs.d/…/hosts.toml`
> directly does **nothing** — k3s regenerates it from `registries.yaml` on every
> restart. *(Docker Hub over HTTPS avoids all of this.)*

Reproduce the pull on the node itself:

```bash
ssh hans@192.168.122.50 'sudo crictl pull docker.io/sylthecatto/wings-portal:v1.0.0'
```

---

## Kubernetes

| Symptom | Cause | Fix |
|---|---|---|
| `Endpoints: <none>`, pods Running | Service selector ≠ pod labels | compare `get svc -o yaml` with `get pods --show-labels` |
| `Endpoints: <none>`, pods `0/1` | readiness failing | `describe` → probe path/port |
| `Liveness probe failed: 404` | wrong path | match the route the app serves |
| `Readiness probe failed: connection refused` | probe port ≠ listen port | align `containerPort`, `targetPort`, probe port, `PORT` env |
| Restarts climbing, logs fine | `initialDelaySeconds` too low | raise it, or add a `startupProbe` |
| `lastState.reason: OOMKilled` (exit 137) | memory limit below peak | raise `limits.memory` to ~2× peak |
| `Pending`: `Insufficient memory` | requests exceed node capacity | lower requests |
| `Pending`: `didn't match pod topology spread` | `DoNotSchedule` on one node | `whenUnsatisfiable: ScheduleAnyway` |
| Ingress does nothing, no Traefik log | `ingressClassName` missing | `ingressClassName: traefik` |
| Host resolves nowhere | `.local` needs `/etc/hosts` everywhere | use `<name>.<ip>.nip.io` |
| `CreateContainerConfigError` | ConfigMap/Secret referenced but absent | `describe` names the missing key |
| App unreachable, logs look healthy | bound to `127.0.0.1` inside the container | bind `0.0.0.0` |
| `spec.selector` edit rejected | it is immutable | delete and recreate the Deployment |

Confirm an OOM kill:

```bash
kubectl get pod POD -n NS -o jsonpath='{.status.containerStatuses[0].lastState}'
kubectl top pod -n NS
```

---

## ArgoCD

| Condition | Cause | Fix |
|---|---|---|
| `ComparisonError: 'Kind' is missing` | `path` contains non-manifest files | point at a manifests-only repo/path |
| `Sync: Unknown` | could not render git at all | read `.status.conditions` — usually the above |
| `SharedResourceWarning` | two Applications own one object | separate namespaces + `namePrefix` per env |
| `namespaces "x" not found` | destination namespace absent | `syncOptions: [CreateNamespace=true]` |
| Live edit reverts in ~30s | `selfHeal: true` | change git, not the cluster |
| Deleted manifest still running | `prune` is off | `prune: true` |
| Permanently `OutOfSync` on a field you never set | a webhook mutates it | `ignoreDifferences` |
| App deleted, workloads remain | no finalizer | add `resources-finalizer.argocd.argoproj.io` |
| `OutOfSync` right after a CI push | expected — that is the handoff | wait, or `argocd app sync` |

```bash
kubectl -n argocd get app APP \
  -o jsonpath='{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}'
argocd app diff APP
```

---

## Full triage command set

```bash
# PODS
kubectl get pods -n NS -o wide
kubectl get pods -n NS --show-labels
kubectl describe pod POD -n NS | sed -n '/Events:/,$p'
kubectl logs POD -n NS --previous
kubectl get pod POD -n NS -o jsonpath='{.status.containerStatuses[0].lastState}'
kubectl top pod -n NS

# SERVICE / ENDPOINTS
kubectl get svc,endpoints -n NS
kubectl run t --rm -it --image=busybox --restart=Never -- \
  wget -qO- http://SVC.NS.svc.cluster.local/health

# INGRESS
kubectl get ingress -n NS -o yaml
kubectl -n kube-system logs deploy/traefik | tail
curl -H "Host: THE-HOST" http://NODE-IP/health

# NODE / REGISTRY
ssh hans@192.168.122.50 'sudo cat /etc/rancher/k3s/registries.yaml'
ssh hans@192.168.122.50 'sudo crictl images; sudo crictl pull IMAGE'

# ARGOCD
argocd app get APP; argocd app diff APP; argocd app history APP

# PODMAN
podman logs -f CTR; podman inspect IMG; podman history IMG; podman system df

# JENKINS
sudo journalctl -u jenkins -f
```

---

See also: [[00 — CI-CD Master Guide]] · [[01 — Podman]] · [[02 — Jenkins]] · [[03 — Kubernetes]] · [[04 — ArgoCD]]
