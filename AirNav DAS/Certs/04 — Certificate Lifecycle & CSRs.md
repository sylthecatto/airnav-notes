---
tags:
  - cybersecurity
  - pki
  - certificates
  - csr
  - lifecycle
reading-order: 4
created: 2026-09-21
aliases:
  - Certificate Lifecycle
  - CSR Guide
---

# Certificate Lifecycle & CSRs

> [!abstract] The 30-Second Summary
> The lifecycle of a digital certificate follows six deterministic phases: **Key Generation**, **CSR Generation**, **Validation & Issuance**, **Deployment**, **Monitoring & Renewal**, and **Revocation**. The critical contract between the server and the CA is the **CSR (Certificate Signing Request, [RFC 2986 / PKCS#10](https://datatracker.ietf.org/doc/html/rfc2986))**. A CSR bundles the applicant's public key, identity attributes, and requested extensions (critically: SANs), signed by the applicant's own private key to establish **Proof of Possession (POP)**. The private key **never leaves the host machine**; only the CSR is transmitted to the Certificate Authority.

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
- Generated on the target host (Proxy VM) using cryptographically secure pseudorandom number generators (`/dev/urandom`).
- **Algorithm Choice** ([NIST SP 800-57](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)): RSA 2048/4096-bit or ECDSA (P-256 / `prime256v1`).
- **Filesystem Security**: Strict permission lockdown immediately upon creation (`chmod 600`, owned by `root:root`).

### Stage 2: Certificate Signing Request (CSR) Creation
- Formatted as **PKCS#10** ([RFC 2986](https://datatracker.ietf.org/doc/html/rfc2986)).
- Bundles the public key, the Subject DN, and requested extensions (critically: `subjectAltName = DNS:labapp.com, IP:192.168.100.20`).

### Stage 3: Verification & Signing
- The CA reviews the request. In enterprise internal PKI, this involves validating the identity against infrastructure inventory. In public PKI, this involves ACME HTTP-01/DNS-01 domain challenge verification.
- **Enterprise Extension Handling**:
  - The CA enforces security profiles (`basicConstraints = critical, CA:FALSE`, `extendedKeyUsage = serverAuth`).
  - **CSR Extension Preservation**: By default, OpenSSL ignores extensions requested in the CSR. Production CAs configure `copy_extensions = copy` in their configuration to preserve client-requested Subject Alternative Names while strictly applying CA policy constraints.
- The CA signs the bundle with the CA's private signing key.

### Stage 4: Deployment & Chain Assembly
- The issued certificate is combined with the Intermediate CA into `fullchain.pem`.
- Placed on the web server (`/etc/nginx/ssl/fullchain.pem` and `labapp.key`).
- Web server configuration reloaded with zero downtime (`systemctl reload nginx`).

### Stage 5: Monitoring & Renewal
- Automated monitoring tools alert on approaching expiration dates.
- **Validity Standards (September 2026)**:
  - CA/Browser Forum Baseline Requirements cap public TLS certificates at **398 days** (approx. 13 months).
  - Modern industry standards (Google/Apple Root Programs) are actively shifting towards automated 90-day lifespans. Internal enterprise PKIs typically issue 1-year (`default_days = 397`) certificates.

### Stage 6: Revocation / Retirement
- Triggered if private key material is compromised, the server is decommissioned, or domain routing changes.

---

## 2 · Anatomy of a Certificate Signing Request (CSR)

When you inspect a live CSR (`openssl req -in labapp.csr -text -noout`), OpenSSL decodes the PKCS#10 structure:

```text
Certificate Request:
    Data:
        Version: 1 (0x0)
        Subject: C=PH, O=AirNav DAS Lab, CN=labapp.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus: 00:bc:dd:b6:a9:fa:...
                Exponent: 65537 (0x10001)
        Attributes:
            Requested Extensions:
                X509v3 Subject Alternative Name: 
                    DNS:labapp.com, DNS:*.labapp.com, IP Address:192.168.100.20, IP Address:10.10.10.10
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value: 55:4f:db:71:b6:32:... (Self-signed by applicant!)
```

### The Three Functional Blocks of a CSR:
1. **Certification Request Info**:
   - `Subject`: Identity attributes. Under modern [CAB Forum BR §7.1.4.2.2](https://cabforum.org/working-groups/server-certificate/baseline-requirements/), `CN` is deprecated and may be omitted or match one SAN.
   - `Subject Public Key Info`: The server's 2048-bit RSA public key.
2. **Attributes / Requested Extensions**:
   - Holds the `subjectAltName` block (`DNS:labapp.com`, `IP:192.168.100.20`). The applicant asks the CA to include these identifiers.
3. **Signature Algorithm & Signature Value (Proof of Possession)**:
   - **Who signed this?** Not the CA! The **applicant** signed the CSR using their own newly created `labapp.key` private key.
   - **Why?** This provides mathematical **Proof of Possession (POP)**. It prevents an attacker from taking somebody else's public key, wrapping it in a CSR with the attacker's own name, and submitting it to a CA. The signature proves mathematically that whoever created the CSR actually holds the private key corresponding to the public key inside the request.

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
  │                                                    ├── 4. Verifies CSR Signature (POP)
  │                                                    ├── 5. Signs CSR with CA Key
  │                                                    ├── 6. Produces server.crt
  │                                                    │
  │◄───────── 7. Returns server.crt + ca-chain ────────│
  │                                                    │
  ├── 8. Combines into fullchain.pem                   │
  └── 9. Nginx serves HTTPS                            │
```

---

## Primary Sources & Standards

- **[IETF RFC 2986](https://datatracker.ietf.org/doc/html/rfc2986)**: *PKCS #10: Certification Request Syntax Specification Version 1.7*.
- **[IETF RFC 5280 §4.2](https://datatracker.ietf.org/doc/html/rfc5280#section-4.2)**: *Standard Certificate Extensions and Processing Rules*.
- **[CA/Browser Forum Baseline Requirements §7.1.4](https://cabforum.org/working-groups/server-certificate/baseline-requirements/)**: *Certificate Content and Policy Requirements*.
