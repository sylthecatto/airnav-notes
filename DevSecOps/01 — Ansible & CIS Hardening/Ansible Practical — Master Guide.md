---
tags:
  - airnav-cadet
  - ansible
  - cis
  - exam-prep
  - cockpit
status: study-guide
exam: Wednesday — Ansible only, no Packer/Terraform/Jenkins, no AI
---

# Ansible Practical — Master Guide

> [!danger] What's actually being tested Wednesday
> **Ansible only.** No Packer, no Terraform, no Jenkins. You'll get a random
> AlmaLinux **8, 9, or 10** ISO, install it into a VM **through Cockpit**, then
> write everything by hand: inventory, `ansible.cfg`, `requirements.yml`,
> `group_vars`, `playbook.yml` — pull the matching `RHEL<N>-CIS` role, harden
> to Level 1, and be ready to explain every decision live. **No AI in the
> room** — official docs, your own notes, and Google are fine. This file is
> the notes.

## How to use this under time pressure

Two hours, four things: VM up → Ansible written → hardening run → ready to
explain. **Part VII is the cheat sheet** — if your brain blanks mid-exam,
that's the page to jump to. Everything before it is here so the cheat sheet
actually makes sense instead of being magic incantations.

## Map of Content

| Part | What it covers |
|---|---|
| [[#Part I — Creating the VM in Cockpit]] | Cockpit's Machines plugin, from ISO to a reachable IP |
| [[#Part II — Ansible From Scratch, By Hand]] | Every file: `ansible.cfg`, inventory, `requirements.yml`, `playbook.yml`, `group_vars` |
| [[#Part III — Finding the Role's Real Variables Yourself]] | The skill that matters more than memorized variable names |
| [[#Part IV — Variable Precedence, Demonstrated]] | The table you'll be asked to produce and defend |
| [[#Part V — Running It, Reading the Output, Fixing It]] | Invocation flags, the recap, real failure patterns |
| [[#Part VI — Presentation and Q&A Prep]] | Questions to have answers for, cold |
| [[#Part VII — The Cheat Sheet]] | One page, everything, no explanation — for when the clock is loud |

---

# Part I — Creating the VM in Cockpit

> [!info] Why this section exists
> You've mostly used virt-manager. Cockpit's Machines plugin does the same
> job through a browser, and it's what you'll be graded on using. The
> concepts are identical (same libvirt underneath) — only the clicks differ.

## Step 0 — two one-time checks on your host, before opening Cockpit

Both take ten seconds and prevent the two most common ways this stalls out
before you've even installed anything.

**You need an SSH keypair on your host machine.** Not the VM — your actual
machine, the one you'll run `ssh` and `ansible` from. Check first, don't
assume:

```bash
ls ~/.ssh/*.pub 2>/dev/null || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
```

Using the default filename means both `ssh` and Ansible find it
automatically later — nothing to reference by path anywhere.

**Cockpit's Machines plugin uses the system libvirt connection
(`qemu:///system`) by default**, which means the actual VM process runs as a
dedicated `qemu` system user — not you. Most home directories are `0700`, so
that user can't even *traverse into* yours to reach an ISO sitting in
`~/Downloads/`, regardless of the ISO file's own permissions. Grant it
pass-through access once, up front:

```bash
setfacl -m u:qemu:x ~
getfacl ~ | grep qemu             # confirm: user:qemu:--x
```

This grants traversal only — not directory listing, not read access to
anything else in your home directory.

## Getting into Cockpit

```bash
systemctl status cockpit.socket   # should be active
```

Browse to `https://localhost:9090` (or the host's IP from another machine).
Log in with your Linux user + sudo password. If prompted, tick **"Reuse my
password for privileged tasks"** — without it, every libvirt action prompts
again.

## Creating the VM

**Virtual Machines** (left sidebar) → **Create VM**.

| Field | What to set | Why |
|---|---|---|
| Name | something you'll type a lot — `cis-lab` is fine | shows in `virsh list` |
| Installation type | **Local install media** | you have the ISO already downloaded |
| Installation source | browse to the `.iso` in `~/Downloads/` | |
| Operating system | Cockpit usually auto-detects from the ISO filename; if not, pick the closest AlmaLinux/RHEL match | affects some defaults, not critical |
| Storage | new qcow2, **≥20 GiB** | matches the brief's usual disk-size expectation |
| Memory | **2048 MiB** minimum, 3072–4096 if you can spare it | the CIS role's Goss JSON parsing can OOM-kill at 2048 — seen this firsthand on Pair A/B |
| Immediately start VM | leave checked | |

> [!warning] Storage pool
> Cockpit defaults to libvirt's `default` pool unless you point it elsewhere.
> If the brief says "your own pool, not `default`" — same rule as the Pair
> A/B briefs had — create a pool first: **Storage Pools → Create Storage
> Pool**, type `dir`, pick a path like `/var/lib/libvirt/pool_lab`, **then**
> come back to Create VM and select it under a storage dropdown (may need
> "Custom storage" / advanced options depending on Cockpit version). If the
> exam brief says nothing about pools, don't bother — `default` is fine.

## UEFI — check before you click Create

If the brief wants UEFI (it usually does, matching the Pair A/B pattern),
expand **Firmware** and pick **UEFI**, not BIOS. This matters because you
can't cleanly convert a running VM from BIOS to UEFI after the fact — get it
right at creation.

## Installing the OS

Click **Create**, then open the VM and use the **Console** tab — this is
Cockpit's in-browser VNC viewer, same thing `virt-manager`'s console does.

Click through Anaconda's graphical or text installer by hand:

1. Language → English
2. **Installation destination** → the one disk → **Custom** partitioning if
   the brief specifies an LVM layout (see the box below), or **Automatic** if
   it doesn't
3. **Network & hostname** → toggle the interface **on** (off by default — a
   classic "why can't I SSH in" moment) — note the hostname field too
4. **User creation** → make a user (call it whatever the brief wants —
   `ansible` is a reasonable default), tick **Administrator** (wheel), and
   **tick "Require a password to use this account."** Set a real password —
   even a throwaway one is fine, it gets replaced by key-only access in a
   minute.
5. **Begin Installation**, wait, reboot

> [!important] Why the password stays ticked, even though key-only is the end goal
> Unticking that box doesn't mean "no password needed" — it **locks** the
> account (same effect as `passwd -l`), and a locked account can't
> authenticate over SSH *or* at the console, by any method. Ticking it now
> and locking it later, only once your SSH key is confirmed working, is what
> guarantees you always have a way into the VM. Doing it the other way round
> is how you end up locked out of your own box with no recovery path short of
> the Cockpit console and a root password you may not have set either.

> [!tip] Manual LVM partitioning in Anaconda's GUI (if the brief wants it)
> Custom partitioning → **+** to add a mount point → type the mount point
> (`/`, `/var`, `/var/log`, `/var/log/audit`, `/var/tmp`, `swap`, plus
> whatever extra LV you're assigned) → for each, set **Device Type: LVM** and
> a size. `/boot` and `/boot/efi` should be **Standard Partition**, not LVM —
> same reason as always: firmware and the bootloader read them before LVM
> exists. Root: give it a floor size, Anaconda's partitioning doesn't have a
> literal `--grow` button, but leaving root's size field blank/at max after
> sizing everything else has it take the remainder.

> [!tip] Cockpit's own unattended install exists too
> The Create VM dialog has an **"Unattended Installation"** toggle that
> generates a Kickstart-equivalent behind the scenes and skips the console
> entirely. Faster, but only reach for it if you've actually rehearsed that
> exact path before Wednesday — the interactive click-through above is the
> one to default to under exam pressure, since you can see every step as it
> happens.

## After first boot — getting in, key-only, in one pass

```bash
# From the Cockpit console, or from the host without logging into the guest:
virsh domifaddr cis-lab                      # note the DHCP-assigned IP
```

Copy the key you already generated in Step 0, then lock password auth down
immediately after confirming it — three commands, in this order, every time:

```bash
ssh-copy-id ansible@<vm-ip>                  # prompts for the password you set during install

ssh ansible@<vm-ip> 'true'                   # confirm: must return with NO password prompt

ssh -t ansible@<vm-ip> 'echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-ansible'
ssh -t ansible@<vm-ip> 'sudo chmod 440 /etc/sudoers.d/90-ansible'
```

> [!important] Why `-t` is not optional on these two commands
> `sudo` needs a password here — NOPASSWD isn't in effect yet, that's what
> this step is creating — and `sudo` refuses to *prompt* for one unless a
> pseudo-terminal is attached to the session. Plain `ssh host 'command'`
> doesn't allocate one by default, regardless of whether you're authenticating
> by key or password; that's a separate setting entirely. Drop the `-t` here
> and you get `sudo: a terminal is required to read the password`, not a
> prompt. Once this file exists, every *later* `sudo` call becomes
> non-interactive by design, so `-t` stops being necessary anywhere else.

Confirm it actually landed before trusting it — a good habit generally, not
just here:

```bash
ssh ansible@<vm-ip> 'sudo -n true && echo "NOPASSWD sudo: working"'
ssh ansible@<vm-ip> 'cat /etc/sudoers.d/90-ansible; stat -c "%a %U:%G" /etc/sudoers.d/90-ansible'
# want: "NOPASSWD sudo: working", no prompt — and mode 440, owner root:root
```

Only once that's confirmed clean is it safe to lock the password down to
match the golden-image pattern from Pair A/B (`sudo passwd -l ansible`, run
over the now-proven key). This step is optional for the exam itself; Ansible
connects fine over a password too. Key-only is the nicer habit, not a
requirement — don't spend exam-clock time chasing it if the password path is
already working.

If `ssh-copy-id` itself fails to connect at all: check `systemctl status
sshd` on the guest via the Cockpit console, and that the firewall allows it —
`firewall --enabled --service=ssh` at install time, or
`sudo firewall-cmd --add-service=ssh --permanent && sudo firewall-cmd --reload`
after the fact.

---

# Part II — Ansible From Scratch, By Hand

> [!abstract] The mental model
> Ansible needs to know **three things**: *which hosts* (inventory), *what
> settings to use while connecting/running* (`ansible.cfg`), and *what to do*
> (a playbook, usually delegating the real work to a role). Everything else —
> `group_vars`, `requirements.yml` — exists to keep those three things
> organized and reusable.

## Directory layout

Build this by hand, in order:

```
ansible-lab/
├── ansible.cfg
├── inventory/
│   └── hosts.yml          # or hosts.ini — either works, YAML shown below
├── requirements.yml
├── group_vars/
│   └── all/
│       └── vars.yml       # or group_vars/<groupname>.yml, either is valid
├── playbook.yml
├── roles/                 # populated by ansible-galaxy, not hand-written
└── collections/           # populated by ansible-galaxy, not hand-written
```

```bash
mkdir -p ansible-lab/{inventory,group_vars/all,roles,collections}
cd ansible-lab
```

> [!important] One rule for every command from here on: run everything from `ansible-lab/`
> Every `-i inventory/hosts.yml`, every `ansible-playbook playbook.yml`, every
> path in `ansible.cfg` — all of it is written **relative to this project
> root**. If a command ever comes back with an inventory or file it "can't
> parse" with no clearer error than that, the first thing to check is `pwd`:
> a stray `cd` into a subfolder is the most common cause, not a typo in the
> file itself. `inventory/hosts.yml` typed while you're already standing
> inside `inventory/` resolves to `inventory/inventory/hosts.yml`, which
> doesn't exist — and Ansible reports that as "no inventory parsed," not as a
> missing-file error, so it doesn't look like a path problem at first glance.

## `inventory/hosts.yml`

The list of machines, grouped, with connection details.

```yaml
---
all:
  children:
    cis_lab:
      hosts:
        node1:
          ansible_host: 192.168.122.50
      vars:
        ansible_user: youruser
        ansible_ssh_private_key_file: ~/.ssh/id_ed25519   # or omit if using a password
```

> [!tip] Prove connectivity before writing another file
> ```bash
> pwd                                          # confirm: .../ansible-lab, the project root
> ansible -i inventory/hosts.yml all -m ping
> ```
> `pong` back means the inventory, SSH, and Python-on-the-target chain all
> work. Do this **immediately** after writing the inventory — don't wait
> until the playbook is written to discover connectivity is broken.

If you'd rather type INI instead of YAML (also completely valid, sometimes
faster to type from memory):

```ini
[cis_lab]
node1 ansible_host=192.168.122.50

[cis_lab:vars]
ansible_user=youruser
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

## `ansible.cfg`

**This is the single most useful file to have memorized** — get these wrong
and nothing else matters, often silently.

### Where this file lives, and why that's not arbitrary

Ansible doesn't load *a* config file — it searches, in this exact order, and
stops at the first one it finds:

```
1. $ANSIBLE_CONFIG          (an env var pointing at a specific file, if set)
2. ./ansible.cfg            (current working directory)
3. ~/.ansible.cfg            (your home directory)
4. /etc/ansible/ansible.cfg  (system-wide)
```

That ordering is *why* "run everything from the project root" (Part II's
opening rule) isn't just tidiness — it's the difference between Ansible
finding **your** `ansible.cfg`, with your `inventory`/`roles_path` settings,
versus silently falling back to whatever's in `~/.ansible.cfg` or
`/etc/ansible/ansible.cfg` (which, on a lab machine, is usually nothing
useful — or worse, useful-looking settings left over from a different
exercise). A misbehaving command that "used to work" is worth checking `pwd`
against, every time, before assuming the file itself is wrong.

```ini
[defaults]
inventory = inventory/hosts.yml
roles_path = roles
collections_path = collections
host_key_checking = False
timeout = 30
stdout_callback = ansible.builtin.default
callback_result_format = yaml

[privilege_escalation]
become = True

[ssh_connection]
pipelining = True
```

### `inventory = inventory/hosts.yml`

Without this, Ansible's *own* default inventory path is `/etc/ansible/hosts`
— a file that almost certainly doesn't exist on a lab machine, or if it does,
doesn't have your VM in it. Every command would then need an explicit
`-i inventory/hosts.yml` typed by hand, every time, or fail with "provided
hosts list is empty." This line is what lets `ansible -m ping all` and
`ansible-playbook playbook.yml` work with no `-i` flag at all — the config
file *is* the flag, written once.

### `roles_path` / `collections_path`

Same idea as `inventory`, but for a subtler reason: Ansible has a **default
search path** for roles and collections too, and it's not just one
directory — it checks several, in order (roughly: an `ANSIBLE_ROLES_PATH`
env var if set, then `~/.ansible/roles/`, then a couple of system-wide
locations, then finally `./roles/` relative to the playbook). If you've done
*any* other Ansible exercise on this same machine before, `~/.ansible/roles/`
may already have a role installed under a name that collides with what
you're about to install — and without pinning `roles_path` explicitly, you
can't be certain which copy actually ran.

Setting both to project-local paths (`roles/`, `collections/`) makes the
project **self-contained and reproducible**: anyone who clones this repo and
runs the two `ansible-galaxy install` commands gets exactly what's declared
in `requirements.yml`, nothing inherited from whatever happens to already
exist on their machine.

### `host_key_checking = False`

This one needs the SSH mechanism underneath it to actually make sense, not
just the symptom.

Every SSH server has a **host key** — a keypair that identifies *the server*
(distinct from the keypair that identifies *you*, the client). The first time
you ever connect to a given host, OpenSSH has no way to know if that host key
genuinely belongs to the machine you think you're talking to, or to an
attacker in the middle — so it asks you, interactively:

```
The authenticity of host '192.168.122.50' can't be established.
Are you sure you want to continue connecting (yes/no)?
```

Once you answer, that key gets written to `~/.ssh/known_hosts`, and every
future connection is checked silently against it — no more prompt, unless the
key ever *changes* (which SSH treats as a serious warning, correctly, since
that's what an actual attack would look like too).

Here's why this bites you specifically in this workflow: **every VM you build
this week is, from SSH's point of view, a brand new host** — new IP,
sometimes reused, and definitely a freshly generated host key each time
(Anaconda/cloud-init regenerate host keys on first boot precisely so clones
don't share an identity). Ansible connects non-interactively — there's no
human sitting at a terminal to type `yes` — so without this setting, the
**first** connection to any freshly built VM just hangs forever, waiting on a
prompt that can never be answered. Not an error. A hang. `host_key_checking
= False` tells Ansible to skip that check entirely, appropriate for a
lab/exam VM you just built yourself and know the identity of; **not**
something you'd disable against a real production fleet you didn't just
personally stand up.

### `timeout = 30`

This is the timeout Ansible applies to the underlying SSH connection **per
task**, not a total playbook time limit. The default is 10 seconds. Why 30
matters specifically here: the CIS role isn't a handful of tasks, it's
routinely 300–600+ of them, and a large fraction `become` (privilege-escalate
via `sudo`) individually. Each escalation is its own small negotiation on top
of the SSH connection. Under load — a VM with modest CPU/memory allocation,
several tasks firing in quick succession — that negotiation can occasionally
take longer than 10 seconds, and when it does, the task fails with a timeout
that has nothing to do with anything actually being wrong. 30 seconds is
generous headroom for exactly that failure mode, cheaply.

### `stdout_callback` + `callback_result_format`

A **callback plugin** is a hook into Ansible's execution that controls how
results get displayed (or logged, or sent somewhere else — callbacks aren't
only about stdout). By default, Ansible's output is dense: each task result
is a single-line JSON blob. Readable if you're grepping programmatically,
miserable if you're a human trying to see what changed during a 400-task run.

`ansible.builtin.default` is the name of the *built-in* callback plugin
(shipped with `ansible-core` itself — the `ansible.builtin.` prefix means
exactly that, see the FQCN explanation under `playbook.yml` below).
`callback_result_format = yaml` tells that plugin to render each task's
result block as readable multi-line YAML instead of one dense JSON line.

> [!danger] The one-word mistake that actually happened here
> Writing `stdout_callback = yaml` (no `ansible.builtin.default` at all) looks
> like it should mean the same thing, and did once — but `yaml` alone
> resolves to a *different*, separately-maintained plugin,
> `community.general.yaml`, which was **removed in `community.general`
> 12.0.0**. A config that worked last month can break on a machine with newer
> collections installed, with an error that doesn't obviously point back at
> this line. The two-line form above is the current, stable way to get the
> same readable output.

### `[privilege_escalation]` → `become = True`

This is worth understanding as a genuinely separate step from SSH
authentication, because conflating the two is a common source of confusion
under pressure.

**Connecting** (SSH) and **escalating privilege** (`become`) are two
independent things Ansible does, one after the other, for every task:

1. SSH in as whatever `ansible_user` the inventory specifies — an ordinary,
   unprivileged account
2. *Then*, if `become` is set, wrap the actual module execution in a
   privilege-escalation command (`sudo` by default — `become_method` can
   change this, but `sudo` covers essentially every exam scenario) before
   running it

Setting `become = True` here, globally, means **every task in every
playbook run from this project defaults to running as root** unless a
specific task explicitly overrides it with `become: false`. This matters for
CIS hardening specifically because nearly everything the role touches needs
root: `/etc/ssh/sshd_config`, `/etc/pam.d/*`, `/etc/security/*`, sysctl
parameters, systemd unit states — none of that is writable by an ordinary
user, and there is no realistic hardening playbook that doesn't need this on
almost every single task.

### `[ssh_connection]` → `pipelining = True`

This is the one worth actually tracing through mentally, because the
*default* behavior is stranger than people expect.

**Without pipelining**, running a single Ansible task against a remote host
is not one SSH command — it's several separate operations:

1. Ansible generates a small, self-contained Python script that embeds the
   module's logic plus your task's arguments
2. That script gets **copied to the remote host** (over SFTP, or SCP as a
   fallback) into a temporary directory
3. A **separate SSH command** executes that script
4. **Another SSH command** cleans up the temporary file afterward

That's up to three distinct connection operations, for *one task*. Multiply
that by 400+ tasks in a CIS run and the overhead compounds fast — not because
any single step is slow, but because SSH connection setup/teardown has fixed
latency that adds up linearly with task count.

**With pipelining enabled**, Ansible skips the copy-then-execute dance
entirely: it feeds the module's Python code directly over the **existing SSH
session's stdin**, in one round trip, no temp file ever written to disk on
the target. Same result, meaningfully fewer connection operations across a
run this size.

> [!tip] The one thing that can make pipelining fail
> Pipelining needs `sudo` to accept input piped to it rather than requiring
> an interactive terminal. If the target's `/etc/sudoers` has
> `Defaults requiretty` set, `become` tasks can fail specifically when
> pipelining is on. Modern AlmaLinux/RHEL don't set this by default, so it's
> rarely an issue here — but if you ever see `become`-wrapped tasks failing
> with something about a missing tty right after enabling pipelining, that
> line in `/etc/sudoers` is the first thing to check.

## `requirements.yml`

Declares the role, and — in a second pass, once you know what to write —
any collections it needs. **Nothing here is installed automatically** — you
always run `ansible-galaxy` afterward. This is a two-step process, in this
order, every time: write the role, install it, **discover** its collection
needs from the installed copy, then come back and add them.

### Step 1 — the role only

```yaml
---
roles:
  - name: RHEL10-CIS                                        # or RHEL8-CIS / RHEL9-CIS, whatever you drew
    src: https://github.com/ansible-lockdown/RHEL10-CIS.git
    scm: git
    version: "1.1.0"                                        # a real release TAG, never a branch
```

> [!danger] Pin to a tag. Never track `main`, never fork the role.
> **Why pin:** CIS renumbers rules between benchmark versions. An unpinned
> `main` means the rules your pipeline enforces can silently change out from
> under you, and your Goss score moves for reasons that don't show up
> anywhere in your own history.
> **Why not fork:** the moment you edit a task inside the role, you own every
> future merge conflict with upstream forever. Everything you need is already
> exposed as a variable in the role's own `defaults/main.yml` — if you're
> reaching to edit a task file, you haven't looked hard enough at the
> defaults yet.
>
> Check the real current tag before the exam (or right at the start of it):
> ```bash
> git ls-remote --tags https://github.com/ansible-lockdown/RHEL10-CIS.git | tail -5
> # swap RHEL10-CIS for RHEL8-CIS / RHEL9-CIS as assigned
> ```

Install just the role:

```bash
ansible-galaxy role install -r requirements.yml -p roles/ --force
```

### Step 2 — find out what collections it actually needs, from the role itself

**Don't guess, and don't copy a list from notes for a different role version
than the one you actually installed.** Every Ansible role can declare its own
collection dependencies, and the `ansible-lockdown` CIS roles always do — in
`meta/main.yml`, under a `collections:` key. That file, in the copy you just
downloaded, is the ground truth:

```bash
cat roles/RHEL10-CIS/meta/main.yml | grep -A5 "^collections:"
```

That's the entire method. Whatever comes back is what you write into
`requirements.yml` next — for `RHEL9-CIS`/`RHEL10-CIS` this has consistently
been `community.general`, `community.crypto`, `ansible.posix`, but **verify
it for whatever role you actually drew** rather than assuming — `RHEL8-CIS`
is not guaranteed to declare exactly the same three.

### Step 3 — add what you found, then install it

```yaml
---
roles:
  - name: RHEL10-CIS
    src: https://github.com/ansible-lockdown/RHEL10-CIS.git
    scm: git
    version: "1.1.0"

collections:
  - name: community.general
  - name: community.crypto
  - name: ansible.posix
```

```bash
ansible-galaxy collection install -r requirements.yml -p collections/ --force
```

> [!warning] Why this step exists at all
> `ansible-core` ships **zero** community collections by default. The CIS
> role's own tasks call modules like `community.general.filesystem` and
> `community.general.modprobe` internally — modules that live in the
> collections you just discovered and installed, not in `ansible-core`
> itself. Skip this step and you'll hit, partway through a run:
> ```
> couldn't resolve module/action 'community.general.filesystem'
> ```
> — a confusing failure if you don't already know it means "a collection is
> missing," since nothing about the error names `requirements.yml` directly.

## `playbook.yml`

The entry point. Almost always short — the CIS role does the actual work.
Every line in it is doing something specific; worth understanding each one
rather than treating the file as boilerplate to retype from memory.

```yaml
---
- name: CIS Level 1 hardening
  hosts: cis_lab
  become: true

  pre_tasks:
    - name: Confirm this is actually the right OS before hardening it
      ansible.builtin.assert:
        that:
          - ansible_facts['distribution'] == 'AlmaLinux'
          - ansible_facts['distribution_major_version'] == '9'   # match your assigned version
        fail_msg: >-
          Expected AlmaLinux 9, found
          {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
      tags: [always]

  roles:
    - role: RHEL9-CIS   # match the exact role name you installed
```

### What a "play" actually is

A **playbook** is a YAML **list**. Each `- name: ...` entry in that list is
one **play** — a mapping of *which hosts* to *what to do to them*. The `---`
at the top just marks the start of a YAML document; the real content is a
single-item list here, though nothing stops a playbook from containing
several plays back to back (each with its own `hosts:`, running in order —
not used in this file, but worth knowing the shape scales that way).

### `hosts: cis_lab`

This isn't a hostname — it's a **pattern**, matched against your inventory at
the moment the play starts. `cis_lab` here is the *group name* you defined in
`inventory/hosts.yml`. Ansible resolves it into the actual set of hosts
belonging to that group and runs everything in this play against each of
them. Patterns can be more elaborate than a bare group name (`all`,
`group1:group2` for a union, `group1:!group2` to exclude, `*.example.com`),
but a single group name is what you need here.

### `become: true` — here, *and* in `ansible.cfg`. Why both?

`ansible.cfg`'s `[privilege_escalation] become = True` already makes root the
default for **every** play in this project. Setting `become: true` again
here, at the play level, is technically redundant *in this specific project*
— but it's a defensible habit, not dead weight: a play should be
understandable on its own, without requiring the reader to also go check
`ansible.cfg` to know it needs root. If you were ever asked "does this
playbook need to run privileged," the honest answer should be visible in the
one file you're looking at. (Task-level `become: false` can still override
either setting for one specific task that genuinely shouldn't escalate —
neither the cfg default nor the play-level setting is absolute.)

Any task-level tailoring (a variable that should only apply during *this*
play, at precedence level #12 — see Part IV) goes in a `vars:` block right
under `become: true`.

### `pre_tasks:` — and the execution order it implies

`pre_tasks` is a **reserved keyword**, not an arbitrary section name — Ansible
guarantees a specific order when a play contains more than one of these
blocks: `pre_tasks` → `roles` → `tasks` → `post_tasks` (with handler
notifications flushed at each boundary). Writing the OS-check as a
`pre_tasks` entry, rather than just putting it first inside `tasks:`, is what
guarantees it runs **before the role gets anywhere near the target** — not a
stylistic choice.

The actual reason this check earns its own place at all: the CIS role is
400–600+ tasks that can take real minutes to run. Discovering ten minutes in
that you installed `RHEL9-CIS` against an AlmaLinux 10 box (a real,
plausible mistake when you're juggling four possible OS/role combinations
under exam time pressure) is a much worse way to find out than failing in the
first two seconds, before a single hardening task has touched the system.

### `ansible.builtin.assert` — why the full `ansible.builtin.` prefix

Since Ansible 2.10, every module belongs to a **collection** — a namespaced
package of modules, plugins, and roles. `ansible.builtin` is the collection
that ships bundled with `ansible-core` itself, containing all the original
"core" modules (`assert`, `copy`, `file`, `command`, and so on). Writing the
bare short name (`assert:`) still works — Ansible falls back to a search
across installed collections when a name isn't fully qualified — but it's
**ambiguous** the moment you have other collections installed that might
also ship a module with the same short name. Since this project already
installs `community.general`, `community.crypto`, and `ansible.posix`
alongside `ansible.builtin`, writing the full name removes any question of
which collection's version of `assert` actually ran. Worth adopting as a
habit everywhere, not just here.

### `ansible_facts['distribution']` — where this data actually comes from

You never wrote a task to *collect* this — it's there because Ansible
**implicitly gathers facts before the first task in every play runs**, unless
you explicitly disable it with `gather_facts: false`. Concretely: before
anything you wrote executes, Ansible connects to the target and runs the
`ansible.builtin.setup` module on your behalf, which inspects the remote
system — OS name and version, network interfaces, mounted filesystems,
memory, CPU, and a great deal more — and returns all of it as one large
dictionary, stored under `ansible_facts`. Every field in that dictionary is
then available to every task in the play, including this one, which is how
`ansible_facts['distribution']` has a value at all despite this being the
very first task.

(You'll also see facts referenced the *flat* way in older examples —
`ansible_distribution` instead of `ansible_facts['distribution']` — Ansible
injects the same data both ways for backward compatibility. The dict-access
form used here is the current recommended style; the flat form can be turned
off entirely via `inject_facts_as_vars = False`, so relying on it is
slightly less future-proof.)

### `fail_msg:` and the `>-` syntax

`ansible.builtin.assert` takes a `that:` list of conditions (all must be
true), and an optional `fail_msg:` shown only if one of them fails. The `>-`
before the message text is YAML's **folded block scalar** syntax: `>` folds
line breaks inside the block into single spaces (so you can wrap a long
string across multiple source lines without an unwanted newline ending up
inside it), and the trailing `-` strips the one trailing newline YAML would
otherwise add at the very end of the block. Small, but it's why the message
reads as one clean sentence instead of an oddly-spaced multi-line blob when
it actually prints.

### `tags: [always]` — the one tag with special behavior

Tags are labels you attach to tasks (or whole roles, or blocks), which
`--tags`/`--skip-tags` at invocation time use to filter what actually runs —
this is exactly the mechanism `--skip-tags "level2-server,level2-workstation"`
uses to scope a run to Level 1 only. `always` is a **magic tag name**, not
just a label that happens to sound important: any task tagged `always` runs
**regardless of whatever `--tags`/`--skip-tags` you pass**, unless you go out
of your way to explicitly pass `--skip-tags always`. That's precisely why
it's on this specific task and no others in this file: no matter how the CIS
run itself gets scoped or filtered, the OS sanity check is a safety net that
can't accidentally be filtered out along with it.

### `roles:` → `- role: RHEL9-CIS`

This is where `roles_path` from `ansible.cfg` gets used: Ansible resolves the
name `RHEL9-CIS` against that search path, finds `roles/RHEL9-CIS/`, and runs
its `tasks/main.yml`. Critically, this is also the moment its
`defaults/main.yml` becomes part of the running play's variable space — at
the **lowest** precedence level (#2 from Part IV's table), which is exactly
why every value you set in `group_vars`, in this play's own `vars:`, or on
the command line is able to override it. The dict form (`- role: RHEL9-CIS`)
rather than a bare string (`- RHEL9-CIS`) is what lets you attach role-scoped
`vars:` or `tags:` alongside the role invocation if you ever need to — not
used here, but it's why the dict form is the conventional way to write this
even when nothing extra is actually attached.

## `group_vars/all/vars.yml`

Where most tailoring actually lives — precedence level #5, applies to every
host in the `all` group.

```yaml
---
# Scope: Level 1, Server only. Almost every exam brief wants exactly this.
rhel9cis_level_1: true
rhel9cis_level_2: false

# A tailoring example: custom login banner
rhel9cis_warning_banner: "AUTHORIZED ACCESS ONLY — ACTIVITY IS MONITORED"

# Goss audit — install it, run it, fetch the report back
setup_audit: true
run_audit: true
fetch_audit_output: true
audit_output_destination: "{{ playbook_dir }}/audit_reports/"
```

> [!important] The variable prefix changes with the role
> `RHEL9-CIS` variables start `rhel9cis_`. `RHEL8-CIS` uses `rhel8cis_`.
> `RHEL10-CIS` uses `rhel10cis_`. **Copy-pasting a `group_vars` file from a
> different version's notes and not updating the prefix is a real, easy
> mistake** — Ansible won't error, it'll just silently define an unused
> variable and the role keeps its own default. Always re-derive the exact
> prefix from whichever role you actually installed (see Part III).

## Ansible Vault — for anything actually sensitive

Almost every brief has "anything sensitive goes through vault" as a hard
requirement (a bootloader password hash is the usual candidate).

```bash
ansible-vault create group_vars/all/vault.yml    # prompts for a password, opens $EDITOR
```

Inside:

```yaml
---
vault_bootloader_password_hash: "grub.pbkdf2.sha512.10000.<salt>.<hash>"
```

Generate a real hash first, don't invent one:

```bash
grub2-mkpasswd-pbkdf2
```

Reference it from the **plain**, committed `vars.yml` — never reference a
vault variable by writing the vault filename directly into the role
invocation, always go through a plain variable that points at it:

```yaml
# in group_vars/all/vars.yml — plain, readable, safe to show anyone
rhel9cis_bootloader_password_hash: "{{ vault_bootloader_password_hash }}"
```

Run anything that touches vaulted variables with:

```bash
ansible-playbook playbook.yml --ask-vault-pass
# or, if you saved the password to a file (never commit that file):
ansible-playbook playbook.yml --vault-password-file ~/.vault_pass
```

> [!danger] The file you point `--vault-password-file` at is the PASSWORD, not the vault
> A classic, easy-to-make mistake under pressure: pointing
> `--vault-password-file` at `vault.yml` itself (the locked box) instead of a
> separate file that contains just the plain password (the key). It fails
> with a decryption error that doesn't obviously say "wrong file."

Other vault commands worth having cold:

```bash
ansible-vault view   group_vars/all/vault.yml    # read it without editing
ansible-vault edit   group_vars/all/vault.yml    # edit in place, re-encrypts on save
ansible-vault decrypt group_vars/all/vault.yml   # permanently decrypt — rarely what you want
```

---

# Part III — Finding the Role's Real Variables Yourself

> [!abstract] This is the actual skill being tested
> Memorizing `RHEL9-CIS`'s variable names doesn't help if you draw
> `RHEL8-CIS` on the day. What's actually being graded is whether you know
> **how to find the real, current variable for whatever role you install** —
> so that's what this section teaches, not a list to memorize.

## The one command that matters

```bash
grep -rn "^rhel[0-9]*cis_" roles/RHEL9-CIS/defaults/main.yml | less
```

(Swap `RHEL9-CIS` for whichever role you actually installed.) This dumps
**every** variable the role exposes, with its default value, in one place —
this is the ground truth. Not a blog post, not last week's notes: the file
that's actually about to run.

## Common families to look for, by name pattern

These patterns are consistent across the `-CIS` role family (all maintained
by ansible-lockdown, same generator/structure), even though exact rule
numbers and defaults differ per OS version:

| Pattern | What it controls |
|---|---|
| `rhel<N>cis_level_1` / `_level_2` | Which benchmark level to remediate/audit |
| `rhel<N>cis_warning_banner` | Login banner text |
| `rhel<N>cis_syslog` | Which logging backend (`rsyslog` vs `journald` — varies by which the brief assigns) |
| `rhel<N>cis_bootloader_password_hash` (or `_password`) | GRUB password — usually **required**, the role refuses to run on its shipped placeholder default |
| `rhel<N>cis_authselect_custom_profile_name` | Custom PAM profile name — also usually required, refuses the example default |
| `rhel<N>cis_sshd_allowusers` | SSH `AllowUsers` — leaving this **undefined** (not even empty string) can crash a `join()` filter inside the role |
| `rhel<N>cis_pass_max_days` / `_min_days` / `_warn_age` | Password aging policy |
| `rhel<N>cis_rule_<x>_<y>_<z>` | Per-rule toggle — the supported way to disable exactly one control |
| `setup_audit` / `run_audit` / `fetch_audit_output` | Goss integration — not role-prefixed, shared across all versions |

## Finding which rules block a Level 1 run before they surprise you

Some rules `assert:` against their own defaults and **abort the entire play**
before doing any remediation — these are the ones that bite hardest under
time pressure, because the failure looks like "nothing worked" rather than
"one thing is misconfigured."

```bash
grep -rl "assert" roles/RHEL9-CIS/tasks/ | xargs grep -B2 -A8 "assert:" | less
```

Look specifically for assertions mentioning a **default placeholder value**
(`changethispassword`, `cis_example_profile`, and similar) — those are the
"you must consciously set this" tripwires.

## Finding which mount-point rules are actually Level 1

The brief usually wants you to check this yourself rather than assume it
carries over between OS versions:

```bash
grep -rl "mount\|partition" roles/RHEL9-CIS/tasks/ | xargs grep -l "level1-server"
```

The **existence** of a separate partition is often Level 2; the **mount
options** (`nodev`/`nosuid`/`noexec`) on a partition that already exists are
often Level 1. This split is not guaranteed to be identical between
`RHEL8-CIS`, `RHEL9-CIS`, and `RHEL10-CIS` — verify per role, per exam.

## A `--skip-tags` guarding an `always`-tagged prelim check

One specific trap worth knowing about by pattern, even without the exact
rule number: some Level 2 rules have their **preliminary check** tagged
`always`, while the remediation itself is tagged `level2-server`. That means
`--skip-tags level2-server` skips the fix but **not** the check — and if the
check's assertion depends on something your Level 1 setup never configured
(a password-based escalation path when you're using key-only SSH, for
example), the play aborts even though you correctly scoped to Level 1.

```bash
grep -B5 "tags:.*always" roles/RHEL9-CIS/tasks/*.yml | grep -A5 assert
```

If you hit this: the fix is the same shape every time — find the rule's own
per-rule toggle variable (`rhel<N>cis_rule_<...>`) and set it `false`, with a
one-sentence justification for why the guard doesn't apply to your setup
(usually: "key-only SSH access means this password-escalation control has no
reachable attack surface here").

## Three categories worth grepping before any real run, not just OS/mount checks

Everything above is about the role failing loudly and stopping. There's a
worse failure shape: the role succeeding at exactly what it's designed to do,
and in the process cutting off the very access **you** need to keep the run
going or to get back in afterward. Only three categories of control can do
this, and they're worth a specific pass — right after installing the role,
same moment as the `assert:` grep — before running for real:

```bash
grep -rl "sudoers\|become" roles/RHEL<N>-CIS/tasks/           # privilege escalation
grep -rl "sshd_config\|PermitRootLogin\|AllowUsers" roles/RHEL<N>-CIS/tasks/   # SSH access itself
grep -rl "faillock\|pam_faillock" roles/RHEL<N>-CIS/tasks/     # account lockout
```

> [!danger] Real example: `NOPASSWD` sudo vs. the control that exists to remove it
> If you set up passwordless `sudo` for your automation account so `become`
> wouldn't prompt on every task (a completely reasonable, common setup), a
> rule like *"ensure re-authentication for privilege escalation is not
> disabled globally"* finds that exact `NOPASSWD` entry and **strips it** —
> because a standing passwordless-sudo rule is precisely what that control
> considers a finding. The dependency ("Ansible needs this account
> passwordless to run smoothly") was in direct conflict with a control the
> role was always going to enforce, and the failure doesn't show up until
> the run reaches that specific rule, potentially hundreds of tasks in.
>
> **The fix that avoids this category entirely, not just this one instance of
> it:** don't make the account passwordless in the first place. Use
> `--ask-become-pass` at invocation, or a vaulted `ansible_become_password`,
> so `become` supplies a real password on every privileged task instead of
> relying on a standing sudoers exception:
> ```bash
> ansible-playbook playbook.yml --ask-vault-pass --ask-become-pass
> ```
> This is arguably the *more* defensible setup regardless — no account on the
> box has blanket passwordless sudo, so the control is genuinely satisfied,
> not carved around with an exclusion. A role-provided exclude-list variable
> (e.g. `rhel<N>cis_sudoers_exclude_nopasswd_list`) is the documented,
> supported way to protect one specific account if you'd rather keep
> `NOPASSWD` — a legitimate choice, just a different one than removing the
> dependency altogether.

---

# Part IV — Variable Precedence, Demonstrated

> [!abstract] Why this gets asked
> The brief always wants tailoring demonstrated at **multiple** precedence
> levels — not because it's hard, but because it proves you understand *why*
> a variable's value is what it is, not just that you typed something that
> happened to work.

## The chain, lowest to highest (the levels you'll actually use)

```
role defaults (#2)  <  group_vars/all (#5)  <  play vars (#12)  <  --extra-vars (#22)
```

Ansible has 22 precedence levels total; almost no exam or brief needs more
than these four.

| Level | Where | Example |
|---|---|---|
| **#2** | `roles/RHEL9-CIS/defaults/main.yml` | the role's own shipped default |
| **#5** | `group_vars/all/vars.yml` | your main tailoring file — most overrides live here |
| **#12** | `vars:` block inside `playbook.yml` | overrides group_vars for this specific play only |
| **#22** | `-e 'var=value'` on the command line | wins over everything; nothing in any file can override it |

## Producing the table live

Pick **two or three** of your tailoring variables and set them at
**different** levels on purpose — this is what "demonstrated at multiple
precedence levels" means in practice:

```yaml
# group_vars/all/vars.yml — level #5
rhel9cis_warning_banner: "..."
```

```yaml
# playbook.yml, vars: block — level #12, beats group_vars
rhel9cis_sshd_clientaliveinterval: 300
```

```bash
# command line — level #22, beats everything
ansible-playbook playbook.yml -e 'rhel9cis_syslog=rsyslog'
```

Then be ready to state, for each one: **where it's set, what it overrides,
and why that's the right place for it** — not just that it works.

> [!tip] The honest answer for why `--extra-vars` is usually the *wrong* place for permanent config
> It always wins, which is exactly why it's invisible in git — nobody
> reviewing the repo can see it took effect just by reading the files. Good
> for a one-off demo of precedence; bad as where your real, permanent
> tailoring decisions live.

## Verify it actually landed — don't trust the recap alone

A typo'd variable name produces **no error at all**. Ansible just silently
defines a new, unused variable; the role quietly keeps its shipped default.
The only real proof is checking the live host:

```bash
ssh youruser@<vm-ip> 'cat /etc/issue.net'                       # banner
ssh youruser@<vm-ip> 'sudo sshd -T | grep clientalive'           # sshd tailoring
```

---

# Part V — Running It, Reading the Output, Fixing It

## The command, built up piece by piece

```bash
ansible-playbook playbook.yml \
  --ask-vault-pass \
  -e 'rhel9cis_syslog=rsyslog' \
  --skip-tags "level2-server,level2-workstation"
```

| Flag | Purpose |
|---|---|
| `--ask-vault-pass` (or `--vault-password-file <path>`) | needed the moment any variable resolves through vault |
| `-e '...'` | precedence level #22 — one-off overrides |
| `--skip-tags "level2-server,level2-workstation"` | scope to Level 1 only |

## Flags worth having memorized for troubleshooting

| Flag | What it does |
|---|---|
| `--syntax-check` | parse the playbook without touching anything — catches YAML typos in seconds |
| `--list-tasks` | show every task that *would* run, in order, without running them |
| `--list-tags` | show every tag available to skip/select |
| `-C` / `--check` | dry run — reports what *would* change, doesn't actually change it (not perfectly accurate for every module, but a fast first look) |
| `--diff` | show the actual before/after content of files a task changes |
| `-v`, `-vv`, `-vvv` | increasing verbosity — `-vvv` shows the actual module arguments and SSH commands, the real "why is this failing" tool |
| `--limit <host>` | run against just one host, useful once you have more than one target |
| `--start-at-task "<name>"` | resume from partway through instead of rerunning everything |

## Reading the recap

```
PLAY RECAP *********************************************************************
node1    : ok=363  changed=138  unreachable=0  failed=0  skipped=277
```

| Field | Meaning |
|---|---|
| `ok` | tasks that ran and found nothing to change, or completed successfully |
| `changed` | tasks that actually modified something — on a second run of an already-hardened host, this should trend toward zero (idempotency) |
| `unreachable` | couldn't even connect — an SSH/network problem, not a playbook problem |
| `failed` | a task ran and errored — **the exam's core failure signal to watch** |
| `skipped` | tag-filtered or `when:`-filtered out — expected, not a problem, if it matches what you scoped with `--skip-tags` |

## Real failure patterns (from actually building this three times)

> [!bug]- "Waiting for SSH" / connection refused right after install
> Check the interface actually came up: `ip a` on the console. Anaconda's
> network screen defaults interfaces **off** unless you toggle them during
> install — an extremely common first miss.

> [!bug]- `couldn't resolve module/action 'community.general.X'`
> The collections from `requirements.yml` weren't installed, or were
> installed to the wrong path. Re-run:
> ```bash
> ansible-galaxy collection install -r requirements.yml -p collections/ --force
> ```
> and confirm `collections_path = collections` is actually in `ansible.cfg`.

> [!bug]- `couldn't resolve module/action 'ansible.builtin.X'` for a module you're sure exists
> Almost always a typo in the FQCN itself (`asert` for `assert`,
> `ansible.buitin` for `ansible.builtin`) — this error means "no exact string
> match," not "this module doesn't exist." `--syntax-check` catches these in
> seconds, before Ansible even connects to a host — run it first, every time,
> rather than debugging blind after a failed live run.

> [!bug]- `Missing sudo password`
> `become: true` is set, but the account's `sudo` isn't passwordless yet — the
> `NOPASSWD` sudoers step from Part I either didn't happen for this VM, or
> didn't survive a rebuild. Fix at the root (a human, at an interactive
> terminal, still has to type the password once to create the file — that's
> expected):
> ```bash
> ssh -t <user>@<vm-ip> 'echo "<user> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-<user>'
> ssh -t <user>@<vm-ip> 'sudo chmod 440 /etc/sudoers.d/90-<user>'
> ssh <user>@<vm-ip> 'sudo -n true && echo OK'    # confirm before retrying the playbook
> ```
> `-t` matters here specifically — plain `ssh host 'command'` doesn't attach
> a terminal, and `sudo` refuses to *prompt* for a password without one; you'd
> otherwise see `sudo: a terminal is required to read the password` instead.
> A same-run workaround exists (`--ask-become-pass` / `-K`, prompts once up
> front and supplies it to every `become` task) but costs you a second typed
> password on every future invocation — worth the thirty seconds to fix
> properly instead.

> [!bug]- `Missing sudo password` reappears **mid-run**, after working fine for hundreds of tasks
> A different cause from the one above — this isn't a setup that was never
> done, it's a setup the **role itself just undid**. A rule enforcing
> "re-authentication for privilege escalation" finds your account's
> `NOPASSWD` sudoers entry and rewrites it to require a password again,
> exactly as designed — see
> [[#Three categories worth grepping before any real run, not just OS/mount checks]].
> Confirm this is actually what happened before assuming anything else broke:
> ```bash
> ssh <user>@<vm-ip> 'sudo -n true' || echo "NOPASSWD is gone"
> ```
> Two legitimate fixes, pick one: switch the whole run to
> `--ask-become-pass`/a vaulted `ansible_become_password` (removes the
> dependency on `NOPASSWD` entirely — see the box linked above), or restore
> the sudoers file and add your account to the role's own
> `rhel<N>cis_sudoers_exclude_nopasswd_list` (a documented exception, not a
> weakened control). **Not** a reason to reinstall the VM — the same rule
> strips the same entry on any fresh install too, so nothing about a rebuild
> changes the outcome.

> [!bug]- `Error while resolving value for 'fail_msg': 'X' is undefined`
> A typo'd variable name **inside a Jinja `{{ }}` reference** — commonly
> `ansible_facts` mistyped, e.g. `anisble_facts`. Notice this surfaces as
> *"Finalization of task args failed,"* not a normal assertion failure: every
> module argument gets templated up front, before `that:` is even evaluated —
> so a broken variable reference inside a message that would only ever print
> *on failure* still breaks the task immediately, even when the assertion
> itself would have passed. Same fix as any other typo: read the exact
> variable name character by character against what you meant to write.

> [!bug]- `Conditional result (True) was derived from value of type 'str'. Conditionals must have a boolean result.`
> A **real bug inside the role itself**, not something in your own files —
> deep in a task or handler, a `when:` condition evaluates to a non-empty
> string instead of an actual boolean (commonly: a comparison accidentally
> wrapped in outer quotes, turning a live expression into a dead string
> literal). `ansible-core 2.19+` hard-errors on this instead of the older,
> silent truthy-cast; the error message even names the escape hatch:
> ```ini
> # ansible.cfg
> [defaults]
> allow_broken_conditionals = True
> ```
> **Prefer this over hand-editing the role's YAML.** The role directory is
> `ansible-galaxy`-installed and gitignored — a fresh
> `ansible-galaxy role install --force` wipes any manual fix in it, while
> `ansible.cfg` is your own committed file and persists. This setting also
> covers every *other* instance of the same defect elsewhere in the role you
> haven't reached yet, not just the one that happened to fail first. Editing
> the specific broken line directly is a legitimate fallback if this setting
> somehow isn't available, but isn't the first thing to reach for.
>
> Worth being ready to explain if asked: this doesn't weaken any hardening
> logic — it's a role/`ansible-core` version compatibility gap, unrelated to
> what the role actually remediates. Different from silently disabling a
> failing CIS control, which is what "never fork and edit the role" is
> actually protecting against.

> [!bug]- The play aborts immediately on an `assert:` before doing any real work
> Almost always one of: bootloader password hash still the shipped default,
> authselect profile name still the example default, or `sshd_allowusers`
> left completely undefined. Find the exact variable with the `grep` from
> Part III and set it deliberately.

> [!bug]- Ansible modules start failing right after a task that touches `/tmp`
> The CIS role sets `/tmp` `noexec` — but Ansible's own temp execution
> directory defaults to a path under the user's home, which is usually fine.
> If it's not, `ansible.cfg`'s `remote_tmp = ~/.ansible/tmp` fixes it
> explicitly.

> [!bug]- `Permission denied (publickey,password)` after the FIRST successful connection
> If SSH worked once and then stopped, something in the hardening pass just
> changed `sshd_config` in a way that's locking you out — check
> `AllowUsers`, `PasswordAuthentication`, and the account's own lock state
> from a **separate** still-open session or the Cockpit console **before**
> you close your only working connection. This is the single most dangerous
> failure mode in a live hardening run — never let your only session close
> until you've confirmed a second way in still works.

> [!bug]- `stdout_callback` plugin not found / removed
> If `ansible.cfg` says `stdout_callback = yaml` instead of
> `ansible.builtin.default` + `callback_result_format = yaml` — see Part II's
> `ansible.cfg` section for the exact fix and why.

---

# Part VI — Presentation and Q&A Prep

You'll present what you did and be asked individual questions — "what" isn't
enough, be ready with "why."

> [!question]- Why RHEL-CIS via Ansible instead of hardening by hand?
> Consistency, repeatability, and a variable-driven audit trail. Every
> decision is a named variable in a committed file, not a one-off `sed`
> command nobody can reconstruct later. Re-running the playbook against a
> re-installed VM reproduces the exact same hardened state.

> [!question]- Why pin the role to a release tag instead of tracking `main`?
> CIS benchmarks get renumbered between versions. An unpinned role means an
> upstream commit can silently change which rules your pipeline enforces —
> your compliance score would move for reasons invisible in your own repo's
> history.

> [!question]- Why not just edit the role's tasks directly for a quick fix?
> Every variable you'd need is already exposed through `defaults/main.yml` —
> editing a task file means owning a merge conflict with upstream forever, for
> a change that was almost always already possible through a variable.

> [!question]- Explain your variable precedence table.
> Have the actual three-or-four-row table ready (Part IV) — which variable,
> what value, which file/level, what it overrides, and *why that's the
> correct place for a permanent decision vs. a one-off*.

> [!question]- Why audit with Goss instead of trusting the Ansible recap?
> Ansible's `ok`/`changed` only proves its own model of the run — a task can
> report success while the actual change never took effect (service didn't
> reload, a later drop-in overrode the setting, SELinux silently blocked the
> write). Goss re-reads the live system independently, with zero knowledge of
> what Ansible did. It's the only genuine verification in the pipeline.

> [!question]- What's your Goss score, and can you explain the failures?
> Have the actual numbers (pre/post, percentage) and be ready to name at
> least **three specific failing checks** with a real reason each — a
> deliberately tailored-off rule, a rule that depends on a partition you
> don't have, or a rule that only takes effect after a reboot the role
> doesn't perform mid-run.

> [!question]- What would you do differently with more time?
> Have a real, specific answer — not "nothing." A common honest one: verify
> the mount-point Level-1/Level-2 split against the actual installed role's
> tasks (Part III) rather than assuming it matches what you remembered from
> a different OS version's role.

---

# Part VII — The Cheat Sheet

One page. No explanations. For when the clock is loud.

```bash
# ── Step 0, on the HOST, before opening Cockpit ─────────────────
ls ~/.ssh/*.pub 2>/dev/null || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
setfacl -m u:qemu:x ~                        # so qemu:///system can reach your ISO

# ── Cockpit / VM ──────────────────────────────────────────────
systemctl status cockpit.socket
# browse: https://localhost:9090 → Virtual Machines → Create VM
# Anaconda: user creation → tick "Require a password" → set one, keep it for now
virsh domifaddr <vmname>                     # get the IP after install

# ── First login, key-only, in one pass ──────────────────────────
ssh-copy-id <user>@<ip>                      # prompts for the install-time password
ssh <user>@<ip> 'true'                       # must return with NO password prompt
# -t is required on these two: sudo needs a real terminal to prompt, and
# NOPASSWD isn't in effect until this file exists
ssh -t <user>@<ip> 'echo "<user> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-<user>'
ssh -t <user>@<ip> 'sudo chmod 440 /etc/sudoers.d/90-<user>'
ssh <user>@<ip> 'sudo -n true && echo OK'    # confirm: no prompt now
# only now, optionally: ssh <user>@<ip> 'sudo passwd -l <user>'

# ── Project scaffold ──────────────────────────────────────────
mkdir -p ansible-lab/{inventory,group_vars/all,roles,collections}
cd ansible-lab
# from here on, EVERY command below assumes you are standing in ansible-lab/ —
# if a path ever "won't parse," `pwd` before anything else

# ── inventory/hosts.yml ───────────────────────────────────────
: <<'EOF'
all:
  children:
    cis_lab:
      hosts:
        node1:
          ansible_host: <ip>
      vars:
        ansible_user: <user>
        ansible_ssh_private_key_file: ~/.ssh/id_ed25519
EOF

# ── ansible.cfg ────────────────────────────────────────────────
: <<'EOF'
[defaults]
inventory = inventory/hosts.yml
roles_path = roles
collections_path = collections
host_key_checking = False
timeout = 30
stdout_callback = ansible.builtin.default
callback_result_format = yaml

[privilege_escalation]
become = True

[ssh_connection]
pipelining = True
EOF

# ── First connectivity check ──────────────────────────────────
ansible -i inventory/hosts.yml all -m ping

# ── requirements.yml, step 1: role only ─────────────────────────
: <<'EOF'
---
roles:
  - name: RHEL<N>-CIS
    src: https://github.com/ansible-lockdown/RHEL<N>-CIS.git
    scm: git
    version: "<real tag>"
EOF
ansible-galaxy role install -r requirements.yml -p roles/ --force

# ── discover the collections it actually needs — DON'T guess ────
cat roles/RHEL<N>-CIS/meta/main.yml | grep -A5 "^collections:"

# ── requirements.yml, step 2: add exactly what that printed ─────
: <<'EOF'
collections:
  - name: community.general   # <- replace with whatever meta/main.yml actually said
  - name: community.crypto
  - name: ansible.posix
EOF
ansible-galaxy collection install -r requirements.yml -p collections/ --force

# ── Find the role's real variables ────────────────────────────
grep -rn "^rhel<N>cis_" roles/RHEL<N>-CIS/defaults/main.yml | less
grep -rl "assert" roles/RHEL<N>-CIS/tasks/ | xargs grep -B2 -A8 "assert:"

# ── group_vars/all/vars.yml (fill in real prefix + values) ────
: <<'EOF'
rhel<N>cis_level_1: true
rhel<N>cis_level_2: false
rhel<N>cis_warning_banner: "..."
rhel<N>cis_bootloader_password_hash: "{{ vault_bootloader_password_hash }}"
rhel<N>cis_authselect_custom_profile_name: custom_profile
rhel<N>cis_sshd_allowusers: "<user>"
setup_audit: true
run_audit: true
fetch_audit_output: true
audit_output_destination: "{{ playbook_dir }}/audit_reports/"
EOF

# ── Vault ──────────────────────────────────────────────────────
grub2-mkpasswd-pbkdf2
ansible-vault create group_vars/all/vault.yml

# ── playbook.yml ───────────────────────────────────────────────
: <<'EOF'
---
- name: CIS Level 1 hardening
  hosts: cis_lab
  become: true
  pre_tasks:
    - name: Confirm OS
      ansible.builtin.assert:
        that:
          - ansible_facts['distribution'] == 'AlmaLinux'
          - ansible_facts['distribution_major_version'] == '<N>'
      tags: [always]
  roles:
    - role: RHEL<N>-CIS
EOF

# ── Sanity before the real run ─────────────────────────────────
ansible-playbook playbook.yml --syntax-check
ansible-playbook playbook.yml --list-tasks

# ── The real run ────────────────────────────────────────────────
ansible-playbook playbook.yml \
  --ask-vault-pass \
  --skip-tags "level2-server,level2-workstation"

# ── Verify on the live host, don't trust the recap alone ───────
ssh user@<ip> 'cat /etc/issue.net'
ssh user@<ip> 'sudo sshd -T | grep -E "clientalive|allowusers"'

# ── If SSH breaks mid-run ───────────────────────────────────────
# DO NOT close your working session. Open Cockpit's console tab for
# the VM as a second way in before touching anything else.
```
