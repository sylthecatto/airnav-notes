---
tags: [devops, jenkins, cicd, pipeline, groovy]
parent: "[[00 — CI-CD Master Guide]]"
docs: https://www.jenkins.io/doc/
---

# Jenkins

> [!abstract] An automation server that runs a file from your repo
> Everything worth knowing is in the **Jenkinsfile** — a Groovy file committed
> alongside the code. The job in the UI is just a pointer to it. If your pipeline
> logic lives in the web UI instead, it is not reviewable, not versioned, and
> not restorable.

---

## Declarative vs scripted

Two syntaxes. Use **declarative** unless you have a specific reason not to.

| | Declarative | Scripted |
|---|---|---|
| Opens with | `pipeline { }` | `node { }` |
| Structure | fixed sections, validated early | arbitrary Groovy |
| Errors | caught before the build starts | at runtime, mid-build |
| `post`, `options`, `when` | built in | hand-rolled |
| Escape hatch | `script { }` block | n/a |

```groovy
pipeline {
  agent any
  stages {
    stage('Build') {
      steps {
        sh 'make'
        script {              // ← drop into scripted Groovy when you must
          env.TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        }
      }
    }
  }
}
```

> [!tip] `.trim()` is mandatory on `returnStdout`
> The captured string keeps its trailing newline. `"image:${env.TAG}"` without
> `.trim()` produces a tag with an embedded `\n`, and the push fails with a
> baffling error.

---

## Anatomy of the wings-portal Jenkinsfile

### `options`

```groovy
options {
  timestamps()
  timeout(time: 30, unit: 'MINUTES')
  disableConcurrentBuilds()
  buildDiscarder(logRotator(numToKeepStr: '20'))
}
```

| Option | Why |
|---|---|
| `timestamps()` | every log line gets a clock — you cannot diagnose a slow stage without it |
| `timeout` | a hung build holds an executor forever otherwise |
| `disableConcurrentBuilds()` | two builds pushing the same tag race in the registry; two Terraform runs corrupt state |
| `buildDiscarder` | build history is the top disk consumer on a lab Jenkins |

### `triggers`

```groovy
triggers { pollSCM('H/5 * * * *') }
```

`H` hashes the **job name** into the interval, so twenty jobs do not all hit
GitHub at `:00`. It is not "random" — it is stable per job.

> [!warning] The first build must be manual
> Jenkins only learns a declarative trigger exists by *reading the Jenkinsfile*,
> which only happens during a build. Run once by hand; polling arms itself
> afterwards. This is the single most common "my trigger doesn't work".

### `environment`

```groovy
environment {
  REGISTRY   = 'docker.io'
  IMAGE_REPO = "${REGISTRY}/sylthecatto/wings-portal"
}
```

Available to every stage as `${IMAGE_REPO}` in Groovy and `$IMAGE_REPO` inside
`sh`. Note `"..."` (double quotes) interpolates in Groovy; `'...'` does not.

### `post`

```groovy
post {
  always  { junit allowEmptyResults: true, testResults: 'pytest-report.xml' }
  success { echo "…" }
  failure { echo 'Check the first RED stage, not the last.' }
  cleanup { sh 'podman image prune -f || true' }
}
```

| Block | Runs when |
|---|---|
| `always` | every outcome — use for **artifacts and reports** |
| `success` / `failure` / `unstable` | that outcome only |
| `cleanup` | last, after everything, regardless |

> [!important] Archive in `always`, not `success`
> A failed build's test report is the one you actually need. Archiving only on
> success throws away the evidence exactly when it matters.

---

## Credentials

**Manage Jenkins → Credentials → System → Global**

| Kind | Binding | Use for |
|---|---|---|
| Secret text | `string(credentialsId:…, variable:'TOK')` | API tokens |
| Username/password | `usernamePassword(…)` → 2 vars | registry login, git over HTTPS |
| **Secret file** | `file(…)` → a **path** | Ansible vault password, kubeconfig |
| SSH private key | `sshUserPrivateKey(…)` | git over SSH |

```groovy
withCredentials([usernamePassword(
    credentialsId: 'dockerhub-creds',
    usernameVariable: 'REG_USER',
    passwordVariable: 'REG_PASS')]) {
  sh '''
    echo "${REG_PASS}" | podman login docker.io -u "${REG_USER}" --password-stdin
  '''
}
```

> [!danger] Three rules
> 1. **`--password-stdin`**, never `-p "$PASS"` — the latter puts the secret in
>    the process list, visible to every user via `ps`.
> 2. **Single-quoted `sh`**. Groovy interpolation (`"${PASS}"`) bakes the secret
>    into the command string Jenkins echoes. Single quotes let the *shell*
>    expand it, and Jenkins masks the value.
> 3. **Secret file for a path.** `--vault-password-file` wants a filename;
>    Jenkins writes the temp file, gives you the path, and deletes it on block
>    exit even if the build fails.

---

## Multibranch pipelines

One job that discovers branches and creates a sub-job per branch, each running
that branch's own Jenkinsfile.

```groovy
if (env.BRANCH_NAME == 'production') {
  env.IMAGE_TAG  = "v1.0.${env.BUILD_NUMBER}"
  env.TARGET_ENV = 'production'
} else {
  env.IMAGE_TAG  = "staging-${env.GIT_SHA}"
  env.TARGET_ENV = 'staging'
}
```

`env.BRANCH_NAME` is injected by the multibranch job — it does not exist in a
plain pipeline job.

Or gate whole stages:

```groovy
stage('Deploy to prod') {
  when { branch 'production' }
  steps { … }
}
```

---

## The `sh` step: `set -eux`

```groovy
sh '''
  set -eux
  podman build …
  podman push …
'''
```

| Flag | Effect |
|---|---|
| `-e` | **exit on first failure** |
| `-u` | fail on an unset variable — catches typos in env names |
| `-x` | echo each command — your build log becomes a transcript |

> [!danger] Without `-e`, a multi-line `sh` only fails if the LAST command fails
> `podman build` can explode and the stage still goes green, because the exit
> status of the block is the exit status of `podman push` — which never ran
> correctly. This is the most dangerous default in all of Jenkins.

---

## Agents

```groovy
agent any                                   // any executor
agent { label 'podman' }                    // a node with that label
agent none                                  // per-stage agents instead
```

On this laptop everything runs on the built-in node. In production, tag agents
by capability (`podman`, `libvirt`, `ansible`) and pick with `label`.

> [!note] Builds run as the `jenkins` user
> Not you. That user needs its own rootless Podman setup, its own SSH key, and
> its own `~/.ssh/known_hosts`. Persistent state (terraform state, golden
> images) belongs under `/var/lib/jenkins/…`, **outside the workspace** — a
> workspace wipe must not take it.

---

## Shared libraries

When five repos share a Jenkinsfile, extract it.

```groovy
@Library('airnav-shared') _

standardPipeline(
  image: 'wings-portal',
  registry: 'docker.io/sylthecatto'
)
```

Library repo layout:

```
vars/standardPipeline.groovy     # the callable step
src/com/airnav/Helpers.groovy    # classes
resources/                       # static files
```

Register at **Manage Jenkins → System → Global Pipeline Libraries**.

---

## Debugging

| Symptom | Look at |
|---|---|
| Stage green but nothing happened | missing `set -e` in the `sh` block |
| `command not found` | the `jenkins` user's `PATH`, not yours |
| Podman permission errors | `subuid`/`subgid` + `XDG_RUNTIME_DIR` for `jenkins` |
| Trigger never fires | run one build manually first |
| Secret appears in the log | you used double quotes in `sh` |
| Workspace has stale files | add `cleanWs()` or `deleteDir()` |

**Replay** (left menu on any build) re-runs with an edited Jenkinsfile without
committing — the fastest way to iterate on pipeline syntax.

```bash
sudo journalctl -u jenkins -f
sudo tail -f /var/lib/jenkins/logs/*.log
```

---

See also: [[00 — CI-CD Master Guide]] · [[01 — Podman]] · [[05 — Troubleshooting]]
