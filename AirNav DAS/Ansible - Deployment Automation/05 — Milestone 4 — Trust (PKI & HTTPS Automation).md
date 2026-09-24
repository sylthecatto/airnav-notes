---
tags:
  - ansible
  - milestone-4
  - pki
  - tls
  - certificates
  - openssl
  - https
reading-order: 5
created: 2026-09-24
updated: 2026-09-24
---

# Milestone 4: Trust (Internal PKI & HTTPS Automation)

> [!abstract] Milestone 4 Objective
> Automate an **internal Public Key Infrastructure (PKI)** for the System Discovery Platform. Generate an internal **Root Certificate Authority (CA)** on the Control Node, automate the generation of a private key and Certificate Signing Request (CSR) with modern **Subject Alternative Names (SANs)**, issue a signed server certificate, deploy the certificate and private key securely to NGINX (`proxy01`), configure **HTTPS with HTTP-to-HTTPS redirection**, and gather cryptographic verification evidence.

> [!info] Official Standards & Primary Sources
> - **IETF RFC 5280**: [Internet X.509 Public Key Infrastructure Certificate and CRL Profile](https://datatracker.ietf.org/doc/html/rfc5280)
> - **CA/Browser Forum Baseline Requirements (2026)**: [cabforum.org/baseline-requirements/](https://cabforum.org/baseline-requirements/) (Mandatory Subject Alternative Name enforcement)
> - **OpenSSL 3.0+ Manual**: [openssl.org/docs/man3.0/](https://www.openssl.org/docs/man3.0/)
> - **Mozilla Server Side TLS Guidelines**: [wiki.mozilla.org/Security/Server_Side_TLS](https://wiki.mozilla.org/Security/Server_Side_TLS)
> - **NGINX SSL/TLS Configuration**: [nginx.org/en/docs/http/configuring_https_servers.html](https://nginx.org/en/docs/http/configuring_https_servers.html)

---

## 1 · Automated PKI Architecture & Key Separation

To adhere to enterprise security standards, the **Root CA private key must never leave the Control Node**. The Control Node acts as the internal Certificate Authority, signing requests and distributing only the public certificates and target server keys.

```mermaid
sequenceDiagram
    autonumber
    participant Control as Ansible Control Node (CA Authority)
    participant NGINX as NGINX Reverse Proxy (proxy01)
    participant Client as Client Host (VM3)

    Note over Control: Step 1: Automate Root CA<br/>Generate root-ca.key (4096-bit)<br/>Generate self-signed root-ca.crt (10-year validity)

    Note over Control: Step 2: Automate Server Cert<br/>Generate server.key (2048-bit)<br/>Generate CSR with SAN (DNS:labapp.com, IP:192.168.100.20)<br/>Sign CSR with Root CA -> server.crt

    Control->>NGINX: Deploy server.crt & server.key (chmod 0600)
    Note over NGINX: Update NGINX config:<br/>listen 443 ssl http2;<br/>HTTP 80 -> 301 Redirect to HTTPS

    Control->>Client: Deploy public root-ca.crt to /etc/pki/ca-trust/
    Note over Client: Ready for trusted HTTPS validation
```

---

## 2 · Step-by-Step Hands-on Implementation

We will implement this in a dedicated role: `roles/pki_trust`.

### Step 2.1 · Scaffold the `pki_trust` Role Directory
From `~/ansible-platform`:

```bash
mkdir -p roles/pki_trust/{defaults,tasks,templates,handlers}
```

---

### Step 2.2 · Define Role Defaults (`roles/pki_trust/defaults/main.yml`)
Create `roles/pki_trust/defaults/main.yml`:

```yaml
---
# roles/pki_trust/defaults/main.yml — Internal PKI Parameters

# CA Metadata:
pki_local_ca_dir: "{{ playbook_dir }}/pki_artifacts"
root_ca_key_filename: "root-ca.key"
root_ca_crt_filename: "root-ca.crt"
root_ca_subject: "/C=PH/ST=NCR/L=Pasay/O=AirNav FCO Engineering/OU=DAS Lab/CN=AirNav DAS Root CA"

# Server Certificate Parameters:
server_fqdn: "labapp.com"
proxy_ip_address: "192.168.100.20"
server_subject: "/C=PH/ST=NCR/L=Pasay/O=AirNav FCO Engineering/OU=DAS Lab/CN={{ server_fqdn }}"

# Target Node Deployment Paths:
remote_cert_dir: "/etc/pki/nginx"
remote_cert_file: "{{ remote_cert_dir }}/server.crt"
remote_key_file: "{{ remote_cert_dir }}/server.key"
remote_ca_file: "{{ remote_cert_dir }}/root-ca.crt"
```

---

### Step 2.3 · Build OpenSSL Extension Template (`roles/pki_trust/templates/server_ext.cnf.j2`)
In RFC 5280 and modern 2026 TLS, browsers and tools like `curl` strictly enforce **Subject Alternative Names (SAN)** and reject certificates that rely solely on Common Name (CN).

Create `roles/pki_trust/templates/server_ext.cnf.j2`:

```ini
# OpenSSL v3 extension config for {{ server_fqdn }}
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

# Modern SAN definition:
subjectAltName = @alt_names

[alt_names]
DNS.1 = {{ server_fqdn }}
DNS.2 = *.{{ server_fqdn }}
IP.1 = {{ proxy_ip_address }}
IP.2 = 127.0.0.1
```

---

### Step 2.4 · Define Role Tasks (`roles/pki_trust/tasks/main.yml`)
Create `roles/pki_trust/tasks/main.yml`:

```yaml
---
# roles/pki_trust/tasks/main.yml — Automated PKI Lifecycle

# =========================================================================
# 1. CONTROL NODE TASKS (CA Generation & Certificate Signing)
# =========================================================================
- name: Ensure local PKI artifact directory exists on Control Node
  ansible.builtin.file:
    path: "{{ pki_local_ca_dir }}"
    state: directory
    mode: '0700'
  delegate_to: localhost
  run_once: true
  tags: [pki, ca]

- name: Generate Root CA Private Key (4096-bit RSA)
  ansible.builtin.command: >
    openssl genrsa -out {{ pki_local_ca_dir }}/{{ root_ca_key_filename }} 4096
  args:
    creates: "{{ pki_local_ca_dir }}/{{ root_ca_key_filename }}"
  delegate_to: localhost
  run_once: true
  tags: [pki, ca]

- name: Generate Self-Signed Root CA Certificate (10-Year Validity)
  ansible.builtin.command: >
    openssl req -x509 -new -nodes
    -key {{ pki_local_ca_dir }}/{{ root_ca_key_filename }}
    -sha256 -days 3650
    -out {{ pki_local_ca_dir }}/{{ root_ca_crt_filename }}
    -subj "{{ root_ca_subject }}"
  args:
    creates: "{{ pki_local_ca_dir }}/{{ root_ca_crt_filename }}"
  delegate_to: localhost
  run_once: true
  tags: [pki, ca]

- name: Generate Server Private Key for NGINX (2048-bit RSA)
  ansible.builtin.command: >
    openssl genrsa -out {{ pki_local_ca_dir }}/server.key 2048
  args:
    creates: "{{ pki_local_ca_dir }}/server.key"
  delegate_to: localhost
  run_once: true
  tags: [pki, server_cert]

- name: Generate Server Certificate Signing Request (CSR)
  ansible.builtin.command: >
    openssl req -new
    -key {{ pki_local_ca_dir }}/server.key
    -out {{ pki_local_ca_dir }}/server.csr
    -subj "{{ server_subject }}"
  args:
    creates: "{{ pki_local_ca_dir }}/server.csr"
  delegate_to: localhost
  run_once: true
  tags: [pki, server_cert]

- name: Render OpenSSL SAN extension configuration
  ansible.builtin.template:
    src: server_ext.cnf.j2
    dest: "{{ pki_local_ca_dir }}/server_ext.cnf"
    mode: '0600'
  delegate_to: localhost
  run_once: true
  tags: [pki, server_cert]

- name: Sign Server CSR using Root CA with modern SAN extensions
  ansible.builtin.command: >
    openssl x509 -req
    -in {{ pki_local_ca_dir }}/server.csr
    -CA {{ pki_local_ca_dir }}/{{ root_ca_crt_filename }}
    -CAkey {{ pki_local_ca_dir }}/{{ root_ca_key_filename }}
    -CAcreateserial
    -out {{ pki_local_ca_dir }}/server.crt
    -days 365
    -sha256
    -extfile {{ pki_local_ca_dir }}/server_ext.cnf
  args:
    creates: "{{ pki_local_ca_dir }}/server.crt"
  delegate_to: localhost
  run_once: true
  tags: [pki, server_cert]

# =========================================================================
# 2. TARGET PROXY NODE TASKS (Deploy Certs & Hardened Permissions)
# =========================================================================
- name: Ensure target certificate directory exists on NGINX host
  ansible.builtin.file:
    path: "{{ remote_cert_dir }}"
    state: directory
    owner: root
    group: root
    mode: '0755'
  tags: [deploy, nginx]

- name: Deploy Server Certificate to NGINX
  ansible.builtin.copy:
    src: "{{ pki_local_ca_dir }}/server.crt"
    dest: "{{ remote_cert_file }}"
    owner: root
    group: root
    mode: '0644'
  notify: Reload NGINX
  tags: [deploy, nginx]

- name: Deploy Server Private Key with strict 0600 permissions
  ansible.builtin.copy:
    src: "{{ pki_local_ca_dir }}/server.key"
    dest: "{{ remote_key_file }}"
    owner: root
    group: root
    mode: '0600'
  notify: Reload NGINX
  tags: [deploy, nginx]

- name: Deploy Root CA public certificate to NGINX node
  ansible.builtin.copy:
    src: "{{ pki_local_ca_dir }}/{{ root_ca_crt_filename }}"
    dest: "{{ remote_ca_file }}"
    owner: root
    group: root
    mode: '0644'
  tags: [deploy, nginx]

# =========================================================================
# 3. VERIFICATION TASKS (Cryptographic Proof)
# =========================================================================
- name: Verify server certificate Subject Alternative Names (SAN)
  ansible.builtin.command: >
    openssl x509 -in {{ remote_cert_file }} -text -noout
  register: cert_inspection
  changed_when: false
  tags: [verification]

- name: Assert SAN contains required FQDN and IP
  ansible.builtin.assert:
    that:
      - "'DNS:labapp.com' in cert_inspection.stdout"
      - "'IP Address:192.168.100.20' in cert_inspection.stdout"
    fail_msg: "SECURITY FAILURE: Server certificate missing required SAN extensions!"
    success_msg: "VERIFIED: Server certificate SAN correctly matches FQDN and IP."
  tags: [verification]

- name: Verify certificate chain of trust against Root CA
  ansible.builtin.command: >
    openssl verify -CAfile {{ remote_ca_file }} {{ remote_cert_file }}
  register: chain_verify
  changed_when: false
  failed_when: "'OK' not in chain_verify.stdout"
  tags: [verification]

- name: Display cryptographic verification evidence
  ansible.builtin.debug:
    msg: "CHAIN VERIFICATION RESULT: {{ chain_verify.stdout }}"
  tags: [verification]
```

---

### Step 2.5 · Update NGINX to Enforce HTTPS (`roles/nginx_proxy/templates/reverse_proxy.conf.j2`)
Now update the NGINX configuration template from Milestone 3 to terminate HTTPS on port 443 and redirect all port 80 traffic:

```nginx
# /etc/nginx/conf.d/reverse_proxy.conf
# Managed by Ansible — roles/nginx_proxy + roles/pki_trust

upstream backend_cluster {
    server {{ backend_host }}:{{ backend_port }};
    keepalive 32;
}

# 1. HTTP Server Block — Permanent 301 Redirect to HTTPS
server {
    listen {{ proxy_http_port }};
    listen [::]:{{ proxy_http_port }};
    server_name {{ fqdn }};

    location / {
        return 301 https://$host$request_uri;
    }
}

# 2. HTTPS Server Block — TLS Termination & Reverse Proxy
server {
    listen {{ proxy_https_port }} ssl http2;
    listen [::]:{{ proxy_https_port }} ssl http2;
    server_name {{ fqdn }};

    # Certificate & Private Key Paths:
    ssl_certificate {{ remote_cert_file }};
    ssl_certificate_key {{ remote_key_file }};

    # Modern TLS Security Parameters (Mozilla Intermediate Standard):
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5:!3DES;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Logging:
    access_log /var/log/nginx/https_access.log combined;
    error_log /var/log/nginx/https_error.log warn;

    location / {
        proxy_pass http://backend_cluster;

        # Standard Headers:
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

---

### Step 2.6 · Add Firewalld Port 443 & Link in `site.yml`
In `roles/nginx_proxy/tasks/main.yml`, ensure port `443/tcp` is open in firewalld:

```yaml
- name: Configure Firewalld to permit incoming HTTPS traffic
  ansible.posix.firewalld:
    port: "{{ proxy_https_port }}/tcp"
    permanent: true
    state: enabled
    immediate: true
  tags: [security, firewall]
```

In `site.yml`, call the `pki_trust` role on the proxy:

```yaml
- name: "Phase 3: Deploy NGINX Reverse Proxy Gateway with HTTPS"
  hosts: proxy
  become: true
  roles:
    - pki_trust
    - nginx_proxy
```

---

## 3 · Verification & Evidence Collection

```bash
# 1. Execute the PKI automation and HTTPS deployment:
ansible-playbook site.yml --tags pki,server_cert,deploy,nginx

# 2. Inspect the generated certificate on proxy01:
ssh root@192.168.100.20 "openssl x509 -in /etc/pki/nginx/server.crt -text -noout | grep -A 4 'Subject Alternative Name'"
# Expected Output:
# X509v3 Subject Alternative Name:
#     DNS:labapp.com, DNS:*.labapp.com, IP Address:192.168.100.20, IP Address:127.0.0.1

# 3. Test HTTP to HTTPS redirection:
ssh root@192.168.100.20 "curl -I -H 'Host: labapp.com' http://127.0.0.1"
# Expected Output:
# HTTP/1.1 301 Moved Permanently
# Location: https://labapp.com/

# 4. Test HTTPS connection (specifying Root CA for trust):
ssh root@192.168.100.20 "curl -v --cacert /etc/pki/nginx/root-ca.crt https://127.0.0.1 --resolve labapp.com:443:127.0.0.1"
# Expected Output:
# * TLSv1.3 (OUT), TLS handshake, Client hello
# * Server certificate: CN=labapp.com
# * SSL certificate verify ok.
# < HTTP/2 200
```

---

## 4 · Technical Defense Q&A for Trainers

> [!tip] Questions Sir Jayrose Might Ask
> **Q1: Why did you generate the Root CA private key on the Control Node instead of on NGINX?**
> *Answer:* Security segregation. A Certificate Authority must never share trust boundaries with public-facing application servers. If the NGINX server is compromised, an attacker would steal the Root CA key and be able to issue trusted certificates for any domain in our organization! Keeping the Root CA on the control node adheres to the principle of least privilege.
>
> **Q2: Why did we use `creates:` on our `ansible.builtin.command` tasks?**
> *Answer:* Raw command tasks are inherently non-idempotent: running `openssl genrsa` every time would generate a new key on every single playbook run, invalidating all previously signed certificates and breaking services. The `creates:` clause instructs Ansible: "If this file already exists on disk, skip this task (`changed: false`)", restoring idempotency!
>
> **Q3: Why is `listen 443 ssl http2;` used instead of `http2 on;`?**
> *Answer:* On AlmaLinux 9 / RHEL 9, NGINX is currently version 1.20. The newer `http2 on;` directive was only introduced in NGINX 1.25.1+. Using `listen 443 ssl http2;` is the officially supported, stable syntax for enterprise Linux 9 distributions.
