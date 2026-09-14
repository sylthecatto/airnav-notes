---
tags:
  - airnav-cadet
  - devsecops
  - almalinux
  - cis
  - packer
  - terraform
  - ansible
  - jenkins
status: complete
score: 92.3%
repo: https://github.com/sylthecatto/terminated-trainee
---

# DevSecOps Pipeline — Pair A

> [!success] Verified result
> **92.3 % CIS Level 1 compliance** — 48 of 625 checks failing, down from 201.
> `failed=0` on both nodes. Reproduced end-to-end through Jenkins, not just by hand.
> Repo: `~/Documents/terminated-trainee` · Jenkins job `terminated-trainee`

## How to read this

**Part I** explains every concept with no commands — read it once to understand
*why* the pipeline is shaped this way. **Part II** is the build itself: every
file in full, every command, in order. **Part III** wires up Jenkins. **Part IV**
is the failures I actually hit and how each was diagnosed.

If you are rebuilding from scratch, work straight through Part II → III. If you
are preparing to defend this, read Part I and Part IV — that is where the
"why did you do it that way" answers live.

## Map of Content

| Part | Contents |
|---|---|
| [[#Part I — Concepts\|Part I]] | KVM/QEMU/libvirt · golden images · Packer · Kickstart · UEFI · LVM · Terraform · cloud-init · Ansible · Vault · precedence · CIS · Goss · Jenkins |
| [[#Part II — The Build\|Part II]] | Prerequisites · every file · every command |
| [[#Part III — Jenkins\|Part III]] | Credentials · job config · triggers · proving automation |
| [[#Part IV — Troubleshooting\|Part IV]] | Nine real failures and their root causes |
| [[#Part V — Results and Defence\|Part V]] | Numbers, tailoring table, likely questions |

---

# Part I — Concepts

## The overall picture

One AlmaLinux 9 ISO goes in. Two hardened, audited VMs come out. Nothing is
clicked by hand.

```
Packer + Kickstart  →  alma9-golden.qcow2   (UEFI, LVM, cloud-init, UNhardened)
        ↓
Terraform           →  2 UEFI VMs, 3 disks each, in their own storage pool
        ↓            →  writes ansible/inventory/hosts.yml
Ansible + RHEL9-CIS →  CIS Level 1 Server remediation
        ↓
Goss                →  independent audit → JSON report
        ↓
Jenkins             →  runs all of the above, archives the report
```

> [!abstract] The separation is the whole design
> **Packer makes an image. Terraform makes machines. Ansible makes
> configuration. Goss makes evidence. Jenkins makes it repeatable.**
>
> Each hands one artifact to the next. That is why you can rebuild any stage
> without touching the others — and why a broken VM costs ten minutes rather
> than an afternoon.

## The virtualization stack

Three layers, commonly confused. Knowing which is which is how you debug fast.

| Layer | What it is | Where it lives |
|---|---|---|
| **KVM** | Kernel module turning Linux into a hypervisor. Gives near-native speed by letting guest instructions run directly on the CPU | Kernel (`/dev/kvm`) |
| **QEMU** | Userspace emulator. Provides the *virtual hardware* — disks, NICs, serial ports. Without KVM it emulates the CPU too (slow) | One process per VM |
| **libvirt** | Management API and daemon above QEMU. Defines VMs as XML, handles storage pools, networks, autostart | `virtqemud`, `virsh` |

> [!tip] Debug by layer
> - `lsmod | grep kvm` empty → **KVM** problem, virtualization off in BIOS
> - `virsh list` errors → **libvirt** problem, daemon or permissions
> - VM defined but won't boot → **QEMU** problem, read the domain XML

Terraform talks to libvirt. Packer talks to QEMU directly. Both ultimately use
KVM for acceleration.

## Golden images and copy-on-write

> [!abstract] What a golden image is
> A pre-built, known-good OS disk you clone instead of installing from scratch
> every time. Install once (~9 min), clone in seconds.

The real benefit is not speed, it is **determinism**. Every VM starts
byte-identical, so any difference between two machines is something *you*
configured — never a bad install, a different mirror, or a package that changed
version between Tuesday and Thursday.

Cloning uses **copy-on-write**: the clone stores only its *differences* from the
backing image.

```hcl
resource "libvirt_volume" "os_disk" {
  count          = var.node_count
  base_volume_id = libvirt_volume.golden.id   # ← the CoW link
}
```

Two VMs cost roughly 200 MB on top of one 2.8 GB image, not 2 × 2.8 GB. This is
how one image becomes N machines cheaply.

> [!warning] The CoW caveat
> Every clone depends on the backing image. Delete or modify
> `alma9-golden.qcow2` and every VM built on it breaks. That is exactly why the
> Jenkinsfile keeps it at `/var/lib/jenkins/golden-images/` — *outside* the
> workspace, where a "Wipe Workspace" click cannot reach it.

## Packer

Packer automates the OS install. It boots a throwaway VM from the ISO, feeds the
installer an answer file, waits for it to finish, runs any cleanup you specify,
then shuts down and saves the disk.

Four building blocks:

| Block | Purpose |
|---|---|
| `source` | What to build and how — ISO, CPU, memory, disk, firmware |
| `build` | Ties sources to provisioners |
| `provisioner` | Commands run *inside* the VM after install, before saving |
| `post-processor` | Acts on the finished artifact (here: a manifest) |

The sequence: download and checksum the ISO → start QEMU → attach the
Kickstart → wait for SSH → run provisioners → graceful shutdown → save qcow2.

## Kickstart

Anaconda (the RHEL installer) normally asks ~15 interactive questions. Kickstart
is the answer sheet that removes all of them.

### Getting the file to the installer

The usual approach is to serve it over HTTP and type `inst.ks=http://...` onto
the GRUB kernel line using simulated keystrokes. That is fragile — you are
blindly counting cursor presses over VNC, and it breaks whenever the boot menu
changes.

There is a better mechanism:

> [!important] The OEMDRV trick
> **Anaconda automatically loads `/ks.cfg` from any attached volume labelled
> `OEMDRV`**, with no kernel argument at all.

```hcl
cd_content = { "ks.cfg" = file("${path.root}/kickstart.cfg") }
cd_label   = "OEMDRV"

boot_wait    = "5s"
boot_command = ["<enter>"]   # only skips GRUB's 60-second countdown
```

No web server, no typed URL, one keystroke instead of five. The map key must be
exactly `ks.cfg` — that is the filename *on the ISO*, and Anaconda looks for
that name specifically.

## UEFI and OVMF

Modern firmware. Two files matter:

| File | Role |
|---|---|
| `OVMF_CODE.fd` | The firmware executable itself. Read-only, shared by all VMs |
| `OVMF_VARS.fd` | The variable store — boot entries, settings. **Per-VM, writable** |

Each VM gets its own private copy of `VARS` (its NVRAM), copied from the
template at creation.

> [!warning] Three gotchas that cost real time
> 1. **`q35` is mandatory.** The older `i440fx` machine type has no UEFI support at all.
> 2. **Don't mix firmware pairs.** `edk2-ovmf` ships a 2 MB raw pair *and* a 4 MB qcow2 pair. Mixing `CODE` from one with `VARS` from the other fails to boot with no useful error. Confirm with `rpm -ql edk2-ovmf`.
> 3. **NVRAM must live outside the storage pool directory**, or `terraform destroy` fails trying to remove a non-empty pool.

## LVM and the partition layout

LVM inserts an abstraction between physical partitions and mounted filesystems:

```
physical partition (pv.01)  →  volume group (vg_sys_a)  →  logical volumes (lv_root, lv_var, …)
```

Because logical volumes are carved from a shared pool, they can be resized
independently later — a fixed partition table cannot.

20 GB disk. `/boot/efi` and `/boot` are **real partitions**, not LVs, because
firmware and the bootloader must read them before LVM exists.

| Mount | LV | Size | Why |
|---|---|---|---|
| `/boot/efi` | — | 600 M | ESP, FAT32 — the UEFI spec mandates FAT |
| `/boot` | — | 1 G | kernels + initramfs |
| `/` | `lv_root` | 4 G + `--grow` | floor, then absorbs the remainder |
| `swap` | `lv_swap` | 2 G | |
| `/var` | `lv_var` | 3 G | RPM DB and dnf cache fill fastest |
| `/var/tmp` | `lv_var_tmp` | 1 G | world-writable *and* persistent |
| `/var/log` | `lv_var_log` | 2 G | log growth can't fill `/` |
| `/var/log/audit` | `lv_var_audit` | 1 G | protects the audit trail |
| `/opt` | `lv_opt` | 1 G | Pair A's assigned extra LV |
| `/tmp` | — | tmpfs | handled by the role, wiped on reboot |

Total allocated: 15 960 MB of 20 480 MB. `--grow` gives root the rest.

> [!important] Why CIS wants these split — the part people miss
> **1. Isolation.** `/var/log` filling on a single-partition box means *nothing*
> can write anywhere — sshd cannot even open a session file. On its own LV, only
> logging stops.
>
> **2. Mount options — the real reason.** In RHEL9-CIS 2.3.0 the "separate
> partition exists" rules are **Level 2**, but the `nodev` / `nosuid` / `noexec`
> mount-option rules are **Level 1** — *and they only apply if the mount point is
> already separate*. So you build the LVs not to pass the L2 rules, but to let
> the **L1** rules run at all.

## Terraform

> [!abstract] Declarative vs imperative
> A shell script says *"run `virsh define`, then `virsh start`"* — a list of
> steps. Run it twice: an error, or two VMs.
>
> Terraform says *"two domains named `pa-node-1` and `pa-node-2` should exist"* —
> a description of the end state. Run it twice, the second says `No changes.`

To do that it must remember what it made. That memory is **state**
(`terraform.tfstate`) — a map from resource addresses to real libvirt UUIDs.

> [!danger] State is the single point of failure
> Lose `terraform.tfstate` and Terraform forgets the VMs exist. `destroy` deletes
> nothing, `apply` tries to recreate what is already there, and you clean up by
> hand. This project uses **default local state** deliberately — no backend
> block, nothing to configure, nothing to break.
>
> It also means the Jenkins workspace has its *own* state, separate from your
> laptop's. Two states, same libvirt — which is exactly the collision described
> in [[#The Jenkins state collision]].

Core vocabulary:

| Term | Meaning |
|---|---|
| **Provider** | Plugin that talks to a platform (`dmacvicar/libvirt`) |
| **Resource** | One managed object (`libvirt_domain.node`) |
| **Data source** | Read-only lookup |
| **Variable** | Input |
| **Output** | Value surfaced after apply |
| **`count`** | Build N copies, indexed `[0]`, `[1]` … |
| **`templatefile()`** | Render a template with values |

This project creates **15 resources**: a pool, the uploaded golden image, 2 OS
disks, 4 data disks, 2 seed ISOs, 2 domains, a keypair, a key file, and the
generated inventory.

## cloud-init

cloud-init is what makes *one* image reusable for *N* machines. On first boot it
reads a data source and applies per-VM identity: hostname, users, SSH keys.

**NoCloud datasource** — the seed is a small ISO with two files, `user-data` and
`meta-data`.

> [!important] It finds the seed by filesystem label, not by path
> cloud-init scans for a volume labelled `cidata`. This is why the seed disk's
> device letter does not matter, and why it can safely be attached last.

```yaml
#cloud-config
hostname: pa-node-1
users:
  - name: ansible
    lock_passwd: true
    ssh_authorized_keys: [ssh-ed25519 AAAA...]
ssh_pwauth: false
```

> [!warning] `#cloud-config` must be line 1
> A blank line or comment above it and cloud-init silently ignores the entire
> file. No error — the VM boots looking healthy with no user and no key.

## Ansible

> [!abstract] Agentless
> Ansible has no daemon on the target. Per task it opens an SSH connection,
> writes a self-contained Python script to a temp dir, runs it, reads one JSON
> document back, and deletes it. Requirements on the target: **sshd + python3**.
> That is the entire mechanism.

| Piece | Role |
|---|---|
| **Inventory** | Which hosts, grouped, with per-group variables |
| **Playbook** | What to do, in order |
| **Module** | The unit of work (`filesystem`, `sysctl`, `lineinfile`) |

**Facts** — before the first task, Ansible runs a setup module that gathers
hundreds of variables about the host (`ansible_facts['distribution']`, disk
layout, network). That is what makes `when:` conditionals and the OS assertion
in this playbook possible.

**Idempotency** — modules describe desired state, not actions. Running twice
changes nothing the second time. This is why `changed=` in the recap is
meaningful: on a converged system it should be near zero.

## Ansible Vault

Symmetric AES256 encryption for files in git.

```bash
ansible-vault create group_vars/all/vault.yml   # prompts for a password
ansible-vault view   group_vars/all/vault.yml
ansible-vault edit   group_vars/all/vault.yml
```

The encrypted file starts `$ANSIBLE_VAULT;1.1;AES256` and is safe to commit. At
runtime you supply the password:

```bash
ansible-playbook playbook.yml --vault-password-file ~/.vault_pass
```

> [!danger] The vault file is the locked box, not the key
> `--vault-password-file` wants the file containing the **password**. Pointing it
> at `vault.yml` itself is a classic error and produces a confusing failure.
>
> The encrypted `vault.yml` **is** committed. `.vault_pass` **never** is.

Convention here: vault variables are prefixed `vault_` and referenced
indirectly, so you can grep for what is secret:

```yaml
# vars.yml (plain, committed, readable)
rhel9cis_bootloader_password_hash: "{{ vault_bootloader_password_hash }}"
```

## Variable precedence

Ansible resolves the same variable name from **22** possible sources. The four
tailoring requirements are deliberately set at **three different levels** to
demonstrate this.

| Variable | Value | Set where | Level | Beats |
|---|---|---|---|---|
| `rhel9cis_warning_banner` | AIRNAV banner | `group_vars/all/vars.yml` | **#5** | role defaults (#2) |
| `rhel9cis_rule_5_3_3_1_*` | `false` | `group_vars/all/vars.yml` | **#5** | role defaults (#2) |
| `rhel9cis_sshd_clientaliveinterval` | `300` | play `vars:` | **#12** | group_vars (#5) |
| `rhel9cis_syslog` | `rsyslog` | `--extra-vars` | **#22** | everything |

The shape to remember:

```
role defaults (#2)  <  group_vars (#5)  <  play vars (#12)  <  --extra-vars (#22)
     lowest                                                       always wins
```

`--extra-vars` always wins because it is the human typing at the moment of
execution — which is also exactly why it is the *wrong* place for permanent
config: it is invisible in git.

> [!warning] There is no warning for a typo
> Misspell a variable and Ansible silently defines a new, unused one. The role
> keeps its default, your tailoring does nothing, and you find out during a
> demo. **Always verify on the host afterwards, never in the playbook.**

## CIS benchmarks and ansible-lockdown

Two different things, often conflated:

- **The CIS Benchmark** is a PDF — a list of ~600 configuration recommendations.
- **RHEL9-CIS** is an Ansible role implementing them, maintained by the
  ansible-lockdown community.

| Level | Scope |
|---|---|
| **Level 1** | Practical, broadly safe. Should not break a normal server |
| **Level 2** | Defence-in-depth. May break functionality — for high-security environments |

This project is **Level 1, Server**.

The role exposes every rule as a variable, and tags every task:

```bash
--skip-tags "level2-server,level2-workstation"
```

> [!danger] Pin the version, and never fork the role
> **Pin** because CIS renumbers rules between benchmark versions — a rule ID is
> meaningless without one. Tracking `main` means an upstream commit silently
> changes what your pipeline enforces, and your score moves for reasons absent
> from your git history.
>
> **Don't fork** because the moment you edit the role you own it forever;
> upstream fixes become merge conflicts. Everything you need is exposed through
> `defaults/main.yml`. If you feel the need to edit a task, you have not read
> the defaults carefully enough.

## Goss

Goss is a fast server-spec tool: a YAML file of assertions, checked against the
live system.

```yaml
port:
  tcp:22:
    listening: true
service:
  auditd:
    enabled: true
    running: true
file:
  /etc/ssh/sshd_config:
    mode: "0600"
```

> [!important] Why audit with a different tool than the one that remediated
> Ansible can only confirm its **own model** of the system. If a task ran without
> error it reports success — even when the change never took effect: the service
> didn't reload, a drop-in overrode it later, SELinux blocked the write, a
> handler never fired because the play aborted.
>
> Goss knows nothing about Ansible. It re-reads the file, re-queries systemd,
> re-checks the port. **A clean `failed=0` recap is not proof of compliance —
> the Goss score is.**

The role runs it twice — before and after remediation — which is what produces a
meaningful before/after number rather than an absolute one.

## Jenkins

> [!abstract] The problem Jenkins solves
> Without it, "run the pipeline" means a human SSHing in and running four
> commands in the right order, with the right environment, remembering the
> vault password. That human is a single point of failure, and nothing is
> recorded. Jenkins makes the process **repeatable, logged, and triggerable by
> an event rather than a person.**

**Controller and agent.** The controller schedules and stores config; agents
execute. Here they are the same machine — `agent any` — which is fine for a lab.

### Jenkinsfile vocabulary

| Block | Purpose |
|---|---|
| `pipeline { }` | Root of a declarative pipeline |
| `agent` | Where it runs |
| `options` | Build-level behaviour (timeouts, concurrency) |
| `triggers` | What starts a build automatically |
| `parameters` | Inputs shown in "Build with Parameters" |
| `environment` | Env vars for all stages |
| `stages` / `stage` | The named phases you see in the UI |
| `steps` | Actual commands |
| `when` | Conditional stage execution |
| `post` | Runs after — `always`, `success`, `failure` |

### Triggers

| Trigger | Mechanism | Fits here? |
|---|---|---|
| `pollSCM` | Jenkins asks the remote "any new commits?" on a schedule | ✅ works from a LAN-only box |
| GitHub webhook | GitHub pushes to Jenkins the instant a commit lands | ❌ needs Jenkins reachable from the internet |
| `cron` | Time-based, ignores commits | Not what "automatic" means here |

> [!important] Why `H/5` and not `*/5`
> `H` makes Jenkins hash the **job name** to pick a fixed offset inside each
> 5-minute window. Every job still runs every 5 minutes, but they are spread
> across the window instead of all hammering SCM at `:00`. Same frequency,
> no thundering herd.

> [!warning] A declarative trigger needs one build to arm itself
> The `triggers { }` block lives *in the Jenkinsfile*, which Jenkins can only
> read by running the job. So after configuring a job from SCM, the trigger does
> not exist until the **first build** parses the file. This catches people out:
> the config looks right, but nothing ever fires.

### Credentials

Jenkins stores secrets encrypted and injects them at runtime.

```groovy
withCredentials([file(credentialsId: 'pairA-vault-pass', variable: 'VAULT_FILE')]) {
    sh 'ansible-playbook playbook.yml --vault-password-file "$VAULT_FILE"'
}
```

Jenkins writes the secret to a temp file, gives you the path in `$VAULT_FILE`,
and **deletes it when the block exits — even on failure**. The secret never
touches the repo, and Jenkins masks it in the console as `****`.

> [!tip] Single quotes matter
> `sh '''...'''` (single) passes `$VAULT_FILE` to the shell, which expands it
> privately. `sh """..."""` (double) makes *Groovy* interpolate it into the
> command string first — which Jenkins then echoes into the build log.

---

# Part II — The Build

## Prerequisites

```bash
# Virtualization stack
sudo dnf install -y qemu-kvm libvirt virt-install edk2-ovmf libguestfs-tools
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm "$USER"     # log out and back in

# Confirm hardware virtualization is on
grep -cE 'vmx|svm' /proc/cpuinfo         # must be > 0

# Packer + Terraform
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y packer terraform

# Ansible
sudo dnf install -y ansible-core

# Jenkins
sudo dnf install -y java-17-openjdk jenkins
sudo systemctl enable --now jenkins
```

Verify:

```bash
packer version && terraform version && ansible --version && virsh list --all
```

## Repository layout

Fifteen files. Nothing else.

```
terminated-trainee/
├── packer/
│   ├── alma9.pkr.hcl
│   └── kickstart.cfg
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── .terraform.lock.hcl      # committed on purpose
│   └── templates/
│       ├── cloud_init.yml.tftpl
│       └── inventory.yml.tftpl
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── playbook.yml
│   └── group_vars/all/
│       ├── vars.yml
│       └── vault.yml            # encrypted
├── Jenkinsfile
├── .gitignore
└── docs/design.md
```

## Stage 1 — Packer

### `packer/kickstart.cfg`

```bash
#version=RHEL9

text
eula --agreed
reboot --eject

lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts='us'
timezone Asia/Manila --utc

# The minimal ISO carries BaseOS only. cloud-init and qemu-guest-agent are in
# AppStream, so this is the build's only network dependency.
repo --name="appstream" --baseurl=https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/

network --bootproto=dhcp --device=link --activate --onboot=on
firewall --enabled --service=ssh

# No root password baked into an image that gets cloned.
rootpw --lock
user --name=ansible --groups=wheel --password=buildpw --plaintext

ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda

# ESP + /boot must be real partitions: firmware and bootloader read them
# before LVM exists.
part /boot/efi --fstype=efi --size=600  --ondisk=vda --fsoptions="umask=0077,shortname=winnt"
part /boot     --fstype=xfs --size=1024 --ondisk=vda
part pv.01     --size=1 --grow          --ondisk=vda

volgroup vg_sys_a pv.01

logvol /              --vgname=vg_sys_a --name=lv_root      --fstype=xfs  --size=4096 --grow
logvol swap           --vgname=vg_sys_a --name=lv_swap      --fstype=swap --size=2048
logvol /var           --vgname=vg_sys_a --name=lv_var       --fstype=xfs  --size=3072
logvol /var/tmp       --vgname=vg_sys_a --name=lv_var_tmp   --fstype=xfs  --size=1024
logvol /var/log       --vgname=vg_sys_a --name=lv_var_log   --fstype=xfs  --size=2048
logvol /var/log/audit --vgname=vg_sys_a --name=lv_var_audit --fstype=xfs  --size=1024
logvol /opt           --vgname=vg_sys_a --name=lv_opt       --fstype=xfs  --size=1024

%packages
@^minimal-environment
cloud-init
qemu-guest-agent
%end

%post --log=/root/ks-post.log
set -x

systemctl enable sshd.service qemu-guest-agent.service
systemctl enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service

# Packer's provisioner uses sudo non-interactively.
echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-ansible
chmod 440 /etc/sudoers.d/90-ansible

# Packer logs in with a password, but cloud-init drops a
# /etc/ssh/sshd_config.d/50-cloud-init.conf that turns PasswordAuthentication
# off on first boot. sshd reads sshd_config.d/*.conf in lexical order and takes
# the FIRST value for a keyword, so this must sort before 50- to win.
echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/01-packer-build.conf
chmod 600 /etc/ssh/sshd_config.d/01-packer-build.conf

# Without this cloud-init probes EC2/Azure/GCE first and adds ~2 min per boot.
echo 'datasource_list: [ NoCloud, None ]' > /etc/cloud/cloud.cfg.d/99-datasource.cfg

# Trust the distro signing key so CIS 1.2.1.x passes without a tailoring exception.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9

dnf clean all
%end
```

### `packer/alma9.pkr.hcl`

```hcl
packer {
  required_plugins {
    qemu = {
      version = "1.1.6"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "alma_version" {
  type    = string
  default = "9.8"
}

# Jenkins overrides this to a path outside the workspace so a workspace wipe
# does not take the golden image with it.
variable "output_directory" {
  type    = string
  default = "output"
}

source "qemu" "alma9" {
  # Minimal ISO, not boot.iso: it carries BaseOS on the media, so the install
  # does not pull ~400 packages over the network.
  iso_url      = "https://repo.almalinux.org/almalinux/${var.alma_version}/isos/x86_64/AlmaLinux-${var.alma_version}-x86_64-minimal.iso"
  iso_checksum = "file:https://repo.almalinux.org/almalinux/${var.alma_version}/isos/x86_64/CHECKSUM"

  machine_type = "q35" # i440fx has no UEFI support at all
  accelerator  = "kvm"
  cpu_model    = "host" # RHEL9's qemu dropped the generic qemu64 model
  cpus         = 2
  memory       = 2048
  disk_size    = "20G"
  format       = "qcow2"
  headless     = true

  efi_boot          = true
  efi_firmware_code = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
  efi_firmware_vars = "/usr/share/edk2/ovmf/OVMF_VARS.fd"

  # Anaconda auto-loads /ks.cfg from any volume labelled OEMDRV.
  cd_content = {
    "ks.cfg" = file("${path.root}/kickstart.cfg")
  }
  cd_label = "OEMDRV"

  boot_wait    = "5s"
  boot_command = ["<enter>"]

  ssh_username     = "ansible"
  ssh_password     = "buildpw"
  ssh_timeout      = "60m"
  shutdown_command = "sudo shutdown -P now"

  output_directory = var.output_directory
  vm_name          = "alma9-golden.qcow2"
}

build {
  sources = ["source.qemu.alma9"]

  provisioner "shell" {
    inline = [
      "sudo rm -f /etc/ssh/sshd_config.d/01-packer-build.conf",
      "sudo cloud-init clean --logs --seed",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo passwd -l ansible",
      "sync",
    ]
  }

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
```

### Sealing the image — why each cleanup line exists

> [!danger] Get these wrong and every clone is subtly broken
> - **`rm 01-packer-build.conf`** — removes the build-only password login. From here the only way in is the per-VM deploy key.
> - **`cloud-init clean --logs --seed`** — without it, cloud-init sees its own completion marker on first boot and skips *everything*: no hostname, no user, no SSH key. The VM boots looking healthy and Ansible can never reach it.
> - **`truncate -s 0 /etc/machine-id`** — truncate, don't delete. systemd regenerates it only if the file *exists and is empty*. Some DHCP clients derive their identity from it, so clones would collide.
> - **`rm /etc/ssh/ssh_host_*`** — bake host keys in and every clone shares an identity. That is a trivial man-in-the-middle plus `known_hosts` chaos. sshd regenerates them on first boot.
> - **`passwd -l ansible`** — kills the build password for good.

### Run it

```bash
cd packer
packer init .          # download the QEMU plugin
packer validate .      # fail in 2 seconds, not 9 minutes
packer build .
```

Expect **~9 minutes**. Verify:

```bash
ls -lh output/alma9-golden.qcow2          # ~2.8G
virt-df -a output/alma9-golden.qcow2      # confirm the LV layout
```

## Stage 2 — Terraform

### `terraform/variables.tf`

```hcl
variable "node_count"      { type = number  default = 2 }
variable "hostname_prefix" { type = string  default = "pa-node" }
variable "vcpu"            { type = number  default = 2 }

# The brief says 2048. The CIS role's Goss JSON parsing gets OOM-killed
# (rc: 137) at that size, so this is a documented deviation.
variable "memory_mb" { type = number  default = 3072 }

variable "pool_name" { type = string  default = "pool_a" }
variable "pool_path" { type = string  default = "/var/lib/libvirt/pools/pool_a" }

# Must match packer's output_directory + vm_name.
variable "golden_image_path" {
  type    = string
  default = "../packer/output/alma9-golden.qcow2"
}

variable "data_disk_count"   { type = number  default = 2 }
variable "data_disk_size_gb" { type = number  default = 2 }

# Pair A is assigned virtio, so data disks appear as /dev/vdb and /dev/vdc.
variable "data_disk_devices" {
  type    = list(string)
  default = ["/dev/vdb", "/dev/vdc"]
}
variable "data_disk_fstype" { type = string  default = "xfs" }

# Confirmed with: rpm -ql edk2-ovmf. The 2 MB raw pair - do not mix with qcow2.
variable "ovmf_code" { type = string  default = "/usr/share/edk2/ovmf/OVMF_CODE.fd" }
variable "ovmf_vars" { type = string  default = "/usr/share/edk2/ovmf/OVMF_VARS.fd" }

# Must be outside pool_path, or destroy fails on a non-empty pool directory.
variable "nvram_dir" { type = string  default = "/var/lib/libvirt/qemu/nvram" }

variable "ssh_user"     { type = string  default = "ansible" }
variable "network_name" { type = string  default = "default" }
```

> [!note] Compressed for readability
> In the real file each attribute sits on its own line. The one-line form above
> is only to keep this section scannable.

### `terraform/main.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      # 0.9.x is a breaking schema rewrite - firmware/nvram/disk blocks are gone.
      version = "0.8.3"
    }
    local = { source = "hashicorp/local", version = "~> 2.5" }
    tls   = { source = "hashicorp/tls",   version = "~> 4.0" }
  }
}

# Naming the socket explicitly avoids the PID-lookup failure the provider hits
# when Terraform runs from a Jenkins subshell.
provider "libvirt" {
  uri = "qemu:///system?socket=/var/run/libvirt/virtqemud-sock"
}

locals {
  node_names = [for i in range(var.node_count) : "${var.hostname_prefix}-${i + 1}"]
}

# Generated here so a fresh clone needs no ssh-keygen step.
resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "deploy_key" {
  filename        = "${path.module}/.ssh/pairA_deploy"
  content         = tls_private_key.deploy.private_key_openssh
  file_permission = "0600"
}

# Pair A's own pool. The brief forbids using the default pool.
resource "libvirt_pool" "this" {
  name = var.pool_name
  type = "dir"
  target { path = var.pool_path }
}

resource "libvirt_volume" "golden" {
  name   = "alma9-golden.qcow2"
  pool   = libvirt_pool.this.name
  source = var.golden_image_path
}

# base_volume_id gives a copy-on-write clone: 2 VMs cost ~200 MB, not 2 x 2.8 GB.
resource "libvirt_volume" "os_disk" {
  count          = var.node_count
  name           = "${local.node_names[count.index]}-os.qcow2"
  pool           = libvirt_pool.this.name
  base_volume_id = libvirt_volume.golden.id
}

# Blank disks; Ansible formats them. Size is in BYTES.
resource "libvirt_volume" "data_disk" {
  count = var.node_count * var.data_disk_count
  name = format("%s-data%d.qcow2",
    local.node_names[floor(count.index / var.data_disk_count)],
    (count.index % var.data_disk_count) + 1
  )
  pool = libvirt_pool.this.name
  size = var.data_disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "seed" {
  count = var.node_count
  name  = "${local.node_names[count.index]}-seed.iso"
  pool  = libvirt_pool.this.name

  user_data = templatefile("${path.module}/templates/cloud_init.yml.tftpl", {
    hostname   = local.node_names[count.index]
    ssh_user   = var.ssh_user
    ssh_pubkey = trimspace(tls_private_key.deploy.public_key_openssh)
  })

  meta_data = <<-EOT
    instance-id: ${local.node_names[count.index]}
    local-hostname: ${local.node_names[count.index]}
  EOT
}

resource "libvirt_domain" "node" {
  count   = var.node_count
  name    = local.node_names[count.index]
  memory  = var.memory_mb
  vcpu    = var.vcpu
  running = true
  machine = "q35"

  cpu { mode = "host-passthrough" }

  firmware = var.ovmf_code
  nvram {
    file     = "${var.nvram_dir}/${local.node_names[count.index]}_VARS.fd"
    template = var.ovmf_vars
  }

  # OS disk -> vda
  disk { volume_id = libvirt_volume.os_disk[count.index].id }

  # Data disks -> vdb, vdc. These MUST be attached before the seed disk:
  # device letters follow attachment order, and the seed carries no flag to
  # set it apart, so declaring it first would steal vdb and push these to
  # vdc/vdd - one past where the Ansible inventory expects them.
  dynamic "disk" {
    for_each = range(var.data_disk_count)
    content {
      volume_id = libvirt_volume.data_disk[count.index * var.data_disk_count + disk.value].id
    }
  }

  # Seed attached LAST, as a plain virtio disk. `cloudinit =` would attach it
  # as an IDE cdrom, and q35 has no IDE controller. Its device letter does not
  # matter: cloud-init finds it by filesystem label ("cidata"), not by path.
  disk {
    volume_id = split(";", libvirt_cloudinit_disk.seed[count.index].id)[0]
  }

  network_interface {
    network_name   = var.network_name
    hostname       = local.node_names[count.index]
    wait_for_lease = true
  }

  # How you get back in when hardening breaks SSH.
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

locals {
  # The interface also reports an IPv6 link-local address; keep only IPv4.
  node_ips = [
    for d in libvirt_domain.node :
    try([
      for a in flatten(d.network_interface[*].addresses) :
      a if can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", a))
    ][0], "")
  ]

  nodes = [
    for i, name in libvirt_domain.node[*].name :
    { name = name, ip = local.node_ips[i] }
  ]
}

# A managed resource, so destroy deletes it instead of leaving a stale file.
resource "local_file" "inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    nodes           = local.nodes
    ssh_user        = var.ssh_user
    ssh_private_key = abspath(local_sensitive_file.deploy_key.filename)
    data_disks      = var.data_disk_devices
    data_fstype     = var.data_disk_fstype
  })
}

output "node_ips" { value = local.node_ips }
```

### `terraform/templates/cloud_init.yml.tftpl`

```yaml
#cloud-config
# ^ must be line 1. A blank line or comment above it and cloud-init ignores
#   the whole file silently.

hostname: ${hostname}
fqdn: ${hostname}.pair-a.lab
preserve_hostname: false

users:
  # Same name the kickstart created, so this updates that account rather than
  # making a second one.
  - name: ${ssh_user}
    groups: [wheel]
    shell: /bin/bash
    lock_passwd: true
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - ${ssh_pubkey}

ssh_pwauth: false
disable_root: true

ssh_deletekeys: true
ssh_genkeytypes: [ed25519, rsa]
```

### `terraform/templates/inventory.yml.tftpl`

```yaml
---
# Generated by terraform. Regenerated on apply, deleted on destroy.
all:
  children:
    pa_nodes:
      hosts:
%{ for n in nodes ~}
        ${n.name}:
          ansible_host: ${n.ip}
%{ endfor ~}
      vars:
        ansible_user: ${ssh_user}
        ansible_ssh_private_key_file: ${ssh_private_key}
        data_disk_devices: ${jsonencode(data_disks)}
        data_disk_fstype: ${data_fstype}
```

> [!tip] Terraform writes Ansible's inventory
> Terraform already knows the IPs, so it writes the inventory directly —
> including the data-disk device list and filesystem, so the playbook hardcodes
> neither. And because it is a **managed resource**, `terraform destroy` deletes
> it, satisfying "destroy leaves no generated inventory".

### Run it

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

Verify — especially the disk order:

```bash
virsh list --all
virsh domblklist pa-node-1     # vda=os, vdb/vdc=data, vdd=seed
cat ../ansible/inventory/hosts.yml
```

## Stage 3 — Ansible

### `ansible/ansible.cfg`

```ini
[defaults]
inventory = inventory/hosts.yml
roles_path = roles
collections_path = collections

# Host keys are stripped from the golden image and every rebuild gets a fresh
# DHCP address, so verification would fail on every run. Lab-only setting.
host_key_checking = False

# The CIS role fires hundreds of rapid sudo escalations; the default 10s
# timeout kills the run partway through.
timeout = 30

# Readable multi-line output. NOT `stdout_callback = yaml` - that was the
# community.general.yaml plugin, removed in community.general 12.0.0.
stdout_callback = ansible.builtin.default
callback_result_format = yaml

[privilege_escalation]
become = True

[ssh_connection]
pipelining = True
```

### `ansible/requirements.yml`

```yaml
---
roles:
  # Pinned to a release tag: CIS renumbers rules between benchmark versions,
  # so tracking `main` would silently change what the pipeline enforces.
  - name: RHEL9-CIS
    src: https://github.com/ansible-lockdown/RHEL9-CIS.git
    scm: git
    version: "2.3.0"

# ansible-core ships none of these, so without them the role fails on
# community.general.filesystem.
collections:
  - name: community.general
    version: ">=8.0.0"
  - name: community.crypto
    version: ">=2.0.0"
  - name: ansible.posix
    version: ">=1.5.0"
```

### `ansible/group_vars/all/vars.yml`

```yaml
---
# Level 1, Server only. The role copies these into the Goss vars file it writes
# on the target, so this scopes the AUDIT as well as the remediation - leave
# level_2 true and you remediate L1 but get graded on L1+L2.
rhel9cis_level_1: true
rhel9cis_level_2: false

# TAILORING - login banner. Precedence #5 (group_vars).
rhel9cis_warning_banner: "AIRNAV SYSTEMS - AUTHORIZED ACCESS ONLY. ACTIVITY IS MONITORED AND RECORDED."

# TAILORING - no account lockout. Precedence #5.
rhel9cis_rule_5_3_3_1_1: false
rhel9cis_rule_5_3_3_1_2: false
rhel9cis_rule_5_3_3_1_3: false

# The one real secret. Generated with: grub2-mkpasswd-pbkdf2
rhel9cis_set_boot_pass: true
rhel9cis_bootloader_password_hash: "{{ vault_bootloader_password_hash }}"

# The role refuses to run while this is still its example default.
rhel9cis_authselect_custom_profile_name: cis_pair_a

# Manages /tmp as tmpfs with nodev,nosuid,noexec - satisfies 1.1.2.1.1-.4
# without a /tmp LV.
rhel9cis_tmp_svc: true

# Must not be undefined: the role feeds this to a join(' ') filter.
rhel9cis_sshd_allowusers: "ansible"

# See Part IV - prelim check is tagged `always`, so --skip-tags misses it.
rhel9cis_rule_5_2_4: false

# Rule 1.2.2.1 runs `dnf update` across every package. The golden image is the
# patch baseline, so this turns a ~1 min run into ~20 min for no benefit.
rhel9cis_rule_1_2_2_1: false

# Goss audit: install it, run it, fetch the JSON back to the controller.
setup_audit: true
run_audit: true
fetch_audit_output: true
audit_output_destination: "{{ playbook_dir }}/audit_reports/"
```

### `ansible/group_vars/all/vault.yml`

```bash
# Generate a real PBKDF2 hash (NOT a plaintext password)
grub2-mkpasswd-pbkdf2

# Create the encrypted file
ansible-vault create group_vars/all/vault.yml
```

Contents, before encryption:

```yaml
---
vault_bootloader_password_hash: "grub.pbkdf2.sha512.10000.<salt>.<hash>"
```

Save the vault password somewhere private — never in the repo, never in chat:

```bash
read -rs -p "vault password: " P && printf '%s' "$P" > ~/.vault_pass && chmod 600 ~/.vault_pass && unset P
```

### `ansible/playbook.yml`

```yaml
---
- name: Pair A - prepare data disks and harden to CIS Level 1 Server
  hosts: pa_nodes
  become: true

  vars:
    # TAILORING - sshd idle timeout. Precedence #12 (play vars), which beats
    # group_vars (#5) and the role's own defaults (#2).
    # 300s x 0 retries = disconnect after 5 minutes idle.
    rhel9cis_sshd_clientaliveinterval: 300
    rhel9cis_sshd_clientalivecountmax: 0

  pre_tasks:
    - name: Fail fast on the wrong OS
      ansible.builtin.assert:
        that:
          - ansible_facts['distribution'] == 'AlmaLinux'
          - ansible_facts['distribution_major_version'] == '9'
        fail_msg: >-
          Expected AlmaLinux 9, found
          {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
      tags: [always]

    - name: Format the data disks
      # Neither the filesystem nor the device list is hardcoded here -
      # Terraform put both in the generated inventory.
      community.general.filesystem:
        fstype: "{{ data_disk_fstype }}"
        dev: "{{ item }}"
      loop: "{{ data_disk_devices }}"
      tags: [datadisks]

  roles:
    - role: RHEL9-CIS
```

### Run it

```bash
cd ansible
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass

ansible-galaxy role install -r requirements.yml -p roles/ --force
ansible-galaxy collection install -r requirements.yml -p collections/ --force

ansible -m ping pa_nodes                    # connectivity first

ansible-playbook playbook.yml \
  -e 'rhel9cis_syslog=rsyslog' \
  --skip-tags "level2-server,level2-workstation"
```

Expect **`ok=363 changed=138 unreachable=0 failed=0 skipped=277`**.

### Verify the tailoring actually landed

> [!important] Verify on the host, not in the playbook
> A typo'd variable produces no error. The only proof is the live system.

```bash
IP=$(grep -m1 ansible_host inventory/hosts.yml | awk '{print $2}')
SSH="ssh -i ../terraform/.ssh/pairA_deploy ansible@$IP"

$SSH 'cat /etc/issue.net'                                    # AIRNAV banner
$SSH 'sudo sshd -T | grep -E "clientalive|allowusers"'       # 300 / 0 / ansible
$SSH 'systemctl is-enabled rsyslog'                          # enabled
$SSH 'lsblk -f | grep -E "vdb|vdc"'                          # both xfs
$SSH 'sudo faillock --user ansible'                          # lockout disabled
```

---

# Part III — Jenkins

This is the part that turns four manual commands into one automatic pipeline.

## `Jenkinsfile`

```groovy
pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 120, unit: 'MINUTES')
        // Two concurrent builds would corrupt terraform.tfstate and fight over
        // the same packer output directory.
        disableConcurrentBuilds()
    }

    // Jenkins is LAN-only, so GitHub webhooks cannot reach it - poll instead.
    // H spreads the load: Jenkins hashes the job name to pick a fixed offset
    // within each 5-minute window, so every job does not hit SCM at :00.
    // Note: a declarative trigger only arms itself after the first build, since
    // Jenkins has to read this file once to learn the trigger exists.
    triggers {
        pollSCM('H/5 * * * *')
    }

    parameters {
        booleanParam(name: 'DESTROY_AND_REBUILD', defaultValue: false,
                     description: 'terraform destroy first, then a full fresh rebuild')
        booleanParam(name: 'REBUILD_IMAGE', defaultValue: false,
                     description: 'Rebuild the Packer golden image; unticked reuses it')
    }

    environment {
        LIBVIRT_DEFAULT_URI = 'qemu:///system'
        // Outside the workspace, so a wipe cannot take the golden image with it.
        GOLDEN_DIR = '/var/lib/jenkins/golden-images/alma9'
        GOLDEN_IMG = '/var/lib/jenkins/golden-images/alma9/alma9-golden.qcow2'
    }

    stages {
        stage('Golden image') {
            when {
                anyOf {
                    expression { params.REBUILD_IMAGE }
                    expression { !fileExists(env.GOLDEN_IMG) }
                }
            }
            steps {
                // set -eux: without -e a multi-line sh only fails if the LAST
                // command fails, so packer could explode and the stage go green.
                sh '''
                    set -eux
                    rm -rf "$GOLDEN_DIR"
                    cd packer
                    packer init .
                    packer validate .
                    packer build -var "output_directory=$GOLDEN_DIR" .
                '''
            }
        }

        stage('Provision') {
            steps {
                sh '''
                    set -eux
                    cd terraform
                    terraform init -input=false
                    terraform validate
                '''
                script {
                    if (params.DESTROY_AND_REBUILD) {
                        sh '''
                            set -eux
                            cd terraform
                            terraform destroy -auto-approve -input=false \
                                -var "golden_image_path=$GOLDEN_IMG"
                        '''
                    }
                }
                sh '''
                    set -eux
                    cd terraform
                    terraform apply -auto-approve -input=false \
                        -var "golden_image_path=$GOLDEN_IMG"
                '''
            }
        }

        stage('Harden and audit') {
            steps {
                // file credential: Jenkins writes it to a temp file, gives us the
                // path, and deletes it when the block exits - even on failure.
                withCredentials([file(credentialsId: 'pairA-vault-pass', variable: 'VAULT_FILE')]) {
                    // dir() is required: ansible.cfg is only read from the cwd.
                    dir('ansible') {
                        // Single quotes so Groovy never interpolates the secret
                        // path into the command string Jenkins echoes.
                        sh '''
                            set -eux
                            ansible-galaxy role install -r requirements.yml -p roles/ --force
                            ansible-galaxy collection install -r requirements.yml -p collections/ --force

                            ansible-playbook playbook.yml \
                                --vault-password-file "$VAULT_FILE" \
                                -e 'rhel9cis_syslog=rsyslog' \
                                --skip-tags "level2-server,level2-workstation"
                        '''
                    }
                }
            }
        }
    }

    post {
        // always, not success: a failed build's report is the interesting one.
        always {
            archiveArtifacts artifacts: 'ansible/audit_reports/*.json',
                             allowEmptyArchive: true,
                             fingerprint: true
        }
    }
}
```

### Three details worth defending

> [!important] Why `set -eux` in every `sh`
> A multi-line `sh` block is one shell script, and a shell reports the exit
> status of its **last** command. Without `-e`, `packer build` could fail on
> line 5 and the stage would still go green because `cd` on line 6 succeeded.
> `-e` aborts on first error, `-u` catches unset variables, `-x` echoes each
> command into the build log for debugging.

> [!important] Why the golden image lives outside the workspace
> `GOLDEN_DIR = /var/lib/jenkins/golden-images/alma9`. A "Wipe Workspace" click,
> or a `cleanWs()` step, deletes everything under the workspace. Putting a 2.8 GB
> artifact that takes 9 minutes to rebuild in there means one careless click costs
> ten minutes. The `when` block then skips Packer entirely when the image exists.

> [!important] Why `disableConcurrentBuilds()`
> Two builds at once would run `terraform apply` against the **same state file**
> simultaneously — the classic way to corrupt state — and both would write to the
> same Packer output directory.

## Jenkins prerequisites

The `jenkins` user needs libvirt access and the tools on its PATH:

```bash
sudo usermod -aG libvirt,kvm jenkins
sudo systemctl restart jenkins

# Confirm the jenkins user can actually reach libvirt
sudo -u jenkins env LIBVIRT_DEFAULT_URI=qemu:///system virsh list --all
```

## Step 1 — Create the credential

The pipeline needs exactly one secret: the vault password.

**Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

| Field | Value |
|---|---|
| Kind | **Secret file** |
| File | `~/.vault_pass` |
| ID | `pairA-vault-pass` |
| Description | Pair A ansible-vault password |

> [!danger] The ID is the contract
> `credentialsId: 'pairA-vault-pass'` in the Jenkinsfile must match this ID
> **exactly**. A mismatch fails the build at `withCredentials` — this is
> [[#Failure 8 — Credential ID mismatch|exactly what bit us]].
>
> The *Kind* matters too: the `file(...)` binding requires a **Secret file**,
> not *Secret text*.

List what actually exists, rather than trusting memory:

```bash
curl -s --netrc-file ~/.jenkins_netrc \
  "http://localhost:8080/credentials/store/system/domain/_/api/json?tree=credentials\[id,typeName\]"
```

## Step 2 — Authenticate to the API

Everything below can be done in the web UI, but the API is scriptable and
reviewable. Keep the password out of process arguments by using a netrc file:

```bash
umask 077
cat > ~/.jenkins_netrc <<'EOF'
machine localhost
login YOUR_JENKINS_USER
password YOUR_JENKINS_TOKEN
EOF
chmod 600 ~/.jenkins_netrc

curl -s --netrc-file ~/.jenkins_netrc http://localhost:8080/whoAmI/api/json
```

Get a token from **your name (top right) → Security → API Token → Add new
token**. A token is preferable to your account password: it is revocable
independently and does not unlock the whole account.

> [!warning] CSRF: the crumb is bound to a session
> Jenkins rejects POSTs without a **crumb**, and the crumb only works for the
> session that issued it — so you must carry cookies with `-c`/`-b` or you get a
> 403 even with a valid crumb.

```bash
J=/tmp/jcookies.txt
CRUMB=$(curl -s -c $J --netrc-file ~/.jenkins_netrc \
  'http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')
```

## Step 3 — Delete the old job

```bash
# Back it up first - deletion is not undoable from the UI
curl -s --netrc-file ~/.jenkins_netrc \
  http://localhost:8080/job/pair-a-pipeline/config.xml -o pair-a-pipeline.bak.xml

curl -s -b $J -c $J -X POST --netrc-file ~/.jenkins_netrc -H "$CRUMB" \
  http://localhost:8080/job/pair-a-pipeline/doDelete
```

A **302** is success — Jenkins redirects to the dashboard afterwards. Verify:

```bash
curl -s --netrc-file ~/.jenkins_netrc "http://localhost:8080/api/json?tree=jobs\[name\]"
```

## Step 4 — Configure the pipeline job

Job config is just XML. Write it, POST it.

```xml
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Pair A - Golden Image to Hardened VM pipeline. Params, triggers
    and options are declared in the Jenkinsfile and synced on each build.</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <jenkins.model.BuildDiscarderProperty>
      <strategy class="hudson.tasks.LogRotator">
        <daysToKeep>-1</daysToKeep>
        <numToKeep>30</numToKeep>
        <artifactDaysToKeep>-1</artifactDaysToKeep>
        <artifactNumToKeep>-1</artifactNumToKeep>
        <removeLastBuild>false</removeLastBuild>
      </strategy>
    </jenkins.model.BuildDiscarderProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/sylthecatto/terminated-trainee.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
```

```bash
curl -s -b $J -c $J -X POST --netrc-file ~/.jenkins_netrc -H "$CRUMB" \
  -H 'Content-Type: application/xml' \
  --data-binary @tt-config.xml \
  http://localhost:8080/job/terminated-trainee/config.xml
```

The equivalent in the UI: **New Item → Pipeline → Pipeline script from SCM →
Git**, repo URL, branch `*/main`, script path `Jenkinsfile`, tick *Lightweight
checkout*.

> [!note] Three deliberate choices in that XML
> - **No credentials on the Git remote.** The repo is public, so Jenkins clones it anonymously — no GitHub PAT is stored in Jenkins at all.
> - **`<lightweight>true</lightweight>`** — polling fetches only the `Jenkinsfile` rather than cloning the whole repo every 5 minutes.
> - **`<triggers/>` left empty.** Not an oversight: the trigger is declared in the Jenkinsfile, and Jenkins writes it in here itself on the first build.

## Step 5 — Arm the trigger

```bash
curl -s -b $J -c $J -X POST --netrc-file ~/.jenkins_netrc -H "$CRUMB" \
  http://localhost:8080/job/terminated-trainee/build
```

> [!warning] This first build is not optional
> The `triggers { pollSCM(...) }` block lives in the Jenkinsfile, which Jenkins
> can only read by **running the job**. Until then the job has no trigger and
> nothing will ever fire on its own. Configure → build once → *then* it is
> automatic.

Confirm Jenkins wrote the trigger into the job config itself:

```bash
curl -s --netrc-file ~/.jenkins_netrc \
  http://localhost:8080/job/terminated-trainee/config.xml | grep -A3 'SCMTrigger'
```

```xml
<hudson.triggers.SCMTrigger>
  <spec>H/5 * * * *</spec>
  <ignorePostCommitHooks>false</ignorePostCommitHooks>
</hudson.triggers.SCMTrigger>
```

That block did not exist before the build. Jenkins synced it from the
Jenkinsfile — along with both `booleanParam` definitions.

## Step 6 — Prove it is actually automatic

Configured is not the same as working. The proof is the **Git Polling Log**
(`/job/terminated-trainee/scmPollLog`):

```
Started on Aug 24, 2026, 11:28:00 AM
Using strategy: Default
[poll] Last Built Revision: Revision 7dea4883... (refs/remotes/origin/main)
No credentials specified
 > git ls-remote -h -- https://github.com/sylthecatto/terminated-trainee.git
Found 1 remote heads on https://github.com/sylthecatto/terminated-trainee.git
[poll] Latest remote head revision on refs/heads/main is: 7dea4883... - already built by 2
Done. Took 0.97 sec
No changes
```

> [!success] What this log proves
> Jenkins woke on its **own schedule**, reached the real GitHub URL, compared the
> remote head to the last built revision, found them identical, and correctly
> declined to rebuild. Push a new commit and the next poll builds it.
>
> `No credentials specified` also confirms the anonymous public clone — no PAT
> stored in Jenkins.

## The Jenkins state collision

> [!danger] Jenkins has its own Terraform state
> The workspace at `/var/lib/jenkins/workspace/terminated-trainee/terraform/`
> holds a **separate** `terraform.tfstate` from your laptop's. Same libvirt,
> two independent memories.
>
> If you have already run `terraform apply` by hand, Jenkins' first build fails:
> its state is empty, so it tries to create `pa-node-1`, `pa-node-2` and
> `pool_a` — which already exist.
>
> **Fix:** destroy the manual infrastructure *using the state that owns it*
> before the first Jenkins build.

```bash
cd ~/Documents/terminated-trainee/terraform
export LIBVIRT_DEFAULT_URI=qemu:///system
terraform destroy -auto-approve

virsh list --all | grep pa-node      # expect nothing
virsh pool-list --all | grep pool_a  # expect nothing
```

You cannot simply hand the existing VMs over to Jenkins either: the Jenkinsfile
passes a different `golden_image_path`, which forces the volume to be replaced
and everything downstream rebuilt regardless.

---

# Part IV — Troubleshooting

Nine real failures from this build, with the diagnosis that found each.

> [!bug]- Failure 1 — Packer hangs forever at "Waiting for SSH"
> **Symptom:** `Permission denied (publickey,gssapi-keyex,gssapi-with-mic)` in a
> loop. sshd is up but never offers password auth.
>
> **Cause:** cloud-init drops `/etc/ssh/sshd_config.d/50-cloud-init.conf` on
> first boot, which sets `PasswordAuthentication no`. Packer authenticates with
> a password.
>
> **Fix:** a drop-in named `01-packer-build.conf`. sshd reads that directory in
> lexical order and takes the **first** value for a keyword, so `01-` wins over
> `50-`. The provisioner deletes it before sealing.
>
> **Diagnose:** connect to the VNC port Packer prints and watch the console, or
> `ssh -vvv` and read which auth methods the server offers.

> [!bug]- Failure 2 — "`/dev/vdb` is already used as iso9660"
> **Symptom:** the `filesystem` task fails on the first data disk; the second is
> silently never formatted.
>
> **Cause:** the cloud-init seed ISO claimed `vdb`, pushing the real data disks
> to `vdc`/`vdd` — one slot past where the inventory expects them. Device letters
> follow **attachment order**, and the seed carries no flag distinguishing it.
>
> **Fix:** attach data disks *before* the seed. The seed's own letter is
> irrelevant — cloud-init finds it by filesystem label (`cidata`), never by path.
>
> **Diagnose:** `virsh domblklist pa-node-1` shows the real mapping in one line
> and settles the question immediately.

> [!bug]- Failure 3 — The role aborts before doing any work
> RHEL9-CIS asserts up front that you have made deliberate choices, and refuses
> to start otherwise. Three separate aborts:
>
> | Assertion | Fix |
> |---|---|
> | `rhel9cis_bootloader_password_hash` still the shipped default | generate a real hash with `grub2-mkpasswd-pbkdf2` |
> | `rhel9cis_authselect_custom_profile_name` still `cis_example_profile` | set to `cis_pair_a` |
> | `rhel9cis_sshd_allowusers` undefined → `TypeError` in `join(' ')` | set to `ansible` |
>
> These are not tailoring decisions — they are values the role will not run
> without, because the defaults would be unsafe.

> [!bug]- Failure 4 — Rule 5.2.4 blocks the run even at Level 1
> **Symptom:** play aborts on "users must provide a password for escalation",
> despite `--skip-tags level2-server`.
>
> **Cause:** 5.2.4 is `level2-server` and never remediates in a Level 1 run — but
> its **prelim check is tagged `always`**, so `--skip-tags` does not skip it. It
> fails because our automation account is deliberately key-only with a locked
> password.
>
> **Fix:** `rhel9cis_rule_5_2_4: false`. This disables a guard for a rule that
> could not have fired anyway.

> [!bug]- Failure 5 — `stdout_callback = yaml` — plugin has been removed
> **Symptom:** `The 'community.general.yaml' callback plugin has been removed.`
>
> **Cause:** the bare name `yaml` resolved to `community.general.yaml`, which was
> **removed in community.general 12.0.0**. Installing current collections pulled
> 13.3.0.
>
> **Fix:** two settings on the builtin callback instead:
> ```ini
> stdout_callback = ansible.builtin.default
> callback_result_format = yaml
> ```
> **Lesson:** verify plugin names against the *installed* version —
> `ansible-doc -t callback -l` — not against a blog post.

> [!bug]- Failure 6 — `couldn't resolve module/action 'community.general.modprobe'`
> **Cause:** `ansible-core` ships **zero** community collections. The role needs
> `community.general`, `community.crypto` and `ansible.posix`.
>
> **Fix:** declare them in `requirements.yml`, install with
> `ansible-galaxy collection install -r requirements.yml -p collections/`, and set
> `collections_path = collections` in `ansible.cfg`.

> [!bug]- Failure 7 — `mkdir /var/lib/jenkins/tfstate: permission denied`
> **Cause:** a Terraform `backend` block pointing at a directory the running user
> could not create.
>
> **Fix:** remove the backend block entirely. Default local state needs no setup
> and no permissions. A remote backend is worth it when a team shares state — not
> for a single-machine lab.

> [!bug]- Failure 8 — Credential ID mismatch
> **Symptom:** build fails immediately in *Harden and audit* at `withCredentials`.
>
> **Cause:** the Jenkinsfile said `credentialsId: 'ansible-vault-pass'`; the
> credential actually in Jenkins was `pairA-vault-pass`.
>
> **Fix:** make them match. List the real IDs with the credentials API call in
> [[#Step 1 — Create the credential|Step 1]] rather than trusting memory.

> [!bug]- Failure 9 — `Decryption failed (no vault secrets were found)`
> **Symptom:** Ansible starts, prints the `PLAY` header, then dies instantly.
>
> **Cause:** the Jenkins credential held the vault password from an **older**
> `vault.yml`. Rebuilding the repo from scratch created a new vault with a new
> password; Jenkins was never updated.
>
> **Fix:** find which password file actually works, then update the credential:
> ```bash
> for f in ~/.vault_pass ~/.pairA_vault_pass; do
>   ansible-vault view group_vars/all/vault.yml --vault-password-file "$f" >/dev/null 2>&1 \
>     && echo "WORKS: $f" || echo "fails: $f"
> done
> ```
> **Lesson:** vault password and vault file are a matched pair. Re-create one and
> you must update every consumer — your shell, Jenkins, any teammate.

## Recovering a host when hardening breaks SSH

> [!question]- SSH is dead after a hardening run. Now what?
> Four categories cause it: **sshd** (`AllowUsers`, crypto policy), **PAM**
> (faillock), **firewall**, and **mount options** (`noexec` on `/tmp`).
>
> Tell them apart from outside without guessing:
> ```bash
> nc -vz 192.168.122.50 22
> # refused → sshd is down     timeout → firewall     open → it is auth
> ```
>
> Then get in over the serial console, which `main.tf` wires up for exactly this:
> ```bash
> virsh console pa-node-1
> ```
>
> Honestly though: the whole box rebuilds in ten minutes. Fix the variable,
> commit, let the pipeline rebuild. A broken host being cheap is the entire point.

---

# Part V — Results and Defence

## Verified numbers

| Stage | Result |
|---|---|
| Packer build | ~9 min → 2.8 GB `alma9-golden.qcow2` |
| Terraform | **15 resources**, both nodes got IPv4 |
| Disk order | `vda`=os, `vdb`/`vdc`=data, `vdd`=seed ✅ |
| Ansible | `ok=363 changed=138 unreachable=0 failed=0 skipped=277` |
| Destroy → rebuild | 15 destroyed, nothing orphaned, clean re-apply ✅ |
| Jenkins build #2 | **SUCCESS in 8m44s** (Packer skipped via `when`) |
| Artifacts | 4 JSON scans archived (pre + post × 2 nodes) |

### Goss compliance

| | Tests | Failed | Score |
|---|---|---|---|
| Pre-remediation | 625 | 201 | 67.8 % |
| **Post-remediation** | 625 | **48** | **92.3 %** ✅ |

Identical numbers by hand and through Jenkins — the pipeline **reproduces** the
result rather than having happened to work once.

## Tailoring decisions and exceptions

| # | Rule(s) | Decision | Rationale | Compensating control |
|---|---|---|---|---|
| 1 | 5.3.3.1.1–.3 `pam_faillock` | Tailored off | Required by the brief. One automation account means a failed run locks both nodes with no path to self-recovery | Key-only access, `AllowUsers ansible`, password auth off, hosts rebuilt every run |
| 2 | 1.1.2.3.2/.3 `/home` mount options | Exception | `/home` is not a separate partition — the brief's LV list omits it, and these nodes have no interactive users | No user data on these hosts |
| 3 | All Level 2 rules | Out of scope | Brief specifies Level 1, Server | — |
| 4 | 1.2.2.1 full `dnf update` | Tailored off | Runs `dnf update` across every package; the golden image is already the patch baseline. Adds ~20 min per run | Patching belongs in the image pipeline, which rebuilds from a current ISO |
| 5 | 5.2.4 password for escalation | Tailored off | Never remediates at L1, but its prelim check is tagged `always` and aborts the play | Key-only, `AllowUsers ansible`, `ssh_pwauth: false` |

### The remaining 48 failures

1. **`/home` mount options** — no separate partition, so the L1 rules have nothing to apply to.
2. **`pam_faillock`** — deliberately disabled per the brief.
3. **Reboot-dependent rules** — sysctl and kernel-module settings written correctly but only active after a reboot; the role does not reboot mid-run by design.

> [!note] Compliance is not security
> 100 % means you matched one baseline, at one moment, on one machine. **90 %
> with documented exceptions is a stronger posture than 100 % reached by quietly
> switching rules off** — the first shows a human understood every deviation.
>
> A Goss report cannot distinguish a deliberate exception from a genuine break.
> That is what the table above is for.

## Deviations from the brief

| Deviation | Reason |
|---|---|
| `memory_mb = 3072`, not 2048 | The role's Python parsing of the Goss JSON gets OOM-killed (`rc: 137`) at 2 GB |
| Bootloader secret stored as a PBKDF2 **hash**, not plaintext | The role asserts against its own default. Supplying the hash satisfies it without needing `passlib` on the controller, and keeps a hash rather than a plaintext in the vault |
| Kickstart delivered by `OEMDRV` label, not `inst.ks=` over HTTP | Removes the HTTP server and the fragile `boot_command` cursor navigation — fewer moving parts, same result |
| `host_key_checking = False` | Host keys are stripped from the image and every rebuild gets a new IP, so verification would fail every run. Lab-only; production would build a `known_hosts` file in the pipeline |

## Likely questions

> [!question]- Why not bake the CIS hardening into the golden image?
> **For:** every VM compliant from first boot, no window between provisioning and
> hardening.
>
> **Against (what we do):** the benchmark and your tailoring change far more often
> than the base OS. Rebuilding a 9-minute image for a one-variable change is
> absurd, and separating them makes hardening **re-runnable and drift-correcting** —
> you can prove compliance again next week without touching the image.
>
> General rule: the image holds what is slow and stable; configuration management
> holds what is fast and environment-specific.

> [!question]- What does cloud-init actually do here?
> It is what makes *one* image reusable for *N* machines. On first boot it reads
> the seed ISO Terraform attached and sets this VM's hostname, creates the
> `ansible` user, installs the deploy key, and regenerates SSH host keys. Same
> qcow2, different identity per VM.

> [!question]- Why audit with Goss instead of trusting Ansible's recap?
> Ansible only confirms its own model. A task can report `ok` while the change
> never took effect — service not reloaded, drop-in overriding it, SELinux
> blocking the write. Goss re-reads the live system with no knowledge of Ansible.
> Independent verification is the only kind that counts.

> [!question]- Why does `destroy` leaving nothing behind matter?
> It proves Terraform's state matches reality. If `destroy` leaves orphans, state
> has drifted — which means `apply` cannot be trusted either. It is the cheapest
> possible check that the infrastructure is genuinely reproducible rather than
> accumulating hand-made cruft.

> [!question]- Why polling instead of a webhook?
> A webhook is strictly better when it can work: instant, no wasted requests. It
> needs GitHub to reach Jenkins over the internet. This Jenkins is LAN-only, so
> polling is the only mechanism available. `H/5` keeps the cost to one
> `git ls-remote` every five minutes, which takes about a second.

## Security notes

> [!danger] What must never be committed
> - `terraform/.ssh/` — the real deploy private key
> - `*.tfstate` — resource details, and can contain secrets
> - `.vault_pass` — the key to the vault
> - `packer/output/` — multi-GB, rebuildable
>
> The **encrypted** `vault.yml` **is** committed on purpose. `.terraform.lock.hcl`
> is committed too, so provider versions stay reproducible.

Verify before every push to a public repo:

```bash
git status --short
git check-ignore -v terraform/.ssh/pairA_deploy terraform/terraform.tfstate
head -c 30 ansible/group_vars/all/vault.yml    # must read $ANSIBLE_VAULT;1.1;AES256
```

> [!warning] Credential hygiene for this setup
> - `~/.git-credentials` stores GitHub PATs in **plaintext** when `credential.helper=store` is set. Check with `git config --global credential.helper`.
> - `~/.jenkins_netrc` holds a Jenkins password in plaintext — delete it when finished, and prefer an API token over the account password.
> - A PAT pasted into a chat, a terminal, or a note should be treated as compromised and rotated.
