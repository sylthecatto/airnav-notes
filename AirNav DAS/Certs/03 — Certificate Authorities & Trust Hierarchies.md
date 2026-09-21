---
tags:
  - cybersecurity
  - pki
  - certificates
  - trust-chains
  - security
reading-order: 3
created: 2026-09-21
---

# Certificate Authorities & Trust Hierarchies

> [!abstract] The 30-second version
> A **Certificate Authority (CA)** is a trusted entity that cryptographically signs identity assertions. Production PKI architectures strictly separate duties using a **2-Tier Hierarchy**: an **Offline Root CA** (self-signed, extremely long-lived, kept powered down in cold storage) that signs an **Online Intermediate CA** (short-lived, actively signs daily server certificates). When a client connects to a server, the server transmits a **Certificate Chain** (`fullchain.pem`). The client mathematically walks up this chain until it hits a pre-installed **Trust Anchor** in its local Operating System or Browser Trust Store. If an intermediate key leaks, only that branch is revoked; the Root CA remains intact.

---

## 1 · PKI Architecture: 1-Tier vs. 2-Tier vs. 3-Tier

```
1-TIER (Lab / Fragile)             2-TIER (Enterprise Standard)          3-TIER (Global / Government)
[ Root CA ] (Online)                [ Offline Root CA ]                   [ Offline Root CA ]
     │                                       │                                     │
     │ signs leaf directly                   │ signs Intermediate                  │ signs Policy CA
     ▼                                       ▼                                     ▼
[ Web Server Cert ]                 [ Intermediate CA ] (Online)          [ Policy CA ] (Offline)
                                             │                                     │
                                             │ signs leaf                          │ signs Issuing CAs
                                             ▼                                     ▼
                                    [ Web Server Cert ]                   [ Issuing CAs ] (Online)
                                                                                   │
                                                                                   ▼
                                                                          [ Web Server Cert ]
```

### The Fatal Flaw of a 1-Tier PKI
In a naive 1-tier setup, a single self-signed Root CA directly signs all web server certificates.
- **The Disaster Scenario**: The private key of the CA must reside on an active, network-connected computer (or even the web server itself). If that server is compromised, the **Root Private Key is stolen**.
- **The Consequence**: Every single certificate ever signed by that CA is now suspect. To fix this, you must revoke the Root CA and manually update the Trust Stores on **every single employee laptop, server, mobile device, and client machine in the entire organization**.
- **Verdict**: Strictly forbidden in production environments.

### Why the 2-Tier Architecture is the Enterprise Standard
A 2-Tier PKI decouples the **Trust Anchor** from the **Operational Signing Engine**:
1. **The Root CA remains OFFLINE**:
   - The Root CA machine is kept disconnected from any network (air-gapped or powered off).
   - Its private key is encrypted with a strong passphrase.
   - It is booted only once every few years for 15 minutes to issue a new Intermediate CA or update a Root CRL.
   - Validity: Typically **10 to 20 years**.
2. **The Intermediate CA handles DAILY OPERATIONS**:
   - Resides on a secure, network-accessible server.
   - Handles automated CSR signing, day-to-day server renewals.
   - Validity: Typically **2 to 5 years**.
3. **Failure Isolation**:
   - If an Intermediate CA server is breached, the administrator boots the Offline Root CA, issues a revocation for that specific Intermediate CA, and signs a new Intermediate CA.
   - **Crucially: No client endpoints need their Trust Stores touched.** The clients still trust the Root CA; they simply reject the revoked intermediate and accept the newly issued one.

---

## 2 · The Chain of Trust & Path Validation (RFC 5280 §6)

When a web browser connects to `https://labapp.com`, the server presents its certificate chain. The browser's TLS engine executes the **RFC 5280 Path Validation Algorithm**:

```
Path Validation Flow:
┌────────────────────────────────────────────────────────┐
│ Client Local Trust Store                               │
│ [ Root CA Certificate ] <─── Trusted Anchor            │
└───────────────▲────────────────────────────────────────┘
                │ Verified against Root Public Key
┌───────────────┴────────────────────────────────────────┐
│ Presented by Nginx Server (fullchain.pem)              │
│                                                        │
│ [ Intermediate CA Certificate ]                        │
│   Issuer: CN = Enterprise Root CA                      │
│   Subject: CN = Enterprise Intermediate CA             │
│   basicConstraints: CA:TRUE, pathlen:0                 │
│                                                        │
│ [ Server Certificate (Leaf / End-Entity) ]             │
│   Issuer: CN = Enterprise Intermediate CA              │
│   Subject: CN = labapp.com                             │
│   SAN: DNS:labapp.com, IP:192.168.100.20               │
│   basicConstraints: CA:FALSE                           │
└────────────────────────────────────────────────────────┘
```

### The Step-by-Step Verification Checklist:
1. **Name Matching**: Does `labapp.com` in the browser's address bar match an entry in the Leaf certificate's `subjectAltName`?
2. **Date Validity**: For *every* certificate in the chain, is current time between `Not Before` and `Not After`?
3. **Chain Assembly**: Does the Leaf certificate's `AuthorityKeyIdentifier` match the Intermediate CA's `SubjectKeyIdentifier`? Does the Intermediate's AKI match the Root's SKI?
4. **Signature Verification**:
   - Decrypt Leaf's signature using the Intermediate CA's public key; verify Leaf's SHA-256 hash.
   - Decrypt Intermediate's signature using the Root CA's public key; verify Intermediate's SHA-256 hash.
5. **Extension Constraints**:
   - Ensure the Intermediate has `basicConstraints = CA:TRUE`.
   - Ensure the Leaf has `basicConstraints = CA:FALSE`.
   - Ensure path length limits (`pathlen`) are not exceeded.
6. **Trust Anchor Termination**: Is the Root CA certificate found inside the client's local, trusted Root Certificate Store?

> [!important] Crucial Rule for `fullchain.pem`
> In Nginx's `ssl_certificate` file, you **MUST bundle**:
> ```
> -----BEGIN CERTIFICATE-----
> (Server / Leaf Certificate)
> -----END CERTIFICATE-----
> -----BEGIN CERTIFICATE-----
> (Intermediate CA Certificate)
> -----END CERTIFICATE-----
> ```
> **Do NOT append the Root Certificate to `fullchain.pem`!**
> The Root Certificate must already be present in the client's local trust store. Sending the Root in the TLS handshake wastes bandwidth and provides zero cryptographic trust (a client cannot establish trust from an entity it does not already trust).

---

## 3 · Certificate Revocation: CRL vs. OCSP

What happens when a private key is stolen *before* its certificate reaches its expiration date? The certificate must be **revoked**.

### 1. CRL (Certificate Revocation List, RFC 5280)
- A timestamped, digitally signed blacklist file published by the CA containing serial numbers of revoked certificates.
- **How it works**: Client downloads the `.crl` file over HTTP/LDAP and checks if the server's serial number is listed.
- **Drawbacks**:
  - **Latency**: Download delays before the page can load.
  - **Scalability**: For public CAs, CRL files can grow to tens of megabytes.
  - **Soft-fail flaw**: Most browsers silently bypass CRL checks if the CRL server times out.

### 2. OCSP (Online Certificate Status Protocol, RFC 6960)
- An interactive HTTP query: The client sends a request containing the certificate serial number directly to the CA's "OCSP Responder".
- The responder returns a signed micro-response: `Good`, `Revoked`, or `Unknown`.
- **Drawbacks**:
  - **Privacy Leak**: The CA learns every domain the user visits in real-time.
  - **Performance Hit**: An extra DNS lookup and HTTP round-trip before every new TLS connection.

### 3. OCSP Stapling (RFC 6066 — The Modern Standard)
- Solves both CRL and OCSP problems by shifting the burden to the **Web Server**:
- The web server (Nginx) periodically queries the CA's OCSP responder itself and caches the timestamped, CA-signed OCSP response.
- When a client connects, Nginx "staples" this cached OCSP proof directly into the initial TLS handshake.
- **Benefits**: Zero latency for the client, zero privacy leaks to the CA, full cryptographic validity.

---

## 4 · Operating System & Browser Trust Stores

How does an operating system decide which Root CAs to trust? Through a curated **Trust Store**.

| System / Application | Trust Store Location & Mechanism | Update Command |
|---|---|---|
| **RHEL / AlmaLinux 9** | `/etc/pki/ca-trust/source/anchors/` | `update-ca-trust extract` |
| **Ubuntu / Debian** | `/usr/local/share/ca-certificates/` | `update-ca-certificates` |
| **Google Chrome / MS Edge** | Uses OS native store (CryptoAPI on Windows, Keychain on macOS, system PKI on Linux) | Controlled by OS |
| **Mozilla Firefox** | Uses its own independent **NSS** (Network Security Services) store (`cert9.db`) | Managed in Firefox Settings: `about:preferences#privacy` |
| **Java Applications** | `$JAVA_HOME/lib/security/cacerts` | `keytool -importcert -keystore cacerts` |
| **Python `certifi`** | Bundled `cacert.pem` inside `site-packages/certifi/` | `SSL_CERT_FILE` environment variable |

In our hands-on implementation, we will install our Root CA into AlmaLinux's native anchor directory so that `curl`, `python`, `git`, and system tools immediately recognize `labapp.com` without needing `--insecure` or `-k` flags.

