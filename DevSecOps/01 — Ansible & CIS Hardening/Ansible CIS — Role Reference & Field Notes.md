---
tags: [airnav-cadet, ansible, cis, hardening, reference]
module: Ansible & CIS Hardening
status: reference
verified: 2026-08-25
---

> [!success] Everything here was verified, not remembered
> Role tags, variable names, rule numbers, and assertion conditions below
> were pulled directly from the upstream `ansible-lockdown` repos at the
> pinned tags on **2026-08-25**. Where the three roles differ, the difference
> is called out explicitly — those differences are the single biggest source
> of exam-day mistakes.

---

## ⚡ FIRST 5 MINUTES — do these in order, no thinking required

```bash
# 1. HOST prep (once, before Cockpit)
ls ~/.ssh/*.pub 2>/dev/null || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
setfacl -m u:qemu:x ~                      # lets qemu:///system read ISOs in your home

# 2. Cockpit → build the VM (see Part 1)
#    Anaconda: TICK "require a password", set one. Enable the NETWORK interface.

# 3. Once booted — get the IP
virsh -c qemu:///system domifaddr terminated-cadet

# 4. Key + sudo (the -t is REQUIRED, sudo needs a terminal to prompt)
ssh-copy-id ansible@<ip>
ssh -t ansible@<ip> 'echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-ansible'
ssh -t ansible@<ip> 'sudo chmod 440 /etc/sudoers.d/90-ansible'
ssh ansible@<ip> 'sudo -n true && echo SUDO-OK'

# 5. Scaffold + PROVE CONNECTIVITY before writing anything else
mkdir -p ~/terminated-cadet/{inventory,group_vars/all,roles,collections} && cd ~/terminated-cadet
# ...write inventory + ansible.cfg (Part 2)...
ansible all -m ping                        # MUST return pong before continuing
```

---

## ⏱️ TWO-HOUR BUDGET — where the time actually goes

| Time | Phase | Notes |
|---|---|---|
| **0:00–0:05** | Host prep + start VM creation in Cockpit | keypair, ACL, click Create |
| **0:05–0:25** | OS installs (unattended-ish) | ⚠️ **don't sit and watch it** — write `ansible.cfg`, `inventory`, `requirements.yml`, `playbook.yml` in another terminal *while it installs* |
| **0:25–0:30** | First contact: key, sudoers, `ansible -m ping` | must end with `pong` |
| **0:30–0:35** | Install role + collections, **run pre-flight greps** | this is where you learn the exact variable names |
| **0:35–0:45** | Write `group_vars`, vault, set the required variables | the assertions from the greps tell you what's mandatory |
| **0:45–1:15** | The hardening run | 400–600 tasks; expect 10–25 min. Fix + re-run if it aborts |
| **1:15–1:30** | Verify on host + read Goss numbers | screenshots/notes for the presentation |
| **1:30–2:00** | Buffer + prep what you'll say | ← **this buffer is not optional** |

> [!danger] The single biggest time-saver
> **Write all the Ansible files while the OS is still installing.** The install
> is ~20 minutes of dead time. Nothing in Part 2 requires the VM to exist —
> only the inventory's IP does, and that's one line you fill in at the end.
> People who wait for the install to finish before opening an editor lose
> a third of the exam.

> [!warning] If you fall behind, cut in this order
> 1. Drop the `-e` precedence demo (do it verbally from the table instead)
> 2. Drop `set_boot_pass`/vault → set a plaintext `_bootloader_password` + `_bootloader_salt` instead (satisfies the same assertion; say it's a lab shortcut)
> 3. Drop custom LVM partitioning → Automatic
> **Never cut:** `ansible -m ping` verification, the pre-flight greps, or
> host-side verification. Those three prevent the failures that cost the most.

---

## 🎯 WHICH VERSION DID I GET? — the one table that matters

Everything that differs between the three roles, in one place. **Get the
prefix wrong and Ansible silently ignores your variable** — no error, role
keeps its default, tailoring does nothing.

| | **AlmaLinux 8** | **AlmaLinux 9** | **AlmaLinux 10** |
|---|---|---|---|
| Role name | `RHEL8-CIS` | `RHEL9-CIS` | `RHEL10-CIS` |
| Latest tag | `4.1.0` | `2.3.0` | `1.1.0` |
| **Var prefix** | `rhel8cis_` | `rhel9cis_` | `rhel10cis_` |
| ISO | `AlmaLinux-8.10-x86_64-minimal.iso` | `AlmaLinux-9.8-…` | `AlmaLinux-10.2-…` |
| Default `_syslog` | **`rsyslog`** | `journald` | `journald` |
| **Lockout rules** | `_rule_5_3_3_1_1/_2/_3` | `_rule_5_3_3_1_1/_2/_3` | ⚠️ **`_rule_5_3_2_1_1/_2/_3`** |
| Crypto policy assert | ✅ yes | ✅ yes | ✅ yes |
| Bootloader password assert | ✅ yes | ✅ yes | ✅ yes |
| Authselect assert | ❌ no | ❌ no | ✅ **yes** |
| **Playbook-user must have a password & be unlocked** | ❌ no | ⚠️ **yes** | ⚠️ **yes** |
| Root password must be set-or-locked | ❌ no | check locally | ⚠️ **yes** (`rule_5_4_2_4`) |
| `_sudoers_exclude_nopasswd_list` | ❌ **does not exist** | ✅ exists | ✅ exists |
| Collections needed | `community.general`, `community.crypto`, `ansible.posix` | *same* | *same* |
| `min_ansible_version` | `2.16.1` | `2.16.1` | `2.16.1` |

> [!danger] The four highest-risk differences
> 1. **RHEL10's lockout rules are `5_3_2_1_x`, not `5_3_3_1_x`.** Copy an 8/9 `group_vars` onto a 10 box and your "no account lockout" tailoring silently does nothing.
> 2. **RHEL8 defaults to `rsyslog`; 9 and 10 default to `journald`.** Know which your brief asks for and set it explicitly either way.
> 3. **RHEL8 has no sudoers exclusion variable.** The `NOPASSWD`-preservation fix that works on 9/10 is *not available* on 8 — use `--ask-become-pass` there (see [[#🔥 THE SUDO TRAP]]).
> 4. **On RHEL 9/10, do NOT lock the `ansible` account.** See below — it aborts the role outright.

> [!danger] ⚠️ NEVER run `passwd -l ansible` on RHEL 9 or 10
> While `rhel<N>cis_rule_5_2_4` is enabled (**it is by default**), the role
> asserts that the account you're connecting as has a **real password** and is
> **not locked**:
> ```
> fail_msg: "You have rhel10cis_rule_5_2_4 enabled but the user = ansible
>            is locked - It can break access"
> ```
> There's a second assertion for a *missing* password (`!!` or empty) with the
> same shape. Both are gated on `sudo_password_rule`, which the role sets to
> `rhel<N>cis_rule_5_2_4`.
>
> **So the "harden it by locking the account" instinct actively breaks the
> run** — the role is protecting you from locking yourself out mid-hardening.
> Keep the password you set at install. Only if you set
> `rhel<N>cis_rule_5_2_4: false` do these checks stop firing.
>
> **RHEL8 does not have these assertions at all** (verified: zero
> `playbook_user` references in its `tasks/main.yml`).

---

# Part 1 — Cockpit: ISO → reachable VM

> [!info] Concept — Cockpit vs virt-manager
> Cockpit's **Machines** plugin is a browser front-end to the *same* libvirt
> daemon virt-manager uses. Same domains, same pools, same XML underneath —
> only the UI differs. `virsh` sees everything Cockpit creates and vice versa.

## 1.1 Host prep (before opening Cockpit)

```bash
systemctl status cockpit.socket          # must be active; else: sudo systemctl enable --now cockpit.socket
ls ~/.ssh/*.pub 2>/dev/null || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
setfacl -m u:qemu:x ~
getfacl ~ | grep qemu                    # want: user:qemu:--x
```

> [!important] Why the ACL — the mechanism, so you can explain it
> Cockpit uses the **system** libvirt connection (`qemu:///system`), so the
> VM process runs as the dedicated `qemu` system user, **not you**. Home dirs
> are `0700`, so `qemu` can't *traverse into* `~` to reach an ISO in
> `~/Downloads/` — regardless of the ISO's own permissions. The ACL grants
> **traversal only** (`--x`), not read or listing.
>
> Diagnose any variant of this with:
> ```bash
> namei -l /path/to/file.iso     # find the first non-traversable dir in the chain
> ```
> Error you'd otherwise see: `Could not open '...iso': Permission denied`.

## 1.2 Create the VM

Browse **`https://localhost:9090`** → **Virtual Machines** → **Create VM**.

| Field | Value | Why |
|---|---|---|
| Name | `terminated-cadet` | appears in `virsh list` |
| Installation type | **Local install media** | you have the ISO |
| Source | `~/Downloads/AlmaLinux-<N>-x86_64-minimal.iso` | |
| Storage | new qcow2, **≥20 GiB** | brief's usual disk expectation |
| Memory | **2048 MiB** min, **4096 better** | the role's Goss JSON parsing can OOM (`rc: 137`) at 2 G |
| Firmware | **UEFI** if the brief asks | ⚠️ cannot convert BIOS→UEFI after creation |
| Immediately start | ✅ | |

> [!tip] Own storage pool (only if the brief forbids `default`)
> **Storage Pools → Create Storage Pool** → type `dir`, path
> `/var/lib/libvirt/pools/pool_lab` → *then* select it during Create VM. If
> the brief says nothing about pools, skip this — `default` is fine.

## 1.3 Anaconda install

1. **Language** → English
2. **Installation destination** → select disk → *Custom* only if LVM layout is required
3. **Network & hostname** → ⚠️ **toggle the interface ON** (off by default — the #1 "why can't I SSH in")
4. **User creation** → name `ansible`, ✅ **Administrator** (wheel), ✅ **"Require a password"**, set one
5. **Root password** → set one too (a Cockpit-console recovery path independent of SSH)
6. **Begin Installation** → wait → reboot

> [!danger] Do NOT untick "Require a password" — and do NOT lock it later either
> Unticking **locks the account** (equivalent to `passwd -l`) — it can't
> authenticate via SSH *or* console, by any method. With no root password
> either, you finish the install with **zero way in**.
>
> **And unlike a normal hardening habit, do not lock it after the key works.**
> On **RHEL 9 and 10**, the role asserts the connecting account has a real
> password and is unlocked (while `rule_5_2_4` is on, which is the default) and
> **aborts** otherwise:
> *"You have rhel10cis_rule_5_2_4 enabled but the user = ansible is locked -
> It can break access."*
> Set a password at install and **keep it**. See the ⚠️ box in
> [[#🎯 WHICH VERSION DID I GET? — the one table that matters]].

> [!important] Set the root password — on RHEL10 it's asserted
> `rule_5_4_2_4` runs `passwd -S root` and requires the result to be `P`
> (password set) or `L` (locked). A fresh AlmaLinux install that never set one
> typically reports locked, which passes — but setting a real root password
> removes all doubt **and** gives you the Cockpit-console recovery path if SSH
> breaks mid-hardening. Two reasons, one action.

> [!tip] Manual LVM in Anaconda (if the brief requires it)
> Custom partitioning → **+** per mount point. `/boot` and `/boot/efi` =
> **Standard Partition** (firmware/bootloader read them before LVM exists);
> everything else = **LVM**. Typical set: `/`, `/var`, `/var/log`,
> `/var/log/audit`, `/var/tmp`, `swap`, + assigned extra LV. Give `/` a floor
> size and leave it last to absorb the remainder (Anaconda has no `--grow`
> button).
>
> **Why CIS wants these split:** the *"separate partition exists"* rules are
> often **Level 2**, but the `nodev`/`nosuid`/`noexec` **mount-option** rules
> are **Level 1** — and they only apply *if the mount point is already
> separate*. You build the LVs so the L1 rules can run at all.

## 1.4 First contact

```bash
virsh -c qemu:///system domifaddr terminated-cadet       # get IP
ssh-copy-id ansible@<ip>                        # prompts for install password
ssh ansible@<ip> 'true'                         # MUST return with no prompt

ssh -t ansible@<ip> 'echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-ansible'
ssh -t ansible@<ip> 'sudo chmod 440 /etc/sudoers.d/90-ansible'
ssh ansible@<ip> 'sudo -n true && echo SUDO-OK'
```

> [!important] Why `-t` is mandatory on those two commands
> `sudo` needs a password here (NOPASSWD doesn't exist yet — you're creating
> it) and **refuses to prompt without a pseudo-terminal**. Plain
> `ssh host 'cmd'` doesn't allocate one. Without `-t`:
> `sudo: a terminal is required to read the password`.

> [!note] Can't read the sudoers file afterward? That's correct.
> `/etc/sudoers.d/*` is `0440 root:root` — even the account it grants sudo
> *to* can't `cat` it directly. Use `sudo cat /etc/sudoers.d/90-ansible`. The
> real proof it works is `sudo -n true` returning cleanly.

---

# Part 2 — The Ansible project, file by file

> [!abstract] Mental model
> Ansible needs exactly three things: **which hosts** (inventory), **how to
> connect/behave** (`ansible.cfg`), **what to do** (playbook → role).
> `group_vars` and `requirements.yml` exist to keep those organized.

```bash
mkdir -p ~/terminated-cadet/{inventory,group_vars/all,roles,collections}
cd ~/terminated-cadet
```

> [!warning] Run EVERY command from the project root
> All paths below are relative to `~/terminated-cadet/`. If an inventory "won't
> parse" with no clearer error, check `pwd` first — `-i inventory/hosts.yml`
> typed from *inside* `inventory/` resolves to `inventory/inventory/hosts.yml`
> and Ansible reports it as *"No inventory was parsed"*, not a missing file.

## 2.1 `inventory/hosts.yml`

```yaml
---
all:
  children:
    terminated_cadet:
      hosts:
        node1:
          ansible_host: 192.168.122.50
      vars:
        ansible_user: ansible
        ansible_ssh_private_key_file: ~/.ssh/id_ed25519
```

INI form, if faster to type:

```ini
[terminated_cadet]
node1 ansible_host=192.168.122.50

[terminated_cadet:vars]
ansible_user=ansible
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

```bash
ansible all -m ping        # → pong. Do this NOW, before anything else.
```

> [!warning] Group names use `_`, the VM name uses `-`
> The libvirt domain is **`terminated-cadet`** (hyphen) but the Ansible group
> is **`terminated_cadet`** (underscore) — deliberately, not a typo. Ansible
> group names follow variable-naming rules; a hyphen produces:
> ```
> [WARNING]: Invalid characters were found in group names but not replaced
> ```
> It still works, but it's a warning in front of an examiner for no reason.
> Hostnames, VM names, and file paths keep the hyphen; **group names get the
> underscore.**

> [!tip] Useful inventory checks
> ```bash
> ansible-inventory --list                 # full parsed inventory as JSON
> ansible-inventory --graph                # tree view of groups → hosts
> ansible terminated_cadet --list-hosts    # what the pattern actually matches
> ```

## 2.2 `ansible.cfg`

```ini
[defaults]
inventory = inventory/hosts.yml
roles_path = roles
collections_path = collections
host_key_checking = False
timeout = 30
stdout_callback = ansible.builtin.default
callback_result_format = yaml
allow_broken_conditionals = True

[privilege_escalation]
become = True

[ssh_connection]
pipelining = True
```

### Why each line — be ready to explain these

> [!info]- Config file search order (why "run from project root" matters)
> Ansible stops at the **first** it finds:
> `$ANSIBLE_CONFIG` → `./ansible.cfg` → `~/.ansible.cfg` → `/etc/ansible/ansible.cfg`.
> Run from the wrong directory and it silently uses a *different* config —
> or none of yours.

> [!info]- `inventory` / `roles_path` / `collections_path`
> Ansible's own defaults are `/etc/ansible/hosts` (won't exist) and a search
> path that includes `~/.ansible/roles/` (may hold a stale role from another
> exercise). Pinning all three to project-local paths makes the project
> **self-contained and reproducible** — clone + 2 galaxy commands = exact
> declared state, nothing inherited.

> [!info]- `host_key_checking = False` — the SSH mechanism
> Every SSH **server** has a host key identifying *the server*. First
> connection, OpenSSH can't verify it and asks interactively
> (`Are you sure you want to continue connecting?`), then records it in
> `~/.ssh/known_hosts`.
> Every VM you build is a **brand-new host** with freshly generated host keys.
> Ansible connects **non-interactively** — nobody can type `yes` — so without
> this the first connection **hangs forever**. Not an error. A hang.
> Appropriate for a lab VM you built yourself; **not** for production.

> [!info]- `timeout = 30`
> Per-task SSH timeout (default 10s). A CIS run is 300–600+ tasks, most
> individually `become`-escalating. Under load those negotiations can exceed
> 10s and fail for no real reason. 30 is cheap headroom.

> [!info]- `stdout_callback` + `callback_result_format`
> A **callback plugin** controls result display. Default output is one dense
> JSON line per task — unreadable across 400 tasks.
> `ansible.builtin.default` = the built-in plugin shipped in `ansible-core`;
> `callback_result_format = yaml` renders results as readable multi-line YAML.
> ⚠️ **Never write `stdout_callback = yaml`** — that resolves to
> `community.general.yaml`, **removed in community.general 12.0.0**.

> [!info]- `become = True` — connection ≠ escalation
> Two independent steps per task: (1) SSH in as `ansible_user` (unprivileged),
> (2) wrap module execution in `sudo`. Setting this globally makes every task
> root by default — necessary because CIS touches `/etc/ssh/sshd_config`,
> `/etc/pam.d/*`, `/etc/security/*`, sysctl, systemd units. Override per-task
> with `become: false` if ever needed.

> [!info]- `pipelining = True` — what it actually saves
> **Without it**, one task = generate a Python script → **copy it to the host**
> (SFTP/SCP) → **separate SSH command** to execute → **another** to clean up.
> Up to 3 connection ops *per task*.
> **With it**, the module is fed over the **existing SSH session's stdin** in
> one round trip, no temp file written. At 400+ tasks that's a real saving.
> ⚠️ Fails only if the target's sudoers has `Defaults requiretty` (modern
> AlmaLinux doesn't).

> [!info]- `allow_broken_conditionals = True` — insurance, added deliberately
> `ansible-core 2.19+` **hard-errors** when a `when:` evaluates to a
> non-boolean (e.g. a string), where older versions silently truthy-cast it.
> `RHEL10-CIS 1.1.0` contains such a bug in `handlers/main.yml` (a comparison
> wrapped in stray outer quotes → dead string literal). This setting is the
> **documented escape hatch named in the error message itself**.
> Prefer it over editing role YAML: the role dir is galaxy-installed and
> gitignored (a `--force` reinstall wipes any manual fix), while `ansible.cfg`
> is *your* file and persists — and it covers other instances of the same
> defect you haven't hit yet.
> **Defense:** *"a role/ansible-core version-compatibility gap, unrelated to
> what the role remediates — not a disabled control."*

## 2.3 `requirements.yml` — two-step, discover don't guess

### Step 1 — role only

```yaml
---
roles:
  - name: RHEL10-CIS                                        # ← YOUR version
    src: https://github.com/ansible-lockdown/RHEL10-CIS.git
    scm: git
    version: "1.1.0"                                        # ← real TAG
```

```bash
ansible-galaxy role install -r requirements.yml -p roles/ --force
```

Confirm the tag is real (tags shift over time):

```bash
git ls-remote --tags https://github.com/ansible-lockdown/RHEL10-CIS.git | tail -5
```

### Step 2 — discover collections FROM THE ROLE

```bash
cat roles/RHEL10-CIS/meta/main.yml | grep -A5 "^collections:"
```

> [!success] Verified 2026-08-25 — all three roles declare the same three
> ```yaml
> collections:
>   - community.general
>   - community.crypto
>   - ansible.posix
> ```
> Still run the command — it's the *method* being graded, and it proves the
> answer for whatever tag you actually installed.

### Step 3 — add and install

```yaml
collections:
  - name: community.general
  - name: community.crypto
  - name: ansible.posix
```

```bash
ansible-galaxy collection install -r requirements.yml -p collections/ --force
```

> [!warning] Why collections are needed at all
> `ansible-core` ships **zero** community collections. The role calls
> `community.general.filesystem`, `community.general.modprobe`, etc. Skip
> this and you get, mid-run:
> `couldn't resolve module/action 'community.general.filesystem'`.

> [!danger] Pin the tag. Never track `main`. Never fork the role.
> **Pin:** CIS renumbers rules between benchmark versions — an unpinned
> `main` silently changes what you enforce, and your score moves for reasons
> absent from your history.
> **Don't fork:** edit a task and you own upstream merge conflicts forever.
> Everything configurable is already in `defaults/main.yml`. Reaching to edit
> a task = you haven't read the defaults carefully enough.

## 2.4 `playbook.yml`

```yaml
---
- name: CIS Level 1 hardening
  hosts: terminated_cadet
  become: true

  vars:
    # PRECEDENCE #12 — play vars, beats group_vars
    rhel10cis_pass_max_days: 90

  pre_tasks:
    - name: Confirm this is the right OS before hardening it
      ansible.builtin.assert:
        that:
          - ansible_facts['distribution'] == 'AlmaLinux'
          - ansible_facts['distribution_major_version'] == '10'
        fail_msg: >-
          Expected AlmaLinux 10, found
          {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
      tags: [always]

  roles:
    - role: RHEL10-CIS
```

### Line-by-line

> [!info]- `hosts: terminated_cadet` — a *pattern*, not a hostname
> Matched against inventory at play start. Also valid: `all`,
> `grp1:grp2` (union), `grp1:!grp2` (exclude), `*.example.com`.

> [!info]- `become: true` here *and* in `ansible.cfg` — redundant on purpose
> A play should be self-explanatory without cross-referencing `ansible.cfg`.
> Defensible as documentation, not dead weight.

> [!info]- `pre_tasks:` — a reserved keyword with guaranteed ordering
> Execution order is **`pre_tasks` → `roles` → `tasks` → `post_tasks`**
> (handlers flushed at each boundary). This *guarantees* the OS check runs
> before the role touches anything — not a stylistic choice.
> **Why it earns its place:** the role is 400–600 tasks / several minutes.
> Discovering you installed `RHEL9-CIS` against AlmaLinux 10 ten minutes in
> is far worse than failing in two seconds.

> [!info]- `ansible.builtin.assert` — why the full FQCN
> Since 2.10 every module lives in a **collection**. `ansible.builtin` ships
> with `ansible-core`. Bare `assert:` still works via fallback search, but is
> **ambiguous** once other collections are installed. Full name = zero doubt
> which ran.

> [!info]- `ansible_facts[...]` — where the data comes from
> Before your first task, Ansible implicitly runs `ansible.builtin.setup` on
> the target (unless `gather_facts: false`), returning a large dict of system
> info stored as `ansible_facts`. That's why it has a value in the very first
> task. (Older flat form `ansible_distribution` also exists for compat; the
> dict form is current style.)

> [!info]- `fail_msg: >-` — YAML folded block scalar
> `>` folds newlines into spaces (wrap long text across source lines);
> trailing `-` strips the final newline. Message prints as one clean sentence.
> ⚠️ Every module arg — including `fail_msg` — is **templated up front**,
> *before* `that:` is evaluated. A typo'd variable inside `fail_msg` breaks
> the task immediately even when the assertion would have passed.

> [!info]- `tags: [always]` — a magic tag
> `always` runs **regardless of `--tags`/`--skip-tags`** (unless you pass
> `--skip-tags always`). That's why the safety check carries it: no matter
> how the CIS run is scoped, the OS guard can't be filtered out.
> ⚠️ `tags:` is a **task-level keyword** — it must align with `name:` and
> `ansible.builtin.assert:`, **not** be nested inside the module's args
> beside `that:`/`fail_msg:`. Wrong indentation →
> `Unsupported parameters ... : tags`.

> [!info]- `roles:` → `- role: RHEL10-CIS`
> Resolved via `roles_path`. This is the moment the role's
> `defaults/main.yml` enters the variable space — at the **lowest**
> precedence (#2), which is exactly why your `group_vars` / play vars /
> extra-vars can override it. Dict form (`- role: X`) allows attaching
> role-scoped `vars:`/`tags:`.

## 2.5 `group_vars/all/vars.yml`

⚠️ **Swap `rhel10cis_` for your actual prefix.**

```yaml
---
# ── Scope: Level 1, Server only ─────────────────────────────
rhel10cis_level_1: true
rhel10cis_level_2: false

# ── TAILORING (precedence #5) ───────────────────────────────
rhel10cis_warning_banner: "AUTHORIZED ACCESS ONLY — ACTIVITY IS MONITORED"

# Logging backend — 8 defaults rsyslog; 9/10 default journald
rhel10cis_syslog: journald

# Password aging — 180 here is PRECEDENCE #5.
# Deliberately different from the play-vars and extra-vars values so the
# override chain is provable on the host afterwards. See Part 3.
rhel10cis_pass_max_days: 180
rhel10cis_pass_min_days: 7
rhel10cis_pass_warn_age: 7

# No account lockout (user AND root)
# ⚠️ RHEL8/9 = 5_3_3_1_x   |   RHEL10 = 5_3_2_1_x
rhel10cis_rule_5_3_2_1_1: false
rhel10cis_rule_5_3_2_1_2: false
rhel10cis_rule_5_3_2_1_3: false

# ── REQUIRED — role refuses to start otherwise ──────────────
rhel10cis_authselect_custom_profile_name: terminated_cadet_profile   # RHEL10 asserts this
rhel10cis_sshd_allowusers: "ansible"
rhel10cis_set_boot_pass: true
rhel10cis_bootloader_password_hash: "{{ vault_bootloader_password_hash }}"

# ── Practical run-time choices ──────────────────────────────
rhel10cis_rule_1_2_2_1: false      # skips full `dnf update` (~20 min saved)

# ── Sudo: PICK ONE of the two lines below, not both ─────────
# Option B — keep the control ON, exempt only this account (RHEL 9/10 only):
rhel10cis_sudoers_exclude_nopasswd_list:
  - ansible
# Option C — blunt: disable the control entirely (works on 8/9/10):
# rhel10cis_rule_5_2_4: false
# See THE SUDO TRAP. Option A (--ask-become-pass) needs neither line.

# ── Goss audit ──────────────────────────────────────────────
setup_audit: true
run_audit: true
fetch_audit_output: true
audit_output_destination: "{{ playbook_dir }}/audit_reports/"
```

> [!warning] Don't set both sudo options at once
> `rhel10cis_rule_5_2_4: false` disables the rule entirely — which means the
> exclusion list is never consulted, because the task that would read it never
> runs. Setting both isn't harmful, but it's incoherent to defend: *"I exempted
> one account from a control I also turned off."* Pick one and be able to say
> why.

> [!danger] A typo'd variable produces NO error
> Ansible silently defines an unused variable; the role keeps its default;
> your tailoring does nothing. **Always verify on the host afterwards** — see
> [[#✅ VERIFY ON THE HOST]].

> [!tip] `group_vars/all/` is auto-loaded — no `vars_files:` needed
> Anything in `group_vars/all/*.yml` (including the encrypted `vault.yml`)
> loads automatically for every host, because of the directory name. You do
> **not** need `vars_files:` in the playbook — adding it can cause the vault
> file to be loaded twice. Files in `group_vars/<groupname>.yml` load only for
> that group, at the same precedence level.

## 2.6 Ansible Vault

```bash
grub2-mkpasswd-pbkdf2                        # generate a REAL hash first
ansible-vault create group_vars/all/vault.yml
```

```yaml
---
vault_bootloader_password_hash: "grub.pbkdf2.sha512.10000.<salt>.<hash>"
```

Reference it from the **plain, committed** `vars.yml`:
```yaml
rhel10cis_bootloader_password_hash: "{{ vault_bootloader_password_hash }}"
```

```bash
ansible-vault view group_vars/all/vault.yml
ansible-vault edit group_vars/all/vault.yml
ansible-playbook playbook.yml --ask-vault-pass
```

> [!danger] `--vault-password-file` wants the PASSWORD file, not `vault.yml`
> Pointing it at the vault itself (the locked box, not the key) is a classic
> error with a confusing decryption failure. Encrypted `vault.yml` **is**
> committed; the password file **never** is.

---

# Part 3 — Variable precedence (they WILL ask)

```
role defaults (#2)  <  group_vars (#5)  <  play vars (#12)  <  --extra-vars (#22)
     lowest                                                        always wins
```

**Demonstrate at three levels** — that's the usual requirement:

| Variable | Value | Set where | Level | Overrides | Why it wins |
|---|---|---|---|---|---|
| `rhel10cis_warning_banner` | AUTHORIZED… | `group_vars/all/vars.yml` | **#5** | role defaults (#2) | group_vars load after role defaults; permanent config belongs in a reviewable file |
| `rhel10cis_pass_max_days` | `90` | play `vars:` | **#12** | group_vars (#5) | play vars are more specific than group vars |
| `rhel10cis_syslog` | `journald` | `group_vars` | **#5** | role defaults (#2) | permanent, reviewable, brief-mandated |

### The strongest demo: **one** variable at **all three** levels

Setting three *different* variables at three levels only proves you can put
things in three files. Setting the **same** variable at three levels, with
three **different values**, proves you know which one actually wins — and it's
verifiable on the host in one command.

| Level | Where | Value |
|---|---|---|
| #2 role default | `roles/RHEL10-CIS/defaults/main.yml` | `365` |
| **#5** group_vars | `group_vars/all/vars.yml` | `180` |
| **#12** play vars | `playbook.yml` → `vars:` | `90` |
| **#22** extra-vars | command line | **`30`** ← wins |

```bash
ansible-playbook playbook.yml -e 'rhel10cis_pass_max_days=30'
```

**Prove it on the host — this is the money shot in the presentation:**

```bash
ssh ansible@<ip> 'grep PASS_MAX_DAYS /etc/login.defs'
# → PASS_MAX_DAYS   30      (not 365, not 180, not 90)
```

> [!tip] The honest point about `--extra-vars`
> It always wins — which is exactly why it's the **wrong** home for permanent
> config: it's invisible in git. Someone reading the whole repo cannot tell it
> took effect. Great for *demonstrating* precedence and for genuine one-offs;
> bad as where real decisions live.

> [!question]- If asked "why is 365 in the role but 30 on the box?"
> Four sources set the same variable; Ansible resolves them by a fixed
> precedence order and the **last writer wins**. The role's `defaults/` is
> deliberately the *lowest* precedence — that's what makes a role
> configurable without editing it. Nothing was overwritten or lost; the lower
> values simply never applied.

---

# Part 4 — Run it

```bash
ansible-playbook playbook.yml --syntax-check      # ~2s, catches YAML + module-name typos
ansible-playbook playbook.yml --list-tasks        # what would run, in order

# The real run — this is the command to memorise
ansible-playbook playbook.yml \
  --ask-vault-pass \
  --ask-become-pass \
  -e 'rhel10cis_pass_max_days=30' \
  --skip-tags "level2-server,level2-workstation"
```

| Flag in that command | Why it's there |
|---|---|
| `--ask-vault-pass` | any variable resolving through `vault.yml` needs it |
| `--ask-become-pass` | supplies the sudo password so you don't depend on `NOPASSWD` — see [[#🔥 THE SUDO TRAP]]. Drop it **only** if `sudo -n true` works and you've exempted the account |
| `-e 'rhel10cis_pass_max_days=30'` | your precedence **#22** demonstration |
| `--skip-tags "level2-server,level2-workstation"` | scopes the run to **Level 1** |

> [!warning] `--syntax-check` does NOT catch everything
> It validates YAML structure and module-name resolution only. It does **not**
> evaluate Jinja — a typo'd `{{ ansible_facts }}` passes syntax-check and
> fails at runtime.

> [!info] What the tags actually are — so you can explain `--skip-tags`
> Every task in the role carries tags. The ones that matter:
> - **`level1-server`** / **`level1-workstation`** — CIS Level 1 profiles
> - **`level2-server`** / **`level2-workstation`** — Level 2 (defence-in-depth, may break things)
> - **`patch`** — tasks that change state · **`audit`** — tasks that only check
> - **`rule_5.2.5`** — every rule has its own tag, so you can run exactly one
> - **`always`** — runs no matter what you skip (see the `tags: [always]` note)
>
> ```bash
> ansible-playbook playbook.yml --list-tags          # everything available
> ansible-playbook playbook.yml --tags rule_5.2.5    # run ONE rule, for testing
> ```
> Skipping Level 2 is *tag-based*, which is why it can't skip an `always`-tagged
> prelim check — the exact reason rule 5.2.4 can still abort a Level 1 run.

> [!tip] A failed run is safe to just re-run
> Ansible modules are **idempotent** — they describe desired state, not
> actions. Fix the cause and re-run the whole playbook; already-correct tasks
> report `ok` and change nothing. You do **not** need to rebuild the VM or use
> `--start-at-task` (which is fragile — it skips handler notifications from
> earlier tasks).

### Troubleshooting flags

| Flag | Use |
|---|---|
| `--syntax-check` | parse only |
| `--list-tasks` / `--list-tags` | see what would run / what's filterable |
| `-C` / `--check` | dry run |
| `--diff` | show file before/after |
| `-v` / `-vv` / `-vvv` | `-vvv` shows module args + SSH commands |
| `--limit <host>` | one host only |
| `--start-at-task "<name>"` | resume partway |
| `-K` / `--ask-become-pass` | prompt for sudo password |

### Reading the recap

```
node1 : ok=479  changed=60  unreachable=0  failed=1  skipped=272
```

| Field | Meaning |
|---|---|
| `ok` | ran, nothing to change / succeeded |
| `changed` | actually modified something — should trend to 0 on a 2nd run (**idempotency**) |
| `unreachable` | connection problem, not a playbook problem |
| `failed` | ⚠️ the signal that matters |
| `skipped` | tag/`when:` filtered — expected if it matches your `--skip-tags` |

---

# 🔥 THE SUDO TRAP

> [!danger] The single most likely thing to derail your run
> You set `NOPASSWD` so `become` wouldn't prompt. **Rule 5.2.4 exists
> specifically to find and remove exactly that.** It rewrites your
> `NOPASSWD` → `PASSWD` mid-run, then the next `become` task fails with
> `Missing sudo password` — hundreds of tasks in.

**Confirm it's what happened:**
```bash
ssh ansible@<ip> 'sudo -n true' || echo "NOPASSWD was stripped"
```

**Three legitimate fixes — pick per version:**

| Fix | Works on | Trade-off |
|---|---|---|
| **A.** `--ask-become-pass` / vaulted `ansible_become_password` | **8, 9, 10** | Removes the `NOPASSWD` dependency entirely — arguably the *most* defensible: no account has blanket passwordless sudo, control genuinely satisfied |
| **B.** `rhel<N>cis_sudoers_exclude_nopasswd_list: [ansible]` | **9, 10 only** | Role's own documented exclusion mechanism (ships with `ec2-user`/`vagrant` examples — same purpose) |
| **C.** `rhel<N>cis_rule_5_2_4: false` | 8, 9, 10 | Blunt; disables the control. Document it as a tailoring decision if used |

**Fix A (universal, recommended):**
```bash
ansible-playbook playbook.yml --ask-vault-pass --ask-become-pass
```
Persist it instead of retyping:
```yaml
# group_vars/all/vars.yml
ansible_become_password: "{{ vault_ansible_become_password }}"
```

**Restore a stripped sudoers file:**
```bash
ssh -t ansible@<ip> 'echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-ansible'
```

> [!warning] Reinstalling the VM does NOT fix this
> Same rule strips the same entry on a fresh install. Root password is
> irrelevant — 5.2.4 targets whatever account has `NOPASSWD`, not root.

---

# 🔍 PRE-FLIGHT GREPS — run these right after installing the role

Two minutes here saves a failed 400-task run.

```bash
R=roles/RHEL10-CIS      # ← your role

# 1. Every variable the role exposes (GROUND TRUTH — not your notes)
grep -rn "^rhel10cis_" $R/defaults/main.yml | less

# 2. Fail-fast assertions — the "you must set this" tripwires
grep -rn -A6 "assert:" $R/tasks/main.yml | less

# 3. THE THREE THAT CAN CUT OFF YOUR OWN ACCESS
grep -rl "sudoers\|become"                          $R/tasks/    # privilege escalation
grep -rl "sshd_config\|PermitRootLogin\|AllowUsers" $R/tasks/    # SSH itself
grep -rl "faillock\|pam_faillock"                   $R/tasks/    # account lockout

# 4. Which mount-point rules are actually Level 1 (differs per role!)
grep -rl "mount\|partition" $R/tasks/ | xargs grep -l "level1-server"

# 5. always-tagged prelim checks that --skip-tags CANNOT skip
grep -rn -B5 "tags:.*always" $R/tasks/*.yml | grep -A5 assert
```

> [!danger] Assertions verified 2026-08-25 — the complete list
> **All three roles** assert on:
> - OS is RedHat-family and the major version matches the role
> - `ansible_version >= min_ansible_version` (`2.16.1` for all three)
> - `rhel<N>cis_crypto_policy` ∈ `rhel<N>cis_allowed_crypto_policies`
> - `rhel<N>cis_additional_crypto_policy_module` ∈ allowed modules
> - `rhel<N>cis_bootloader_password_hash != 'grub.pbkdf2.sha512.changethispassword'`
>   **OR** (`_bootloader_salt != ''` **AND** `_bootloader_password != 'password'`)
>   → note the **OR**: you can satisfy it *either* with a real PBKDF2 hash *or*
>   by setting salt + a non-default plaintext password. The hash is better;
>   the second path is the time-pressure fallback.
>
> **RHEL9-CIS and RHEL10-CIS additionally** assert (gated on
> `rhel<N>cis_rule_5_2_4`, on by default):
> - the connecting account (`rhel<N>cis_playbook_user`, defaults to
>   `ansible_user`) **has a password** — not empty, not `!!`
> - that account is **not locked** — no leading `!` in its shadow entry
>
> **RHEL10-CIS additionally:**
> - `rhel10cis_authselect_custom_profile_name != 'cis_example_profile'`
>   → *"You still have the default name for your authselect profile"*
> - `passwd -S root` returns `P` or `L` (gated on `rhel10cis_rule_5_4_2_4`)
>   → *"requires that you have a root password set or locked"*
>
> **All three:** `rhel<N>cis_sshd_allowusers` must not be undefined — the role
> feeds it to a `join(' ')` filter and a null raises `TypeError`.

---

# ✅ VERIFY ON THE HOST

> [!important] The recap is not proof. The host is.
> A typo'd variable produces no error — the only real evidence is the live
> system. This is also exactly what you demo during the presentation.

```bash
IP=<vm-ip>; S="ssh ansible@$IP"

$S 'cat /etc/issue.net'                              # banner
$S 'sudo sshd -T | grep -E "allowusers|clientalive|permitrootlogin"'
$S 'sudo grep -E "PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE" /etc/login.defs'
$S 'systemctl is-enabled rsyslog systemd-journald'   # logging backend
$S 'sudo faillock --user ansible'                    # lockout state
$S 'lsblk -f'                                        # partitions/filesystems
$S 'sudo authselect current'                         # active PAM profile
$S 'cat /sys/firmware/efi/fw_platform_size'          # 64 = UEFI (absent = BIOS)
```

**Goss report** (fetched back by `fetch_audit_output`):

```bash
ls -la audit_reports/          # expect a pre_scan and a post_scan JSON per host
```

Read the score — `jq` is installed and by far the cleanest:

```bash
# Per-file summary
for f in audit_reports/*.json; do
  echo "--- $f"
  jq '.summary' "$f"
done

# Just the numbers that matter
jq '.summary | {total: ."total-count", failed: ."failed-count"}' audit_reports/*post*.json
```

No `jq`? Use Python **one file at a time** — `python3 -m json.tool` accepts
only a single file and silently produces nothing when given a glob:

```bash
for f in audit_reports/*.json; do
  echo "--- $f"
  python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('summary'))" "$f"
done
```

**Compute the percentage yourself** — that's the number you present:

```
compliance % = (total - failed) / total × 100
```

> [!important] Present the *before and after*, not just the final number
> The role runs Goss **twice** — `pre_scan` before remediation, `post_scan`
> after. "47 of 711 failing, 93.4%" is fine; **"231 failing → 47 failing,
> 67.5% → 93.4%"** is the answer that shows the pipeline did something. Have
> both.

> [!tip] The strongest single thing you can demo: run it twice
> ```bash
> ansible-playbook playbook.yml --ask-vault-pass --ask-become-pass \
>   --skip-tags "level2-server,level2-workstation"
> ```
> A second run on an already-hardened box should report **`changed=0`** (or
> very near it). That is a live, unarguable demonstration of **idempotency** —
> the property that makes configuration management trustworthy. If `changed`
> is still high on run two, something is *not* converging and that's worth
> knowing before an examiner finds it.

---

# 🎤 PRESENTATION & Q&A

> [!question]- Why a role instead of hardening by hand?
> Consistency, repeatability, and an auditable trail. Every decision is a
> named variable in a reviewable file — not a one-off `sed` nobody can
> reconstruct. Re-running reproduces the exact same state.

> [!question]- Why pin to a release tag?
> CIS renumbers rules between benchmark versions. Unpinned, an upstream
> commit silently changes what you enforce and your score moves for reasons
> invisible in your own history.

> [!question]- Why not fork and edit the role?
> Every knob is already in `defaults/main.yml`. Editing tasks means owning
> upstream merge conflicts forever, for a change that was already possible
> through a variable.

> [!question]- Explain your precedence table.
> Have the actual table (Part 3): variable, value, where set, what it
> overrides, and **why that's the right home** for a permanent decision vs. a
> one-off.

> [!question]- Why Goss instead of trusting Ansible's recap?
> Ansible's `ok` means "my model says this is fine." A task can report success
> while the change never took effect — service not reloaded, a later drop-in
> overrode it, SELinux blocked the write. Goss re-reads the actual file,
> queries the actual service, checks the actual port, with **zero knowledge of
> Ansible**. Independent verification is the only kind that counts.

> [!question]- Your score, and three failures explained
> Have real numbers (pre/post, %) and three concrete failing checks:
> typically (1) a deliberately tailored-off rule, (2) a rule depending on a
> partition you don't have, (3) a reboot-dependent sysctl/kernel-module
> setting the role doesn't reboot for mid-run.

> [!question]- Is 90%+ with exceptions worse than 100%?
> No — **100% reached by switching rules off is weaker than 90% with
> documented exceptions.** The documentation is what proves a human
> understood each deviation. A Goss report can't distinguish a deliberate
> exception from a genuine break; that's what your tailoring table is for.

> [!question]- Why did you disable account lockout?
> Brief requirement + real justification: a single automation account means
> one failed run locks the box with no self-recovery path. **Compensating
> controls:** key-only SSH, `PasswordAuthentication no`, `AllowUsers ansible`,
> host rebuildable from scratch. Password brute-force has no reachable surface.

> [!question]- Hardening broke SSH — recover?
> Four causes: **sshd** (`AllowUsers`, crypto policy), **PAM** (faillock),
> **firewall**, **mount options** (`noexec`).
> Diagnose from outside: `nc -vz <ip> 22` → refused = sshd down, timeout =
> firewall, open = auth. Get in via **Cockpit console** (bypasses sshd
> entirely — this is why you set a root password).
> ⚠️ **Never close your only working session** until a second way in is proven.

---

# 🧰 IF ASKED TO ADD YOUR OWN TASKS

Common asks, ready to paste. Put in `pre_tasks:` (before hardening) or
`post_tasks:` (after).

> [!example]- Format & mount a data disk
> ```yaml
> post_tasks:
>   - name: Create filesystem on data disk
>     community.general.filesystem:
>       fstype: xfs            # or ext4
>       dev: /dev/vdb
>
>   - name: Mount it persistently
>     ansible.posix.mount:
>       path: /data
>       src: /dev/vdb
>       fstype: xfs
>       opts: defaults,nodev,nosuid
>       state: mounted
> ```
> Detect by **shape, not name** (device order isn't guaranteed):
> ```yaml
> - name: Find unpartitioned data disks
>   ansible.builtin.set_fact:
>     data_disks: >-
>       {{ ansible_facts.devices | dict2items
>          | selectattr('value.partitions', 'eq', {})
>          | selectattr('value.sectors', 'ge', 1000000)
>          | map(attribute='key') | list | sort }}
> ```

> [!example]- Create users / groups
> ```yaml
> - name: Ensure group exists
>   ansible.builtin.group:
>     name: devops
>     state: present
>
> - name: Create user with SSH key
>   ansible.builtin.user:
>     name: alice
>     groups: [wheel, devops]
>     append: true
>     shell: /bin/bash
>     create_home: true
>     password: "{{ vault_alice_password_hash }}"   # mkpasswd -m sha512crypt
>
> - name: Install her key
>   ansible.posix.authorized_key:
>     user: alice
>     key: "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
>     state: present
> ```

> [!example]- Install packages / manage services
> ```yaml
> - name: Install packages
>   ansible.builtin.dnf:
>     name: [vim, git, tmux, chrony]
>     state: present
>
> - name: Enable and start a service
>   ansible.builtin.service:
>     name: chronyd
>     state: started
>     enabled: true
> ```

> [!example]- Firewall rules
> ```yaml
> - name: Allow a service
>   ansible.posix.firewalld:
>     service: https
>     permanent: true
>     immediate: true
>     state: enabled
>
> - name: Allow a port
>   ansible.posix.firewalld:
>     port: 8080/tcp
>     permanent: true
>     immediate: true
>     state: enabled
> ```

> [!example]- Files, templates, lines
> ```yaml
> - name: Deploy a config from template
>   ansible.builtin.template:
>     src: templates/myapp.conf.j2
>     dest: /etc/myapp.conf
>     owner: root
>     group: root
>     mode: '0640'
>     validate: 'myapp --test -c %s'      # validate BEFORE replacing
>   notify: Restart myapp
>
> - name: Ensure a single line is set
>   ansible.builtin.lineinfile:
>     path: /etc/security/limits.conf
>     regexp: '^\*\s+hard\s+core'
>     line: '*  hard  core  0'
>
> - name: Drop-in directory file (preferred over editing main configs)
>   ansible.builtin.copy:
>     content: "ClientAliveInterval 300\n"
>     dest: /etc/ssh/sshd_config.d/60-timeout.conf
>     mode: '0600'
>   notify: Restart sshd
>
> handlers:
>   - name: Restart sshd
>     ansible.builtin.service:
>       name: sshd
>       state: restarted
> ```

> [!example]- sysctl / kernel parameters
> ```yaml
> - name: Set a kernel parameter
>   ansible.posix.sysctl:
>     name: net.ipv4.conf.all.rp_filter
>     value: '1'
>     state: present
>     reload: true
>     sysctl_file: /etc/sysctl.d/99-custom.conf
> ```

> [!example]- Cron / scheduled tasks
> ```yaml
> - name: Nightly audit job
>   ansible.builtin.cron:
>     name: "nightly goss audit"
>     minute: "0"
>     hour: "2"
>     job: "/usr/local/bin/goss -g /etc/goss.yaml validate > /var/log/goss.log 2>&1"
> ```

> [!tip] Finding module docs offline — no internet needed
> ```bash
> ansible-doc ansible.builtin.user            # full docs
> ansible-doc -s ansible.posix.mount          # snippet: just the options
> ansible-doc -l | grep -i firewall           # search installed modules
> ansible-doc -t callback -l                  # list callback plugins
> ```
> **This works with no network** and is allowed — it's the official docs
> shipped with your install. `ansible-doc -s <module>` prints a ready-to-paste
> YAML skeleton of every option, which is faster than remembering syntax.

> [!tip] Finding the right fact name — don't guess
> If a task needs a system value (`ansible_facts['...']`), dump the real facts
> and search them:
> ```bash
> ansible node1 -m setup | less                              # everything
> ansible node1 -m setup -a 'filter=ansible_distribution*'    # narrow by glob
> ansible node1 -m setup -a 'filter=ansible_mounts'
> ansible node1 -m setup -a 'filter=ansible_devices'          # disks
> ```
> This is also how you confirm a fact exists *before* referencing it in a
> playbook, rather than discovering it's undefined mid-run.

> [!tip] Password hashes for the `user` module
> `password:` needs a **hash**, never plaintext. Two ways:
> ```bash
> mkpasswd -m sha512crypt                 # from the 'whois' package
> openssl passwd -6                       # fallback, always present
> ```
> Both produce a `$6$…` SHA-512 crypt string. Put it in the vault, reference it
> as `"{{ vault_alice_password_hash }}"`.

---

# 🚨 FAILURE LOOKUP

| Symptom | Cause | Fix |
|---|---|---|
| `Could not open '…iso': Permission denied` | `qemu` can't traverse `~` | `setfacl -m u:qemu:x ~` |
| `ssh-copy-id: No identities found` | no keypair **on host** | `ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519` |
| `sudo: a terminal is required` | `ssh host 'sudo …'` with no TTY | add `-t` |
| `Unable to parse … inventory` / *"No inventory was parsed"* | wrong `pwd`, doubled path | `pwd`; run from project root |
| Hangs on first connect, no error | host-key prompt nobody can answer | `host_key_checking = False` |
| `couldn't resolve module/action 'community.general.X'` | collections not installed | `ansible-galaxy collection install -r requirements.yml -p collections/ --force` |
| `couldn't resolve module/action 'ansible.builtin.X'` | **typo in the FQCN** (`asert`) | exact-string compare; `--syntax-check` |
| `Could not load 'ansible.builtin.defaults' callback` | typo — it's `default`, singular | fix `ansible.cfg` |
| `Unsupported parameters … : tags` | `tags:` nested inside module args | align `tags:` with `name:` |
| `resolving value for 'fail_msg': 'X' is undefined` | typo'd var in Jinja; args templated up front | fix spelling |
| `Missing sudo password` at task 1 | no `NOPASSWD`, no `-K` | sudoers file, or `--ask-become-pass` |
| `Missing sudo password` **mid-run** | rule 5.2.4 stripped it | [[#🔥 THE SUDO TRAP]] |
| *"You still have the default name for your authselect profile"* | RHEL10 assertion | set `rhel10cis_authselect_custom_profile_name` |
| *"…bootloader_password… not been set correctly"* | shipped placeholder hash | `grub2-mkpasswd-pbkdf2` → vault, **or** set `_bootloader_salt` + non-default `_bootloader_password` |
| *"…user = ansible is locked - It can break access"* | you ran `passwd -l ansible`; RHEL9/10 assert it's unlocked | `sudo passwd -u ansible` (unlock), or set `rule_5_2_4: false` |
| *"…user = ansible has no password set…"* | account has `!!`/empty password | `sudo passwd ansible` — set a real one |
| *"requires that you have a root password set or locked"* | RHEL10 `rule_5_4_2_4`; `passwd -S root` ≠ P/L | `sudo passwd root` |
| *"Crypto policy is not a permitted version"* | `_crypto_policy` not in the allowed list | leave it at `DEFAULT` unless the brief says otherwise |
| `Conditional result (True) … must have a boolean result` | role bug + `ansible-core ≥2.19` | `allow_broken_conditionals = True` |
| Play aborts on 5.2.4 despite `--skip-tags level2-server` | prelim check tagged `always` | `rhel<N>cis_rule_5_2_4: false` |
| Modules fail after `/tmp` hardening | `/tmp` mounted `noexec` | `remote_tmp = ~/.ansible/tmp` in `ansible.cfg` |
| `rc: 137` during Goss parsing | OOM | give the VM ≥3–4 G RAM |
| SSH dies mid-hardening | sshd/PAM/firewall/mount | Cockpit console; `nc -vz <ip> 22` to classify |

---

# 📋 THE ONE-PAGE RUN

```bash
# ── HOST PREP ───────────────────────────────────────────────
ls ~/.ssh/*.pub || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
setfacl -m u:qemu:x ~

# ── COCKPIT ─────────────────────────────────────────────────
# https://localhost:9090 → Virtual Machines → Create VM
# ISO from ~/Downloads/ · 20G · 4096 MiB · UEFI if required
# Anaconda: NETWORK ON · user 'ansible' + Administrator + PASSWORD TICKED · root pw

# ── ACCESS ──────────────────────────────────────────────────
virsh -c qemu:///system domifaddr terminated-cadet
ssh-copy-id ansible@<ip>
ssh -t ansible@<ip> 'echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-ansible'
ssh -t ansible@<ip> 'sudo chmod 440 /etc/sudoers.d/90-ansible'
ssh ansible@<ip> 'sudo -n true && echo SUDO-OK'

# ── PROJECT ─────────────────────────────────────────────────
mkdir -p ~/terminated-cadet/{inventory,group_vars/all,roles,collections} && cd ~/terminated-cadet
# write inventory/hosts.yml + ansible.cfg
ansible all -m ping                                   # MUST be pong

# ── ROLE ────────────────────────────────────────────────────
# requirements.yml: role only → install → discover → add collections → install
ansible-galaxy role install -r requirements.yml -p roles/ --force
cat roles/RHEL<N>-CIS/meta/main.yml | grep -A5 "^collections:"
ansible-galaxy collection install -r requirements.yml -p collections/ --force

# ── PRE-FLIGHT (2 min, saves 40) ────────────────────────────
grep -rn "^rhel<N>cis_" roles/RHEL<N>-CIS/defaults/main.yml | less
grep -rn -A6 "assert:" roles/RHEL<N>-CIS/tasks/main.yml
grep -rl "sudoers\|sshd_config\|faillock" roles/RHEL<N>-CIS/tasks/

# ── SECRETS ─────────────────────────────────────────────────
grub2-mkpasswd-pbkdf2
ansible-vault create group_vars/all/vault.yml

# ── RUN ─────────────────────────────────────────────────────
# ⚠️ RHEL9/10: do NOT `passwd -l ansible` — the role asserts it's unlocked
ansible-playbook playbook.yml --syntax-check
ansible-playbook playbook.yml --ask-vault-pass --ask-become-pass \
  -e 'rhel<N>cis_pass_max_days=30' \
  --skip-tags "level2-server,level2-workstation"

# Re-run after ANY failure — modules are idempotent, nothing is lost
# Second clean run should show changed=0 → live proof of idempotency

# ── VERIFY ON THE HOST, NOT THE RECAP ───────────────────────
ssh ansible@<ip> 'cat /etc/issue.net; sudo sshd -T | grep -E "allowusers|clientalive"'
ls audit_reports/
```

> [!warning] Order of operations that saves the most time
> **ping → pre-flight greps → syntax-check → run.**
> Every one of those catches a class of failure that would otherwise surface
> 10–40 minutes into a run.
