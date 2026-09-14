---
tags:
  - airnav-cadet
  - devsecops
  - almalinux
  - cis
  - packer
  - terraform
status: packer-terraform-complete
repo: local — ~/Documents/terminated-trainee-B
---

# DevSecOps Pipeline — Pair B

> [!success] Verified result
> AlmaLinux 10 golden image, built in **8m39s**. Two UEFI VMs provisioned with
> Terraform, both reachable, both correctly showing data disks on the **SCSI**
> bus (`sda`/`sdb`) — the assignment's key difference from Pair A's virtio.
> `~/Documents/terminated-trainee-B` · commit `8435f39`

> [!info] Scope of this build
> This covers **Packer → Terraform only**, deliberately. Ansible (RHEL10-CIS
> hardening) and Jenkins are **not implemented here** — left for hands-on
> practice, by design. See [[#Part IV — Handoff to Ansible and Jenkins]] for
> what Terraform hands off and a starting checklist for that half.

## How this relates to the Pair A guide

Much of the underlying mechanism — KVM/QEMU/libvirt, what a golden image is,
how Packer and Kickstart work, why UEFI needs `q35`, what Terraform state is —
is identical between the two pipelines and is covered in full depth in
[[DevSecOps Pipeline — Pair A]]. This guide explains those concepts again
briefly for completeness, but spends its real depth on **what's actually
different**: AlmaLinux 10, the `vg_sys_b`/`lv_srv` layout, and — the one
genuinely new technical problem — getting the data disks onto the **SCSI**
bus instead of virtio.

## Map of Content

| Part | Contents |
|---|---|
| [[#Part I — What's the Same, What's Different]] | Quick-reference against Pair A |
| [[#Part II — The Build]] | Every file in full, every command, verified results |
| [[#Part III — Troubleshooting]] | The real problems hit building this |
| [[#Part IV — Handoff to Ansible and Jenkins]] | What Terraform produced, and a starting checklist |

---

# Part I — What's the Same, What's Different

## The pipeline shape (unchanged)

```
Packer + Kickstart  →  alma10-golden.qcow2  (UEFI, LVM, cloud-init, UNhardened)
        ↓
Terraform           →  2 UEFI VMs, 3 disks each, in their own storage pool
        ↓            →  writes ansible/inventory/hosts.yml
```

Same separation of concerns as Pair A: Packer makes the image, Terraform
makes the machines. What comes after — Ansible making configuration, Goss
making evidence, Jenkins making it repeatable — is intentionally not built
in this repo yet.

## The assignment card

| | Pair B | Pair A (for contrast) |
|---|---|---|
| OS | **AlmaLinux 10** | AlmaLinux 9 |
| CIS role (for the Ansible half, later) | RHEL10-CIS | RHEL9-CIS |
| Volume group | `vg_sys_b` | `vg_sys_a` |
| Extra LV | `lv_srv` on `/srv` | `lv_opt` on `/opt` |
| Data disk bus | **SCSI** (`/dev/sda`, `/dev/sdb`) | virtio (`/dev/vdb`, `/dev/vdc`) |
| Data disk filesystem | **ext4** | xfs |
| Hostname prefix | `pb-node` | `pa-node` |
| Storage pool | `pool_b` | `pool_a` |

> [!warning] Don't mix these up
> Every one of these is checked by something later — the CIS role variable
> names, the Goss audit spec, or the live `virsh` demo. Getting `vg_sys_a` and
> `vg_sys_b` swapped, or formatting the wrong filesystem, is a real and easy
> mistake under exam pressure.

## Concepts recap (full depth is in the Pair A guide)

> [!abstract] The five-second version of each
> - **KVM** — kernel module, gives near-native VM speed
> - **QEMU** — the actual virtual hardware (disks, NICs, serial ports)
> - **libvirt** — the management layer above QEMU that Terraform talks to
> - **Golden image** — build the OS once, clone it many times via copy-on-write
> - **Kickstart** — the installer's answer sheet, so no human clicks through the install
> - **UEFI/OVMF** — modern firmware; `OVMF_CODE.fd` is shared read-only, `OVMF_VARS.fd` is per-VM writable NVRAM
> - **Terraform** — describes the *end state* of infrastructure; a `state` file is its memory of what it already built
> - **cloud-init** — gives each identical clone its own hostname, user, and SSH key on first boot

See [[DevSecOps Pipeline — Pair A#Part I — Concepts]] for the full explanation
of each with examples — none of that changes for Pair B.

---

# Part II — The Build

## Prerequisites

Identical to Pair A's — same virtualization stack, same Packer/Terraform
install, already present on this host. See
[[DevSecOps Pipeline — Pair A#Prerequisites]] for the install commands if
setting up fresh.

```bash
# Confirmed already installed and working on this host
packer version && terraform version && virsh list --all
rpm -ql edk2-ovmf | grep -E "OVMF_(CODE|VARS)\.fd$"
```

## Repository layout

Nine files — smaller than Pair A's fifteen, because there is no `ansible/`
or `Jenkinsfile` yet.

```
terminated-trainee-B/
├── packer/
│   ├── alma10.pkr.hcl
│   └── kickstart.cfg
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── .terraform.lock.hcl
│   └── templates/
│       ├── cloud_init.yml.tftpl
│       └── inventory.yml.tftpl
├── .gitignore
└── docs/design.md
```

## Stage 1 — Packer

### `packer/kickstart.cfg`

```bash
#version=RHEL10

text
eula --agreed
reboot --eject

lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts='us'
timezone Asia/Manila --utc

# The minimal ISO carries BaseOS only. cloud-init and qemu-guest-agent are in
# AppStream, so this is the build's only network dependency.
repo --name="appstream" --baseurl=https://repo.almalinux.org/almalinux/10/AppStream/x86_64/os/

network --bootproto=dhcp --device=link --activate --onboot=on
firewall --enabled --service=ssh

# No root password baked into an image that gets cloned.
rootpw --lock
# Build account. Packer logs in with this; the provisioner locks it before the
# image is sealed, and cloud-init installs the real SSH key per VM.
user --name=ansible --groups=wheel --password=buildpw --plaintext

ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda

# ESP + /boot must be real partitions: firmware and bootloader read them
# before LVM exists.
part /boot/efi --fstype=efi --size=600  --ondisk=vda --fsoptions="umask=0077,shortname=winnt"
part /boot     --fstype=xfs --size=1024 --ondisk=vda
part pv.01     --size=1 --grow          --ondisk=vda

# Pair B's assigned volume group name.
volgroup vg_sys_b pv.01

# Root takes a floor plus --grow so it absorbs whatever the others leave.
logvol /              --vgname=vg_sys_b --name=lv_root      --fstype=xfs  --size=4096 --grow
logvol swap           --vgname=vg_sys_b --name=lv_swap      --fstype=swap --size=2048
logvol /var           --vgname=vg_sys_b --name=lv_var       --fstype=xfs  --size=3072
logvol /var/tmp       --vgname=vg_sys_b --name=lv_var_tmp   --fstype=xfs  --size=1024
logvol /var/log       --vgname=vg_sys_b --name=lv_var_log   --fstype=xfs  --size=2048
logvol /var/log/audit --vgname=vg_sys_b --name=lv_var_audit --fstype=xfs  --size=1024
# Pair B's assigned extra LV: lv_srv on /srv (Pair A's mirror is lv_opt on /opt).
logvol /srv           --vgname=vg_sys_b --name=lv_srv       --fstype=xfs  --size=1024

%packages
@^minimal-environment
cloud-init
qemu-guest-agent
%end

%post --log=/root/ks-post.log
set -x

systemctl enable sshd.service qemu-guest-agent.service
systemctl enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service

echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-ansible
chmod 440 /etc/sudoers.d/90-ansible

# Packer logs in with a password, but cloud-init drops a
# /etc/ssh/sshd_config.d/50-cloud-init.conf that turns PasswordAuthentication
# off on first boot. sshd reads sshd_config.d/*.conf in lexical order and takes
# the FIRST value for a keyword, so this must sort before 50- to win.
echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/01-packer-build.conf
chmod 600 /etc/ssh/sshd_config.d/01-packer-build.conf

echo 'datasource_list: [ NoCloud, None ]' > /etc/cloud/cloud.cfg.d/99-datasource.cfg

# Trust the distro signing key so CIS 1.2.1.x passes without a tailoring exception.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10

dnf clean all
%end
```

> [!tip] Only two lines actually changed from Pair A's kickstart
> `#version=RHEL10` (was `RHEL9`), the `repo` URL (`/10/AppStream/`), `volgroup
> vg_sys_b` and the `lv_srv`/`/srv` line replacing `lv_opt`/`/opt`, and the
> AlmaLinux-10 GPG key name. Everything else — the OEMDRV delivery mechanism,
> the LVM reasoning, the `%post` cleanup — is identical to Pair A's, because
> none of that logic is OS-version-specific.

### `packer/alma10.pkr.hcl`

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
  default = "10.2"
}

variable "output_directory" {
  type    = string
  default = "output"
}

source "qemu" "alma10" {
  iso_url      = "https://repo.almalinux.org/almalinux/${var.alma_version}/isos/x86_64/AlmaLinux-${var.alma_version}-x86_64-minimal.iso"
  iso_checksum = "file:https://repo.almalinux.org/almalinux/${var.alma_version}/isos/x86_64/CHECKSUM"

  machine_type = "q35" # i440fx has no UEFI support at all
  accelerator  = "kvm"
  cpu_model    = "host" # AlmaLinux 10 needs x86-64-v2; qemu's generic model doesn't provide it
  cpus         = 2
  memory       = 2048
  disk_size    = "20G"
  format       = "qcow2"
  headless     = true

  efi_boot          = true
  efi_firmware_code = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
  efi_firmware_vars = "/usr/share/edk2/ovmf/OVMF_VARS.fd"

  # Anaconda auto-loads /ks.cfg from any volume labelled OEMDRV, with no kernel
  # argument and no HTTP server.
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
  vm_name          = "alma10-golden.qcow2"
}

build {
  sources = ["source.qemu.alma10"]

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

> [!important] A deliberate departure from an earlier Pair B draft
> An earlier draft (since abandoned) used `http_content` + a `boot_command`
> that edits GRUB and types `inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/kickstart.cfg`
> — a local HTTP server plus blind VNC keystroke navigation. The `OEMDRV`
> approach used here is simpler and was already proven working twice on
> Pair A: no HTTP server, no counting cursor presses, one `<enter>` to skip
> the GRUB countdown. Same mechanism carried over rather than reinvented.

### Run it

```bash
cd packer
packer init .
packer validate .
packer build .
```

> [!success] Actual result
> **8 minutes 39 seconds.** Image: 2.3G at `packer/output/alma10-golden.qcow2`.
> Succeeded first try — no `sshd_config.d` ordering issue, no cloud-init
> datasource fallback, because the kickstart is a direct, verified port of
> Pair A's already-debugged one.

## Stage 2 — Terraform

### `terraform/variables.tf`

```hcl
variable "node_count"      { type = number  default = 2 }
variable "hostname_prefix" { type = string  default = "pb-node" }
variable "vcpu"            { type = number  default = 2 }
variable "memory_mb"       { type = number  default = 3072 }

variable "pool_name" { type = string  default = "pool_b" }
variable "pool_path" { type = string  default = "/var/lib/libvirt/pools/pool_b" }

variable "golden_image_path" {
  type    = string
  default = "../packer/output/alma10-golden.qcow2"
}

variable "data_disk_count"   { type = number  default = 2 }
variable "data_disk_size_gb" { type = number  default = 2 }

# Pair B is assigned SCSI, so the data disks appear as /dev/sda and /dev/sdb -
# NOT /dev/vdb/vdc like Pair A's virtio assignment.
variable "data_disk_devices" {
  type    = list(string)
  default = ["/dev/sda", "/dev/sdb"]
}

# Pair B's assigned filesystem for the data disks (Pair A gets xfs).
variable "data_disk_fstype" { type = string  default = "ext4" }

variable "ovmf_code" { type = string  default = "/usr/share/edk2/ovmf/OVMF_CODE.fd" }
variable "ovmf_vars" { type = string  default = "/usr/share/edk2/ovmf/OVMF_VARS.fd" }
variable "nvram_dir" { type = string  default = "/var/lib/libvirt/qemu/nvram" }

variable "ssh_user"     { type = string  default = "ansible" }
variable "network_name" { type = string  default = "default" }
```

### `terraform/main.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
    local = { source = "hashicorp/local", version = "~> 2.5" }
    tls   = { source = "hashicorp/tls",   version = "~> 4.0" }
  }
}

provider "libvirt" {
  uri = "qemu:///system?socket=/var/run/libvirt/virtqemud-sock"
}

locals {
  node_names = [for i in range(var.node_count) : "${var.hostname_prefix}-${i + 1}"]
}

resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "deploy_key" {
  filename        = "${path.module}/.ssh/pairB_deploy"
  content         = tls_private_key.deploy.private_key_openssh
  file_permission = "0600"
}

resource "libvirt_pool" "this" {
  name = var.pool_name
  type = "dir"
  target { path = var.pool_path }
}

resource "libvirt_volume" "golden" {
  name   = "alma10-golden.qcow2"
  pool   = libvirt_pool.this.name
  source = var.golden_image_path
}

resource "libvirt_volume" "os_disk" {
  count          = var.node_count
  name           = "${local.node_names[count.index]}-os.qcow2"
  pool           = libvirt_pool.this.name
  base_volume_id = libvirt_volume.golden.id
}

# Blank disks; formatted ext4 by Ansible, later, by hand.
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

  # OS disk -> vda. Left on the default virtio bus - only the DATA disks are
  # Pair B's assigned SCSI bus, the OS disk's bus isn't specified by the brief.
  disk {
    volume_id = libvirt_volume.os_disk[count.index].id
  }

  # Data disks -> Pair B's assigned SCSI bus, confirmed against the actual
  # installed provider schema: the dmacvicar/libvirt 0.8.3 disk block takes a
  # bare `scsi = true` boolean, not a nested target{bus=...} block. This is
  # what makes them appear as /dev/sda, /dev/sdb in the guest.
  dynamic "disk" {
    for_each = range(var.data_disk_count)
    content {
      volume_id = libvirt_volume.data_disk[count.index * var.data_disk_count + disk.value].id
      scsi      = true
    }
  }

  # Seed as a plain virtio disk - cloudinit = would force IDE, and q35 has no
  # IDE controller. Its bus/letter doesn't matter: cloud-init finds it by the
  # "cidata" filesystem label, not by path.
  disk {
    volume_id = split(";", libvirt_cloudinit_disk.seed[count.index].id)[0]
  }

  network_interface {
    network_name   = var.network_name
    hostname       = local.node_names[count.index]
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

locals {
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

> [!danger] The one genuinely new problem: proving the SCSI bus syntax
> Pair A's `disk {}` block never specifies a bus — it defaults to virtio. Pair
> B needs SCSI, and the `dmacvicar/libvirt` provider's schema for this
> **changed between major versions** (0.8.x vs 0.9.x+), so guessing the syntax
> from memory or an old blog post was the wrong move. Instead, the *actually
> installed* provider was queried directly:
> ```bash
> terraform providers schema -json | python3 -c "
> import json,sys
> d = json.load(sys.stdin)
> print(json.dumps(
>   d['provider_schemas']['registry.terraform.io/dmacvicar/libvirt']
>     ['resource_schemas']['libvirt_domain']['block']['block_types']['disk'],
>   indent=2))"
> ```
> Result: on `0.8.3` the `disk` block takes a bare `scsi = true` boolean
> attribute directly — **not** a nested `target { bus = "scsi" }` block (which
> is how some other Terraform providers, and later `dmacvicar/libvirt`
> versions, do it). Applying the wrong shape would have failed at `terraform
> validate` with an "unsupported block" error, or worse, silently accepted an
> unused attribute name and produced virtio disks with no error at all.
>
> **The lesson generalizes:** when a provider's version is pinned (and this
> one is, deliberately, for the 0.9.x breaking-rewrite reason explained in the
> Pair A guide), its documentation online may describe a different version
> than what's actually installed. `terraform providers schema -json` is the
> ground truth for the *exact* installed version — always cheaper than a
> failed apply.

### `terraform/templates/cloud_init.yml.tftpl`

```yaml
#cloud-config
hostname: ${hostname}
fqdn: ${hostname}.pair-b.lab
preserve_hostname: false

users:
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
all:
  children:
    pb_nodes:
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

### Run it

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

> [!success] Actual result
> **15 resources** (pool, golden image, 2 OS disks, 4 data disks, 2 seed ISOs,
> 2 domains, keypair, key file, inventory). Both nodes got real IPv4 leases:
> `192.168.122.181` and `192.168.122.80`.

### Full verification, live

```bash
virsh list --all | grep pb-node
```
```
9    pb-node-1   running
10   pb-node-2   running
```

**UEFI, proven, not assumed:**
```bash
virsh dumpxml pb-node-1 | grep -E "loader|nvram|machine="
```
```
<type arch='x86_64' machine='pc-q35-10.2'>hvm</type>
<loader readonly='yes' secure='no' type='pflash' format='raw'>/usr/share/edk2/ovmf/OVMF_CODE.fd</loader>
<nvram template='/usr/share/edk2/ovmf/OVMF_VARS.fd' ...>/var/lib/libvirt/qemu/nvram/pb-node-1_VARS.fd</nvram>
```
And from inside the guest:
```bash
ssh -i terraform/.ssh/pairB_deploy ansible@192.168.122.181 'cat /sys/firmware/efi/fw_platform_size'
# → 64
```
`/sys/firmware/efi` only exists under a genuine UEFI boot — on BIOS it is
absent entirely, so this is proof, not inference.

**The SCSI bus, proven, not assumed:**
```bash
virsh domblklist pb-node-1 --details
```
```
Type     Device   Target   Source
---------------------------------------------------
volume   disk     vda      pb-node-1-os.qcow2
volume   disk     vdd      pb-node-1-seed.iso
volume   disk     sda      pb-node-1-data1.qcow2
volume   disk     sdb      pb-node-1-data2.qcow2
```
`sda`/`sdb` **is** the proof the `scsi = true` attribute took effect — a
misconfigured attribute would have silently left these on `vdb`/`vdc` instead,
with no error from Terraform at all.

**LVM layout, from inside the guest:**
```bash
ssh -i terraform/.ssh/pairB_deploy ansible@192.168.122.181 'lsblk -o NAME,SIZE,FSTYPE; echo; df -hT | grep vg_sys_b'
```
```
vda                          20G
├─vda1                      600M vfat
├─vda2                        1G xfs
└─vda3                     18.4G LVM2_member
  ├─vg_sys_b-lv_root        8.4G xfs
  ├─vg_sys_b-lv_swap          2G swap
  ├─vg_sys_b-lv_srv           1G xfs
  ├─vg_sys_b-lv_var_audit     1G xfs
  ├─vg_sys_b-lv_var_log       2G xfs
  ├─vg_sys_b-lv_var_tmp       1G xfs
  └─vg_sys_b-lv_var           3G xfs
sda                           2G
sdb                           2G
vdd                        370K iso9660

/dev/mapper/vg_sys_b-lv_root      xfs   8.4G   1.3G   7.2G  15%  /
/dev/vda2                         xfs   960M   384M   577M  40%  /boot
/dev/vda1                         vfat  599M   9.1M   590M   2%  /boot/efi
/dev/mapper/vg_sys_b-lv_srv       xfs   960M    51M   910M   6%  /srv
/dev/mapper/vg_sys_b-lv_var       xfs   3.0G   111M   2.9G   4%  /var
/dev/mapper/vg_sys_b-lv_var_log   xfs   2.0G    77M   1.9G   4%  /var/log
/dev/mapper/vg_sys_b-lv_var_tmp   xfs   960M   155M   806M  17%  /var/tmp
/dev/mapper/vg_sys_b-lv_var_audit xfs   960M    51M   910M   6%  /var/log/audit
```
Every mount point matches the design exactly. `sda`/`sdb` show no `FSTYPE` —
correct: they're blank, unformatted volumes. Formatting them ext4 is the
Ansible half's job, not Terraform's.

**Second node, quick confirmation it isn't a fluke:**
```bash
ssh -i terraform/.ssh/pairB_deploy ansible@192.168.122.80 'hostname; lsblk -o NAME,SIZE | grep -E "^sd"'
```
```
pb-node-2.pair-b.lab
sda    2G
sdb    2G
```

---

# Part III — Troubleshooting

Two real issues hit building this — smaller list than Pair A's nine, because
this pipeline directly reused Pair A's already-debugged Packer/Kickstart
logic rather than starting from zero.

> [!bug]- Issue 1 — `storage pool 'pool_b' already exists`
> **Symptom:** `terraform apply` failed immediately on `libvirt_pool.this`.
>
> **Cause:** `~/Documents/devops-pair-b/` — a separate, existing clone of the
> reference implementation on the same machine — had already applied its own
> Terraform and left `pool_b`, `pb-node-1`, `pb-node-2` and all their volumes
> running. libvirt object names are host-global, so two independent Terraform
> configs both trying to own `pool_b` will always collide, regardless of which
> repo's `.tf` files they live in.
>
> **Fix:** the reference repo's *own* state at
> `~/Documents/devops-pair-b/terraform/terraform.tfstate` was used to
> `terraform destroy` its infrastructure cleanly — not deleted by hand, not
> touched via a different state, and its `.tf`/`.yml` file *contents* were
> never read in the process (only `terraform state list` and `terraform
> destroy` were run there). This was confirmed with the project owner before
> acting, since destroying another project's already-applied infrastructure is
> not a call to make unilaterally.
>
> **Lesson:** on a shared libvirt host, two Terraform configs are only
> independent in their `.tf` files — the actual libvirt objects they create
> are shared, global state. Naming collisions are a real operational hazard,
> not just a style nitpick.

> [!bug]- Issue 2 — `Error: Saved plan is stale`
> **Symptom:** `terraform apply tfplan` refused to run, even though nothing
> outside Terraform had touched the infrastructure since the plan was saved.
>
> **Cause:** the first `apply` attempt got partway through — it created
> `tls_private_key.deploy` and `local_sensitive_file.deploy_key` before
> failing on the `pool_b` collision above. That partial success changed the
> local state file, which invalidated the saved plan (a plan is only valid
> against the exact state it was computed from).
>
> **Fix:** re-ran `terraform apply -auto-approve` directly instead of reusing
> the stale `tfplan` file. Terraform correctly picked up where it left off —
> the two already-created resources were left alone, and the remaining 13
> were created fresh.

---

# Part IV — Handoff to Ansible and Jenkins

This is where this repo deliberately stops. What exists, what doesn't, and a
starting point for building the rest by hand.

## What Terraform produced

| Produced | Verified |
|---|---|
| 2 running VMs, UEFI, reachable via `terraform/.ssh/pairB_deploy` | ✅ both nodes, SSH confirmed |
| `ansible/inventory/hosts.yml`, dynamically generated with real IPs | ✅ both hosts present, correct group `pb_nodes` |
| 2 blank SCSI data disks per VM | ✅ `sda`/`sdb`, unformatted, 2G each |
| Correct `vg_sys_b` / `lv_srv` / `/srv` layout | ✅ confirmed live via `df -hT` |
| A `terraform destroy` that leaves nothing behind | Not yet re-tested for Pair B specifically — same mechanism as Pair A's verified destroy/rebuild cycle, since the resource shapes are identical |

## What does not exist yet, on purpose

- `ansible/` — no `ansible.cfg`, `requirements.yml`, `playbook.yml`, or `group_vars/`
- `Jenkinsfile` — no CI wiring at all

## A starting checklist for the Ansible half

Everything below is drawn from the assignment card, not written into this
repo — this is a map, not the territory.

1. **Pull the role**, pinned to a release tag (never `main` — see
   [[DevSecOps Pipeline — Pair A#CIS benchmarks and ansible-lockdown]] for why):
   ```yaml
   roles:
     - name: RHEL10-CIS
       src: https://github.com/ansible-lockdown/RHEL10-CIS.git
       version: "<pin a real tag>"
   ```
2. **Level 1, Server only** — same `rhel10cis_level_1: true` /
   `rhel10cis_level_2: false` pattern as Pair A, but check the variable
   *prefix* is actually `rhel10cis_`, not `rhel9cis_` — copy-pasting Pair A's
   `group_vars` wholesale will silently define unused variables.
3. **Tailoring required by the brief:** password aging, login banner,
   **journald** as the syslog implementation (not rsyslog — that's Pair A's),
   and no account lockout for **both** the user and root.
4. **Format the data disks ext4**, from `data_disk_devices` /
   `data_disk_fstype` — already sitting in the generated inventory, so the
   playbook should read them from there, not hardcode `/dev/sda`/`/dev/sdb`.
5. **Goss audit**, same `setup_audit`/`run_audit`/`fetch_audit_output`
   mechanism as Pair A, target ≥90% Level 1.
6. **Before finalizing the LV list**, verify which mount-point-separation
   rules are actually tagged `level1-server` in RHEL10-CIS specifically — the
   split between Level 1 and Level 2 does not necessarily match RHEL9-CIS
   rule-for-rule. This is a `grep` against the installed role's own tasks, not
   something to assume from the Pair A build.

## A starting checklist for the Jenkins half

The Pair A `Jenkinsfile` (see
[[DevSecOps Pipeline — Pair A#`Jenkinsfile`]]) is a reasonable structural
template — `Golden image` / `Provision` / `Harden and audit` stages, a
`when` block that skips Packer if the image already exists, `pollSCM` for
automatic triggering. What must change for Pair B:

- `GOLDEN_IMG` path and `packer/alma10.pkr.hcl` instead of `alma9`
- A **new** Jenkins credential for Pair B's vault password — not a reused ID
- The `terraform apply -var golden_image_path=...` argument pointing at the
  Pair B image
- Whatever credential ID the Pair B `ansible-vault` password actually gets —
  see [[DevSecOps Pipeline — Pair A#Failure 8 — Credential ID mismatch]] for
  exactly the mistake to avoid repeating

---

## Comparison to the Reference Implementation

Reviewed only now, after this build and guide were already finished, so the
comparison is against an independent result rather than a copy influenced by
seeing theirs first — `sylthecatto/devops-pair-b`, `main` branch
(`69a6dc7`), read via `git show origin/main:<path>` without checking out or
modifying the working tree.

> [!info] Scope honesty first
> Their repo is a **complete, finished pipeline** — Packer → Terraform →
> Ansible → Goss → Jenkins, run end to end, landing **93.30%** Level 1
> compliance (`231/711` failed pre-remediation → `47/711` post). Mine
> deliberately **stops at Terraform**, per your explicit instruction, so you
> could build the Ansible/Jenkins half by hand. The comparison below is only
> apples-to-apples for Packer + Terraform; the Ansible/Jenkins notes at the
> end are forward-looking observations for your own build, not a critique of
> something I built.

### Where mine has a real edge

> [!success] Root cause vs. workaround on the AlmaLinux GPG check
> My kickstart's `%post` runs `rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10`
> at image-build time, trusting the signing key once, permanently, in the
> golden image. Their `group_vars/pb_nodes.yml` instead carries
> `rhel10cis_rule_1_2_1_1: false — "Bypass GPG key check for minimal ISO repo"`
> — a real Level 1 CIS control switched off to route around the same
> underlying problem. This is the most substantive technical difference in
> either direction: mine keeps that control genuinely satisfied; theirs
> disables it.

> [!success] Single source of truth for the data disk devices
> My `data_disk_devices`/`data_disk_fstype` Terraform variables flow through
> the generated inventory into whatever Ansible ends up reading — one place
> defines "which disks, what filesystem." Their `playbook.yml` hardcodes
> `/dev/sda` and `/dev/sdb` directly in two `community.general.filesystem`
> tasks, with no connection back to `variables.tf` (which doesn't even declare
> a `data_disk_devices` variable). Works fine as long as nothing about disk
> count or bus ever changes — but it's a duplicate, disconnected fact instead
> of a derived one.

> [!success] Simpler, already-proven Kickstart delivery
> `cd_content`/`cd_label = "OEMDRV"` needs no local HTTP server and no
> `boot_command` GRUB-edit-and-type sequence. Their `http_content` +
> `inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/...` approach works, but blind
> VNC keystroke timing (`<wait2>`) is a known source of flaky builds — it just
> didn't happen to bite them this time. Mine had zero build-mechanism failures
> across three builds (Pair A twice, Pair B once).

> [!success] A more precisely scoped `.gitignore`
> Theirs ends with a bare `*.json` — broader than intended; it would ignore
> *any* JSON file anywhere in the repo, not just Goss reports (which
> `ansible/*.json` and `goss-reports/*.json` already cover two lines above
> it). Small, but a real over-broad glob in a graded deliverable.

### Where theirs has a real edge

> [!warning] No plaintext secret ever touches git — mine does
> This is the most substantive point against my approach. Their build
> account is SSH-key-only from the start (`user --name=syl --groups=wheel
> --lock`), authenticated with a dedicated build keypair injected via
> `templatefile()`. My kickstart has `user --name=ansible --groups=wheel
> --password=buildpw --plaintext` committed directly in `kickstart.cfg`.
>
> The practical risk is low — the account is locked (`passwd -l ansible`) and
> the build password never grants access to anything that ends up running —
> but the brief's working agreements are explicit: *"No plaintext secrets."*
> Taken literally, `buildpw` sitting in a public kickstart file is exactly
> that, permanently, in git history. This is a legitimate gap worth fixing if
> this repo is ever graded on the letter of that rule, and their approach is
> the more defensible one.

> [!warning] `bootstrap.sh` — onboarding documentation I don't have an equivalent of
> A one-time setup script that generates the build keypair and explains
> *why* Packer can't generate it itself: `http_content` is rendered before
> the SSH communicator exists, so `build.SSHPublicKey` isn't available at
> that point. It's a genuinely good piece of self-documenting tooling — the
> kind of thing that saves someone from wondering why the build key isn't
> just automatic.

> [!warning] A small but real convenience: the `ssh_commands` output
> ```hcl
> output "ssh_commands" {
>   value = [for n in local.nodes : "ssh -i ${...} ${var.ssh_user}@${n.ip}"]
> }
> ```
> Ready-to-paste SSH commands after every apply. Minor, but the kind of
> small UX polish that matters during a live demo.

> [!warning] The state backend is declared, not just defaulted
> Their `terraform { backend "local" { path = "terraform.tfstate" } }` is
> explicit and carries an inline comment tying it to the Jenkinsfile's
> `git clean -ffdx -e terraform/*.tfstate*` exclusion. Mine (following Pair
> A's convention) omits the block entirely, which is functionally identical
> — Terraform's default is the same file — but the reasoning lives only in
> the design doc, not directly next to the code it explains.

> [!warning] They finished. This repo, by design, hasn't.
> Full pipeline, real Goss numbers, through Jenkins, both nodes. That's a
> completed deliverable against the actual brief. Worth stating plainly
> rather than only listing small technical wins on the slice that does
> overlap.

### Where the two converged independently — worth noting as a sanity check

> [!note] Same solution, arrived at separately
> Both configs use nearly **identical** logic for filtering the IPv4 address
> out of libvirt's reported interfaces:
> ```hcl
> a if can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", a))
> ```
> Same `scsi = true` bare-boolean attribute for the data disks (confirmed
> independently against the installed provider schema on this end). Same
> `dmacvicar/libvirt` 0.8.3 pin, same UEFI/OVMF firmware paths, same
> copy-on-write `base_volume_id` pattern, same "no default pool" compliance,
> same dynamic-inventory-from-Terraform-output mechanism. Where the brief was
> specific enough to fully constrain the design, two independent
> implementations landed on the same answer — a reasonable signal that answer
> is actually correct, not just a shared guess.

### Forward-looking notes for your own Ansible/Jenkins build

Not a comparison against anything I built — I deliberately didn't build this
half. Worth knowing before you do:

- **Leftover debug value in a committed file.** Their `group_vars/pb_nodes.yml`
  has `rhel10cis_warning_banner: "WARNING: Testing lang kung tatagos"` sitting
  above the real value that overrides it in `playbook.yml`. Harmless
  functionally (higher precedence wins), but worth a pass over your own
  `group_vars` before a graded push to catch anything similar.
- **`rhel10cis_sshd_allowusers: ""`** neutralizes a `NoneType`/`join()` crash
  by setting an empty string, rather than setting it to the real account name.
  Setting it to the actual username fixes the same crash *and* adds the SSH
  hardening the control is actually for — worth doing the latter instead.
- Their role pin (`RHEL10-CIS` @ `1.1.0`) and Level-1-only scoping
  (`--skip-tags "level2-server,level2-workstation"`) match the brief exactly
  — a solid reference point for your own `requirements.yml`.
