---
tags:
  - cybersecurity
  - pki
  - certificates
  - csr
  - lifecycle
reading-order: 4
created: 2026-09-21
---

# Certificate Lifecycle & CSRs

> [!abstract] The 30-second version
> The life of a digital certificate follows six deterministic stages: **Key Generation**, **CSR Generation**, **Validation & Issuance**, **Deployment**, **Monitoring & Renewal**, and **Revocation**. The critical bridge between the server and the CA is the **CSR (Certificate Signing Request, PKCS#10)**. A CSR contains the server's public key and requested attributes, signed by the server's own private key to establish **Proof of Possession (POP)**. The private key **never leaves the host machine**; only the CSR is sent to the Certificate Authority.

---

## 1 · The 6 Stages of the Certificate Lifecycle

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ 1. Keypair Gen  │──────►│  2. Create CSR  │──────►│ 3. CA Issuance  │
│  (on Server)    │       │  (Proof of Pop) │       │ (Verifies & Signs)
└─────────────────┘       └─────────────────┘       └────────┬────────┘
                                                             │
┌─────────────────┐       ┌─────────────────┐                │
│  6. Revocation  │◄──────│ 5. Monitor/Renew│◄───────────────┘
│ (if compromised)│       │  (Automated)    │       4. Deployment
└─────────────────┘       └─────────────────┘     (Nginx + Reload)
```

### Stage 1: Keypair Generation
- Generated on the target host (e.g. Proxy VM) using high-entropy random number sources (`/dev/urandom`).
- **Cryptographic choice**:
  - RSA 2048 or 4096-bit.
  - ECDSA (`prime256v1` / P-256 or `secp384r1` / P-384).
- **Security Rule**: File permissions must be locked immediately (`chmod 400` or `chmod 600`, owned by `root:root`).

### Stage 2: Certificate Signing Request (CSR) Creation
- Formatted as **PKCS#10** (RFC 2986).
- Bundles the public key, the Subject DN, and requested extensions (critically: `subjectAltName = DNS:labapp.com`).

### Stage 3: Verification & Signing
- The CA reviews the request. In enterprise internal PKI, this involves validating the identity against inventory/CMDB. In public PKI, this involves ACME HTTP-01/DNS-01 domain challenge verification.
- **Enterprise Extension Handling**:
  - The CA enforces security profiles (`basicConstraints = critical, CA:FALSE`, `extendedKeyUsage = serverAuth`).
  - **CSR Extension Preservation**: By default, OpenSSL ignores extensions requested in the CSR. Production CAs configure `copy_extensions = copy` to preserve client-requested Subject Alternative Names while strictly applying CA policy constraints.
- The CA generates the certificate and cryptographically signs it with the CA's private key.

### Stage 4: Deployment & Chain Assembly
- The issued certificate is combined with the intermediate CA into `fullchain.pem`.
- Placed on the web server (`/etc/pki/tls/certs/` or `/etc/nginx/ssl/`).
- Web server config updated and reloaded with zero downtime (`nginx -s reload` or `systemctl reload nginx`).

### Stage 5: Monitoring & Renewal
- Automated monitoring tools check expiration dates.
- **Validity Standards (September 2026)**:
  - CA/Browser Forum Baseline Requirements cap public TLS certificates at **398 days** (approx. 13 months).
  - Modern industry standards (Google/Apple Root Programs) are transitioning toward shorter 90-day lifespans to enforce automated lifecycle management. Internal enterprise PKIs typically issue 1-year (`default_days = 397`) certificates.

### Stage 6: Revocation / Retirement
- Triggered if private key material is compromised, server is decommissioned, or domain ownership changes.

---

## 2 · Anatomy of a Certificate Signing Request (CSR)

What actually lives inside a `.csr` file? You can inspect any CSR with:
`openssl req -in server.csr -text -noout`

A standard PKCS#10 CSR contains three core components:

```
Certification Request Info:
├── Version: 0 (v1)
├── Subject: CN = labapp.com, O = AirNav DAS Lab, C = PH
├── Subject Public Key Info:
│   ├── Public Key Algorithm: rsaEncryption (or id-ecPublicKey)
│   └── Public Key Data: (2048 or 4096 bits)
└── Attributes / Requested Extensions:
    ├── basicConstraints: CA:FALSE
    ├── keyUsage: digitalSignature, keyEncipherment
    ├── extendedKeyUsage: serverAuth
    └── subjectAltName:
        ├── DNS:labapp.com
        ├── DNS:*.labapp.com
        └── IP:192.168.100.20
Signature Algorithm: sha256WithRSAEncryption
Signature Value: (Signed by the applicant's private key!)
```

### The Concept of Proof of Possession (POP)
Notice that the CSR has its own **Signature Algorithm** and **Signature Value** at the bottom.
- **Who signed this?** Not the CA! The **applicant** signed it using their own newly created private key.
- **Why?** This prevents an attacker from taking somebody else's public key, wrapping it in a CSR with the attacker's own name, and submitting it to a CA. The signature proves mathematically that whoever created the CSR actually holds the private key corresponding to the public key inside the request.

---

## 3 · The Golden Rule: Private Keys Never Leave the Host

> [!danger] Cardinal Rule of Asymmetric Security
> **Your private key is generated on the host where it will be used, and it NEVER leaves that host.**

```
CORRECT PRODUCTION WORKFLOW:
Target Host (Proxy VM)                  CA Server (Root / Intermediate)
  │                                                    │
  ├── 1. Generate Private Key (stays here!)            │
  ├── 2. Generate CSR containing Public Key            │
  │                                                    │
  │────────── 3. Send server.csr (Public) ────────────►│
  │                                                    ├── 4. Signs CSR with CA Key
  │                                                    ├── 5. Produces server.crt
  │                                                    │
  │◄───────── 6. Returns server.crt + ca-chain ────────│
  │                                                    │
  ├── 7. Combines into fullchain.pem                   │
  └── 8. Nginx serves HTTPS                            │
```

If an external party, online tool ("free SSL generator website"), or vendor asks you to email them your private key or generates the private key on their servers for you to download:
**That private key is fundamentally compromised and must not be used.**

