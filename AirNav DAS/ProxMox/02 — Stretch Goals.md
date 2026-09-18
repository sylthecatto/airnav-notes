---
tags:
  - proxmox
  - virtualization
  - system-discovery
  - moc
aliases:
  - Stretch Goals
  - Wed-Fri Plan
reading-order: 2
created: 2026-09-15
---

# 02 — Stretch Goals: Wednesday–Friday Deep-Dive Plan

**Prerequisite:** [[OLIVERIO_AirNavDAS_SystemDiscoveryTask|System Discovery Task]] finished and working.
**Purpose:** the core assignment is done — this note is self-directed extension work for the rest of the week, in the spirit of the original task's "experimentation" instruction.

> [!abstract] What this document is
> Seven independent, fully step-by-step guides, each deep enough to stand
> alone. None of them require redoing the base build — they all build on
> top of the three working VMs from [[OLIVERIO_AirNavDAS_SystemDiscoveryTask|the main task]].
> Every section that has an official doc, RFC, or vendor guide behind it
> links directly to that source rather than a blog paraphrase of it.

## Contents

- [[#1 · Chaos and failure-mode testing]]
- [[#2 · Snapshots and backup/restore]]
- [[#3 · Automate the build with Ansible]]
- [[#4 · A real security hardening pass]]
- [[#5 · TLS on the reverse proxy]]
- [[#6 · Horizontal scaling: a second App VM behind the load balancer]]
- [[#7 · Centralized logging]]
- [[#8 · Suggested order for the week]]

> [!info] One ground rule across every section
> None of these steps have been run against the real system unit yet —
> this document was written without touching it, so treat every command
> here as **untested on your specific box** even though each one is
> individually correct and sourced from official docs. Read a whole
> section before running its commands, and take a snapshot first (§2)
> before anything destructive.

---

## 1 · Chaos and failure-mode testing

> [!info] Concept: why break it on purpose
> [[OLIVERIO_AirNavDAS_SystemDiscoveryTask|The main task]] proves the *happy path*
> works. It says nothing about what a client-facing failure actually
> looks like at each layer — and "what does it look like when X breaks"
> is exactly the kind of system understanding real infra/MSSP work
> depends on. This is deliberately not something with an "official
> vendor doc" behind it — it's a standard SRE practice; see Google's
> [Embracing Risk](https://sre.google/sre-book/embracing-risk/) chapter
> from the SRE Book for the underlying philosophy if you want the theory.

### 1.1 — Before you start: snapshot everything

Do [[#2 · Snapshots and backup/restore|§2]] first, or at minimum:
```bash
# on the Proxmox host
qm snapshot 100 pre-chaos --description "Before failure testing"
qm snapshot 101 pre-chaos --description "Before failure testing"
qm snapshot 102 pre-chaos --description "Before failure testing"
```
This makes every experiment below free to run — if anything ends up in a
state you don't want, `qm rollback <id> pre-chaos` undoes it instantly.

### 1.2 — The test matrix

Run these one at a time. For each: run the break command, then `curl -v
http://192.168.100.20/` from the laptop, record the HTTP status code and
response body, then look at what each of the three VMs' logs show (or
don't show), then undo the break before moving to the next row.

| # | What you break | Break command (run on the target VM unless noted) | Undo command |
|---|---|---|---|
| 1 | The App's Flask service only | `systemctl stop labapp` | `systemctl start labapp` |
| 2 | The whole App VM | `qm stop 101` (on Proxmox host) | `qm start 101` |
| 3 | MariaDB only | `systemctl stop mariadb` (on DB VM) | `systemctl start mariadb` |
| 4 | The whole DB VM | `qm stop 100` (on Proxmox host) | `qm start 100` |
| 5 | Just the network path to the App VM (without touching the process) | `firewall-cmd --add-rich-rule='rule family="ipv4" source address="10.10.10.10" drop'` (on App VM — blocks only the proxy's traffic) | `firewall-cmd --reload` (drops the temporary rich rule since it wasn't made `--permanent`) |

### 1.3 — What to actually record for each row

For every row, write down (a new subsection in this doc, or a scratch
note — up to you):
1. **The exact HTTP status code and body** curl got back (`502`? `504`?
   `500`? Did it hang and time out instead of returning immediately?)
2. **What Nginx's access log shows** — does it even log an entry for a
   failed upstream, and with what status?
3. **What the App VM's journal shows** (for rows 1 and 5, where the App
   VM itself is still running) — does Flask log an exception, or does it
   just silently never receive the request?
4. **How long the client waited** before getting a response — instant
   failure (connection refused) and slow failure (timeout) feel very
   different to a real user, and are caused by different underlying
   conditions (process not listening at all vs. network path silently
   dropping packets).

> [!info] Concept: why the *same* symptom (a 502) can have different real causes
> Rows 1 and 3 both likely produce broadly similar-looking failures from
> the client's side (some kind of 502/500), but the *reason* is
> completely different underneath — a stopped Flask process vs. an
> exception thrown mid-request when `pymysql.connect()` fails. This is
> exactly why "the proxy returned an error" is never a complete incident
> description in real troubleshooting — you have to look one layer
> further down every time, exactly like you had to when diagnosing the
> AlmaLinux 10 CPU wall in the main task's §5.

> [!info] Concept: what a "real" app would do differently
> `app.py` has **zero error handling** — if `pymysql.connect()` throws,
> Flask's default behavior is an unhandled-exception `500`. A production
> app would typically: retry the DB connection a few times with backoff,
> return a friendly `503 Service Unavailable` instead of a raw stack
> trace, and expose a `/health` endpoint that a load balancer or
> orchestrator polls *before* routing real traffic to it. None of that
> exists here on purpose — seeing the raw, unhandled failure is more
> instructive than a polished one for this exercise.

---

## 2 · Snapshots and backup/restore

**Official docs:** [Proxmox VE Administration Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html) (see its "Snapshots" section) · [Backup and Restore (vzdump) chapter](https://pve.proxmox.com/pve-docs/chapter-vzdump.html)

> [!info] Concept: snapshot vs. backup — they are not the same thing
> A **snapshot** is a fast, storage-level "freeze point" tied to the
> disk it lives on — instant to create and roll back, but it lives *on
> the same storage* as the VM and isn't a standalone, portable file. A
> **backup** (`vzdump`) is a full, portable archive containing the disk
> data *and* the VM's configuration, meant to survive the original
> storage (or even the original host) being gone entirely. Use snapshots
> for "let me try something risky and undo it in 10 seconds"; use
> backups for actual disaster recovery.

### 2.1 — Confirm your storage supports snapshots

This lab's VM disks live on `local-lvm`, an LVM-thin pool — confirmed
earlier in the main task (`Vwi-a-tz--` volumes) — which **does** support
snapshots. Not all Proxmox storage types do; check first if you ever
change storage backend:
```bash
pvesm status
```

### 2.2 — Take a snapshot (UI and CLI)

**Web UI:** select a VM → **Snapshots** tab → **Take Snapshot** → give it
a name and description.

**CLI**, from the Proxmox host:
```bash
qm snapshot 100 my-snapshot-name --description "What state this is"
qm listsnapshot 100          # see all snapshots for this VM
```

### 2.3 — Roll back

**Web UI:** Snapshots tab → select the snapshot → **Rollback**.

**CLI:**
```bash
qm rollback 100 my-snapshot-name
```
> [!danger] Rollback discards everything since the snapshot
> There's no "undo the rollback" — anything written to that VM's disk
> after the snapshot was taken is gone. This is exactly why §1's chaos
> testing takes a snapshot *first*.

### 2.4 — Delete a snapshot once you no longer need it

```bash
qm delsnapshot 100 my-snapshot-name
```
Snapshots aren't free forever — they consume storage proportional to how
much has changed since they were taken. Clean up ones you're done with.

### 2.5 — A real backup, and restoring from it

**Web UI:** select a VM → **Backup** tab → **Backup now** → choose the
storage to write the archive to (e.g. `local`) and the mode (**Snapshot**
mode is the fast, non-disruptive one — the VM keeps running).

**CLI:**
```bash
vzdump 100 --storage local --mode snapshot
```

**Restore** (this creates a **new** VM from the archive — it does not
overwrite the original by default):
```bash
# find the archive filename first
ls /var/lib/vz/dump/
qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vzdump.zst 200
```
That last `200` is the new VM ID for the restored copy — pick any unused
ID. Once restored, you'd normally need to change its network config
(same issue as cloning, see [[#6 · Horizontal scaling: a second App VM behind the load balancer|§6]]) before starting it alongside the original, to avoid an IP/hostname clash.

---

## 3 · Automate the build with Ansible

**Official docs:** [Ansible Playbooks — Community Documentation](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html) · [ansible.posix collection](https://docs.ansible.com/ansible/latest/collections/ansible/posix/index.html) (firewalld, SELinux booleans) · [community.mysql collection](https://docs.ansible.com/ansible/latest/collections/community/mysql/index.html)

> [!info] Concept: Infrastructure as Code
> Everything in the main task was typed by hand, once, into three separate SSH
> sessions. A **playbook** describes the *desired end state* instead —
> "MariaDB should be installed and running, this database should exist"
> — and Ansible figures out what needs to change to get there. Run it
> again on a system that's already correct, and it reports **no
> changes** (this property is called **idempotency**), which is also a
> way to *verify* nothing has drifted from what you expect.

### 3.1 — Install Ansible on the laptop

AlmaLinux ships the core engine in its own repos; the full collection
ecosystem needs EPEL:
```bash
sudo dnf install epel-release -y
sudo dnf install ansible -y
ansible --version
```

### 3.2 — Install the collections this playbook needs

```bash
ansible-galaxy collection install ansible.posix community.mysql community.general
```

### 3.3 — Set up SSH key auth from the laptop to all three VMs

Right now only the Proxmox host has your key — the three guest VMs still
need a password each time. Fix that (you'll be asked for each VM's root
password once):
```bash
for ip in 10.10.10.10 10.10.10.11 10.10.10.12; do
  ssh-copy-id -o "ProxyCommand=ssh -W %h:%p root@192.168.100.2" -i ~/.ssh/id_ed25519.pub root@$ip
done
```

### 3.4 — Project layout

```
~/ansible-lab/
├── ansible.cfg
├── inventory.ini
├── site.yml
├── templates/
│   ├── app.py.j2
│   ├── labapp.service.j2
│   └── labapp.conf.j2
```

`ansible.cfg` — tells Ansible how to reach the internal-only VMs (jump
through Proxmox, same pattern as every `ssh -J` command in the main task):
```ini
[defaults]
inventory = inventory.ini
host_key_checking = False

[ssh_connection]
ssh_args = -o ProxyCommand="ssh -W %h:%p root@192.168.100.2" -o ControlMaster=auto -o ControlPersist=60s
```

`inventory.ini`:
```ini
[db]
10.10.10.12

[app]
10.10.10.11

[proxy]
10.10.10.10

[all:vars]
ansible_user=root
```

Test connectivity before writing anything else:
```bash
cd ~/ansible-lab
ansible all -m ping
```
Every host should reply `"ping": "pong"`. If one doesn't, fix that
connection before continuing — a playbook run against a host it can't
reach will just fail loudly at that host.

### 3.5 — The playbook itself

`site.yml` — reproduces exactly what the main task built by hand:

```yaml
---
- name: Configure DB VM
  hosts: db
  become: true
  tasks:
    - name: Install MariaDB
      dnf:
        name: mariadb-server
        state: present

    - name: Enable and start MariaDB
      systemd:
        name: mariadb
        enabled: true
        state: started

    - name: Create labdb database
      community.mysql.mysql_db:
        name: labdb
        state: present

    - name: Create labuser scoped to the internal network
      community.mysql.mysql_user:
        name: labuser
        password: labpass123
        priv: "labdb.*:ALL"
        host: "10.10.10.%"
        state: present

    - name: Create the greetings table and seed it
      community.mysql.mysql_query:
        login_db: labdb
        query:
          - "CREATE TABLE IF NOT EXISTS greetings (id INT AUTO_INCREMENT PRIMARY KEY, message VARCHAR(255))"
          - "INSERT INTO greetings (message) SELECT 'Hello from the DB VM (via Ansible)!' WHERE NOT EXISTS (SELECT 1 FROM greetings)"

    - name: Open firewall for MariaDB
      ansible.posix.firewalld:
        port: 3306/tcp
        permanent: true
        immediate: true
        state: enabled

- name: Configure App VM
  hosts: app
  become: true
  tasks:
    - name: Install Python and pip
      dnf:
        name:
          - python3
          - python3-pip
        state: present

    - name: Install Flask and pymysql
      pip:
        name:
          - flask
          - pymysql
        executable: pip3

    - name: Create app directory
      file:
        path: /opt/labapp
        state: directory

    - name: Deploy app.py
      template:
        src: templates/app.py.j2
        dest: /opt/labapp/app.py

    - name: Deploy the systemd unit
      template:
        src: templates/labapp.service.j2
        dest: /etc/systemd/system/labapp.service
      notify: restart labapp

    - name: Enable and start labapp
      systemd:
        name: labapp
        enabled: true
        state: started
        daemon_reload: true

    - name: Open firewall for the app
      ansible.posix.firewalld:
        port: 5000/tcp
        permanent: true
        immediate: true
        state: enabled
  handlers:
    - name: restart labapp
      systemd:
        name: labapp
        state: restarted
        daemon_reload: true

- name: Configure Proxy VM
  hosts: proxy
  become: true
  tasks:
    - name: Install nginx
      dnf:
        name: nginx
        state: present

    - name: Deploy reverse proxy config
      template:
        src: templates/labapp.conf.j2
        dest: /etc/nginx/conf.d/labapp.conf
      notify: reload nginx

    - name: Enable and start nginx
      systemd:
        name: nginx
        enabled: true
        state: started

    - name: Open firewall for HTTP
      ansible.posix.firewalld:
        service: http
        permanent: true
        immediate: true
        state: enabled

    - name: Allow nginx to proxy network connections (SELinux)
      ansible.posix.seboolean:
        name: httpd_can_network_connect
        state: true
        persistent: true
  handlers:
    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded
```

The three template files (identical content to the main task's, just
Jinja2-ified — nothing here actually needs a template variable, but
using `.j2` keeps the door open for making the IPs/ports configurable
later):

`templates/app.py.j2`:
```python
from flask import Flask
import pymysql

app = Flask(__name__)

@app.route("/")
def index():
    conn = pymysql.connect(
        host="10.10.10.12", user="labuser",
        password="labpass123", database="labdb"
    )
    with conn.cursor() as cur:
        cur.execute("SELECT message FROM greetings LIMIT 1")
        row = cur.fetchone()
    conn.close()
    return f"<h1>Hello from the App VM</h1><p>DB says: {row[0]}</p>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

`templates/labapp.service.j2`:
```ini
[Unit]
Description=Lab Flask App
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/labapp/app.py
WorkingDirectory=/opt/labapp
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

`templates/labapp.conf.j2`:
```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://10.10.10.11:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### 3.6 — Run it

```bash
ansible-playbook site.yml --check --diff   # dry run first — see what WOULD change
ansible-playbook site.yml                  # for real
```

### 3.7 — Prove idempotency

```bash
ansible-playbook site.yml
```
Run it a **second** time immediately. Every task should report `ok`
rather than `changed`. If anything shows `changed` on a second run
against an already-correct system, that task isn't properly idempotent —
worth investigating why.

> [!tip] This doesn't replace the main task — it documents it differently
> The manual, step-by-step build in the main task is still the right way to
> *learn* what each piece does the first time. This playbook is what you
> reach for the *second* time you need this exact stack — on a fourth VM,
> after a rebuild, or to guarantee three environments are configured
> identically instead of trusting that you typed the same commands three
> times correctly by hand.

---

## 4 · A real security hardening pass

**Official docs:** [AlmaLinux 9 OpenSCAP Guide](https://wiki.almalinux.org/documentation/openscap-guide-for-9.html) · [SCAP Security Guide for AlmaLinux 9](https://complianceascode.github.io/content-pages/guides/ssg-almalinux9-guide-cis.html) · [Red Hat: Writing a custom SELinux policy (RHEL 9)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/writing-a-custom-selinux-policy_using-selinux)

### 4.1 — Run a CIS benchmark scan (start with the DB VM)

Install the scanner and the content package:
```bash
dnf install -y openscap-scanner scap-security-guide
```

Find the exact CIS profile ID available on this system:
```bash
oscap info /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml | grep -i cis
```

Run the scan (Level 1 Server is the less disruptive starting point —
Level 2 is stricter and more likely to flag things that would actually
break this specific lab setup, like remote root SSH):
```bash
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_server_l1 \
  --results /root/cis-results.xml \
  --report /root/cis-report.html \
  /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml
```

Pull the HTML report back to the laptop to actually read it (browsers
don't render well over SSH):
```bash
scp -o "ProxyCommand=ssh -W %h:%p root@192.168.100.2" root@10.10.10.12:/root/cis-report.html .
```
Open `cis-report.html` locally. It lists every check, pass/fail, and
*why* each one matters — read a handful of the failed ones even if you
don't fix them all; understanding the reasoning behind a benchmark item
is the actual point, not a 100% pass score.

> [!danger] Do not blindly auto-remediate
> `oscap xccdf eval --remediate ...` exists and will try to *automatically
> fix* every failed check. **Don't run this on these VMs without a
> snapshot first** (§2) — CIS profiles routinely disable things like
> remote root SSH login, which is exactly how you've been reaching every
> VM in this whole project via `ssh -J`. Take a snapshot, try
> `--remediate` on the DB VM only, see what breaks, and decide item by
> item afterward rather than accepting a benchmark's defaults wholesale
> for a lab you need to keep using.

### 4.2 — Replace the blanket SELinux boolean with a scoped policy

The main task's fix for the `502 Bad Gateway` (§6.3 there) was
`setsebool -P httpd_can_network_connect 1` — correct, but broad: it
allows **every** `httpd_t`-labeled process to connect outbound to
**anything**, not just Nginx to `10.10.10.11:5000` specifically. Build
the narrower version, on the Proxy VM:

**Step 1 — turn the broad fix back off**, so the specific denial happens again:
```bash
setsebool -P httpd_can_network_connect 0
```

**Step 2 — reproduce the denial** (fire a request from the laptop):
```bash
curl http://192.168.100.20/   # expect 502 again
```

**Step 3 — capture the exact denial and generate a module from it:**
```bash
ausearch -m avc -ts recent -c nginx | audit2allow -M nginx-app-connect
```
This writes `nginx-app-connect.pp` (the compiled module) and
`nginx-app-connect.te` (the human-readable source) into the current
directory.

**Step 4 — read the `.te` file before installing it.** This is the step
`audit2allow` itself doesn't do for you — Red Hat's own docs explicitly
warn that suggested rules "can be incorrect in certain cases." Confirm
it only grants `name_connect` (outbound TCP connect) and nothing broader
before proceeding.

**Step 5 — install it:**
```bash
semodule -i nginx-app-connect.pp
```

**Step 6 — retest:**
```bash
curl http://192.168.100.20/   # should be 200 again
```

Now Nginx can make exactly the one kind of connection it actually needs,
and nothing else has changed for any other `httpd_t` process on the
system — a real, meaningfully narrower fix than the blanket boolean, and
a genuinely useful skill for real RHEL-family hardening work.

---

## 5 · TLS on the reverse proxy

**Official docs:** [nginx — Configuring HTTPS servers](https://nginx.org/en/docs/http/configuring_https_servers.html)

> [!info] Concept: why self-signed, not Let's Encrypt, for this lab
> Let's Encrypt (and ACME generally) issues certificates for **public
> DNS names**, and validates ownership over the public internet. This
> lab's Proxy VM sits at a private RFC1918 address (`192.168.100.20`)
> with no public DNS name pointing at it — ACME simply cannot work here,
> not as a matter of configuration but as a matter of what the protocol
> requires. A self-signed certificate is the *correct* choice for an
> internal-only service like this, not a lesser substitute.

### 5.1 — Generate a self-signed certificate (on the Proxy VM)

Modern browsers and `curl` validate against the certificate's **Subject
Alternative Name (SAN)**, not just its Common Name — this has to include
the actual IP being connected to:
```bash
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/labapp.key \
  -out /etc/nginx/ssl/labapp.crt \
  -subj "/CN=192.168.100.20" \
  -addext "subjectAltName=IP:192.168.100.20"
```

### 5.2 — Add an HTTPS server block

Edit `/etc/nginx/conf.d/labapp.conf` to add a second `server` block
(keep the existing port-80 one, or redirect it — shown below):
```nginx
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/ssl/labapp.crt;
    ssl_certificate_key /etc/nginx/ssl/labapp.key;

    location / {
        proxy_pass http://10.10.10.11:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### 5.3 — Apply and open the firewall

```bash
nginx -t
systemctl reload nginx
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```

### 5.4 — Test

```bash
curl -vk https://192.168.100.20/
```
The `-k` flag (insecure) is required here specifically *because* it's
self-signed — `curl` has no way to verify a certificate not signed by a
trusted CA, and that's expected and correct for this setup. A real
public-facing service would instead get a CA-signed cert (Let's Encrypt
or otherwise) precisely so clients *don't* need `-k`.

---

## 6 · Horizontal scaling: a second App VM behind the load balancer

**Official docs:** [nginx — HTTP Load Balancing](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/) · [ngx_http_upstream_module](https://nginx.org/en/docs/http/ngx_http_upstream_module.html)

> [!info] Concept: this is the actual payoff of the 3-tier architecture decision
> [[OLIVERIO_AirNavDAS_SystemDiscoveryTask#A segmented 3-tier shape, not one flat VM|the 3-tier architecture decision]] argued that splitting into tiers lets each one scale independently. This section is where that claim stops being theoretical — adding a second App instance without touching the DB or Proxy at all is only possible *because* of that original design decision.

### 6.1 — Clone the App VM

**Web UI:** right-click VM 101 → **Clone**. Choose **Full Clone** (not
Linked — linked clones depend on the original's disk remaining intact
and unmodified, which adds a constraint you don't want for two
independent app servers). Give it a new VMID (e.g. `103`) and name
(`app2`).

### 6.2 — Fix its network identity

A clone keeps the original's hostname and IP — both need to change
before starting it alongside the original, or you'll have two machines
claiming `10.10.10.11`. Boot `app2`, then on its console:
```bash
hostnamectl set-hostname app2
nmcli connection modify ens18 ipv4.addresses 10.10.10.13/24
nmcli connection up ens18
```

### 6.3 — Make the two App instances visibly distinguishable

So you can actually *see* the load balancer alternating between them
rather than taking it on faith, edit `/opt/labapp/app.py` on **each**
instance to identify itself:
```python
# on 10.10.10.11 (the original), change the return line to:
    return f"<h1>Hello from App VM 1 (10.10.10.11)</h1><p>DB says: {row[0]}</p>"

# on 10.10.10.13 (the clone), change it to:
    return f"<h1>Hello from App VM 2 (10.10.10.13)</h1><p>DB says: {row[0]}</p>"
```
```bash
systemctl restart labapp   # on each, after editing
```

### 6.4 — Turn Nginx into a real load balancer

On the Proxy VM, replace the single `proxy_pass` target with an
`upstream` block listing both:
```nginx
upstream labapp_backend {
    server 10.10.10.11:5000;
    server 10.10.10.13:5000;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://labapp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```
```bash
nginx -t
systemctl reload nginx
```

### 6.5 — Prove it

From the laptop, fire several requests in a row:
```bash
for i in {1..6}; do curl -s http://192.168.100.20/; echo; done
```
Nginx's default algorithm is round-robin — you should see the response
alternate between "App VM 1" and "App VM 2" on successive requests.

> [!tip] What this doesn't cover yet
> This is round-robin only — no health checking (a dead backend would
> still get roughly half the traffic and fail), no session affinity, no
> weighting. NGINX's free/open-source build's health-check and
> API-driven reconfiguration features live behind NGINX Plus (see the
> commercial notice in the [official upstream module docs](https://nginx.org/en/docs/http/ngx_http_upstream_module.html)) — worth
> knowing that boundary exists if you ever need those specific features
> for real.

---

## 7 · Centralized logging

**Official docs:** [Red Hat: Configuring a remote logging solution (RHEL 9)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/security_hardening/assembly_configuring-a-remote-logging-solution_security-hardening) · [rsyslog: Forwarding Logs](https://docs.rsyslog.com/doc/getting_started/forwarding_logs.html)

> [!info] Concept: why this matters beyond convenience
> [[OLIVERIO_AirNavDAS_SystemDiscoveryTask#7 · Part Five — Proving it: tracing one request across every hop|§7 of the main task]] proved the request trace by opening three separate SSH sessions and manually tailing three files at once. That's fine for a one-off proof; it doesn't scale to "an incident happened at 3am, which of thirty servers logged something relevant." Centralizing solves that.

> [!tip] Why rsyslog and not a full log stack here
> A Grafana Loki + Promtail stack is the more feature-rich modern
> answer, but it needs meaningfully more RAM than this 3.7 GB host
> comfortably has to spare on top of three VMs already running.
> `rsyslog` is almost certainly **already installed** on all three
> AlmaLinux VMs (it ships by default alongside journald on RHEL-family
> minimal installs) — this gets you real centralization for effectively
> zero extra resource cost. If you ever move this exercise to bigger
> hardware, Loki/Promtail or `systemd-journal-remote` (also covered in
> the Red Hat doc linked above) are worth revisiting.

### 7.1 — Pick a receiver

Reuse the Proxy VM as the log receiver too — it's already the one
publicly-reachable box, no new VM needed.

### 7.2 — Configure the receiver to accept incoming logs

On the **Proxy VM**, edit `/etc/rsyslog.conf` — uncomment (or add) the
TCP listener:
```
module(load="imtcp")
input(type="imtcp" port="514")
```
```bash
systemctl restart rsyslog
firewall-cmd --permanent --add-port=514/tcp
firewall-cmd --reload
```

### 7.3 — Point the DB and App VMs at it

On **both** the DB VM and the App VM, add one line to the end of
`/etc/rsyslog.conf` (the double-`@` means TCP; a single `@` would mean
UDP, which is faster but can silently drop messages):
```
*.* @@10.10.10.10:514
```
```bash
systemctl restart rsyslog
```

### 7.4 — Also forward the App and Nginx application logs specifically

`journalctl -u labapp` and Nginx's access log aren't part of the generic
syslog facility by default, so the line above alone won't pick them up.
Two options, in order of effort:
- **Simplest:** on the App VM, have systemd forward journal entries
  into syslog too (it already does, via `systemd-journald`'s own
  forwarding to syslog, controlled by `ForwardToSyslog=yes` in
  `/etc/systemd/journald.conf` — confirm it's set, then `systemctl
  restart systemd-journald`).
- **For Nginx specifically:** change its access log destination to also
  write via syslog: add `access_log syslog:server=10.10.10.10:514
  main;` to the `server` block in `labapp.conf` on the Proxy VM itself
  (it can log to its own local rsyslog, which is already forwarding).

### 7.5 — Confirm it's working

On the **Proxy VM** (the receiver), watch the centralized log while
firing a request from the laptop:
```bash
tail -f /var/log/messages
```
```bash
# from the laptop, separately:
curl http://192.168.100.20/
```
You should see log lines originating from **all three** hostnames
(`db`, `app`, `proxy`) arriving in this one file — the same three-hop
proof as §7 of the main task, but from a single vantage point instead of three
SSH sessions.

---

## 8 · Suggested order for the week

| Day | Focus | Why this order |
|---|---|---|
| Wednesday AM | [[#1 · Chaos and failure-mode testing|§1]] | Cheapest, most directly matches the task's "experimentation" instruction, deepens understanding of what's already built |
| Wednesday PM | [[#2 · Snapshots and backup/restore|§2]] | Should really precede §1's risk-taking, but doing it right after makes the "why did I want this" lesson land harder — reorder if you'd rather snapshot first |
| Thursday | [[#3 · Automate the build with Ansible|§3]] | Biggest single skill jump; benefits from a full, uninterrupted day |
| Friday AM | [[#4 · A real security hardening pass|§4]] | Most directly relevant to actual MSSP/vuln-management work |
| Friday PM | Pick one: [[#5 · TLS on the reverse proxy|§5]], [[#6 · Horizontal scaling: a second App VM behind the load balancer|§6]], or [[#7 · Centralized logging|§7]] | Whichever sounds most interesting — all three are genuinely optional polish at this point, not core learning |

Nothing here is mandatory or sequenced by a hard dependency except
"snapshot before you break things" — reorder freely to match what's
actually interesting on the day.
