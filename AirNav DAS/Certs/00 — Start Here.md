---
tags:
  - cybersecurity
  - pki
  - certificates
  - cryptography
  - networking
  - high-availability
  - moc
aliases:
  - Certs MOC
  - PKI Notes Index
reading-order: 0
created: 2026-09-21
---

# Start Here — PKI, Digital Certificates, Security & High Availability

> [!abstract] The 30-second version
> **PKI (Public Key Infrastructure)** is the governance, software, and cryptographic framework that binds digital identities (like domain names or server hostnames) to cryptographic public keys via **digital certificates (X.509)** issued by trusted **Certificate Authorities (CAs)**. Without PKI, encrypted connections are vulnerable to **Man-In-The-Middle (MITM)** attacks because anyone can generate an encryption key; PKI answers the fundamental question: *"Can I mathematically prove this public key genuinely belongs to `labapp.com` and not an impersonator?"*
>
> This folder covers the cryptographic theory, X.509 v3 anatomy, 2-tier enterprise CA architectures (Root + Intermediate), certificate lifecycle management, a complete hands-on production deployment for securing our 3-tier Nginx proxy VM with HTTPS/TLS and DNS resolution, and a stretch module on **Linux High Availability (HA) and Floating Virtual IPs (VIPs)**.

---

## What this folder is

A rigorous, production-focused engineering study track and implementation guide. It builds directly upon the 3-tier Proxmox lab built in the System Discovery Task (Proxy VM `192.168.100.20`, App VM `10.10.10.11`, DB VM `10.10.10.12`).

Every technical fact, parameter, and configuration directive here has been verified against **primary authoritative sources**:
- **IETF RFCs**: RFC 5280 (X.509 PKI Profile & CRL), RFC 8446 (TLS 1.3), RFC 5246 (TLS 1.2), RFC 2818 & RFC 6125 (Subject Alternative Name matching & CN deprecation), RFC 3768 / RFC 5798 (VRRP).
- **NIST Special Publications**: NIST SP 800-57 Part 1 Rev. 5 (*Recommendation for Key Management*), NIST SP 800-52 Rev. 2 (*Guidelines for the Selection, Configuration, and Use of TLS*).
- **CA/Browser Forum**: *Baseline Requirements for the Issuance and Management of Publicly-Trusted TLS Server Certificates*.
- **Vendor Technical Documentation**: OpenSSL 3.x Official Documentation, Red Hat Enterprise Linux 9 Security Hardening & System-Wide Crypto Policies, Keepalived Architecture Documentation.

---

## The notes

| # | Note | What it answers |
|---|---|---|
| 01 | [[01 — Cryptography & PKI Foundations]] | Symmetric vs asymmetric crypto, hash functions, digital signatures, key distribution problem, why PKI exists |
| 02 | [[02 — X.509 Certificates & Anatomy]] | X.509 v3 structure, ASN.1/DER vs PEM, extensions (`basicConstraints`, `keyUsage`, `extKeyUsage`, `SAN`), why CN is dead |
| 03 | [[03 — Certificate Authorities & Trust Hierarchies]] | 1-tier vs 2-tier vs 3-tier PKI, Root vs Intermediate CAs, offline root principles, path validation algorithm, revocation (CRL/OCSP), OS/browser trust stores |
| 04 | [[04 — Certificate Lifecycle & CSRs]] | Key generation, CSR structure, proof of possession, issuance, validation, automated vs manual renewal |
| 05 | [[05 — Hands-On 2-Tier CA & Nginx TLS Implementation]] | Conceptual runbook: 2-Tier architecture, extensions, config mechanics |
| Task | [[TASK — 2-Tier PKI & HTTPS Setup Guide]] | **The Hands-On Execution Guide**: Exact host prompts, copy-paste blocks, verify steps |
| 06 | [[06 — Linux High Availability & Floating IPs]] | Stretch Goal: High Availability principles, Active/Passive vs Active/Active, VRRP protocol, Floating Virtual IP (VIP) allocation, Gratuitous ARP, Keepalived setup |

---

## The core mental models

### 1. The Trust Hierarchy (2-Tier PKI)

```
[ Offline Root CA ] (Self-Signed, 10-20 yr validity, locked down)
       │
       │ signs (issues)
       ▼
[ Online Intermediate CA ] (Signed by Root, 3-5 yr validity, active issuer)
       │
       │ signs (issues)
       ▼
[ End-Entity / Leaf Cert ] (Signed by Intermediate, max 398 days, e.g. labapp.com)
```

### 2. Request Flow with TLS & DNS

```
Laptop Browser (Client)
   │
   │ 1. Resolves labapp.com -> 192.168.100.20 via /etc/hosts
   │ 2. Initiates TLS Handshake on Port 443 (TCP SYN -> SYN/ACK -> ClientHello)
   ▼
[ Proxy VM: Nginx (192.168.100.20:443) ]
   │
   │ 3. Presents Certificate Chain (Server Cert + Intermediate CA)
   │ 4. Laptop verifies chain back to locally trusted Root CA in its trust store
   │ 5. Session keys negotiated (ECDHE); encrypted HTTP/2 requests flow
   │ 6. proxy_pass forwards unencrypted/internal traffic to App VM
   ▼
[ App VM: Flask (10.10.10.11:5000) ]
   │
   │ 7. Internal SQL query
   ▼
[ DB VM: MariaDB (10.10.10.12:3306) ]
```

---

## Suggested Reading Order

1. Read **01 through 04** in sequence to build a rock-solid mental model of *why* certificates work the way they do and avoid the common pitfalls (such as omitting SANs or failing to concatenate intermediate certificates into a full chain).
2. Execute **05** step-by-step in your lab environment to generate the CA hierarchy, issue the TLS certificate for `labapp.com`, configure Nginx on AlmaLinux 9, and verify a green lock in your browser.
3. Study **06** to understand how production enterprise systems ensure zero-downtime using redundant proxies and floating virtual IPs.

