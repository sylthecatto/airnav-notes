---
tags:
  - cybersecurity
  - pki
  - certificates
  - trust-chains
  - security
reading-order: 3
created: 2026-09-21
aliases:
  - CA Hierarchies
  - Trust Chains
---

# Certificate Authorities & Trust Hierarchies

> [!abstract] The 30-Second Summary
> A **Certificate Authority (CA)** is a trusted entity that cryptographically signs identity assertions. Production PKI architectures strictly separate duties using a **2-Tier Hierarchy**: an **Offline Root CA** (self-signed, extremely long-lived, kept powered down in cold storage) that signs an **Online Intermediate CA** (short-lived, actively signs daily server certificates). When a client connects to a server, the server transmits a **Certificate Chain** (`fullchain.pem`). The client mathematically walks up this chain until it hits a pre-installed **Trust Anchor** in its local Operating System or Browser Trust Store. If an intermediate key leaks, only that branch is revoked; the Root CA remains intact.

---

## 1 · The Mental Model: The Nightclub, Bouncer & Passport Office

To understand why the CA's private key and your server's private key never conflict or decrypt each other's data, consider this physical analogy:

```
[ Government Passport Office ]  (CA)
  • Inspects your documents ahead of time.
  • Stamps your Driver's License with an official Gold State Seal (CA Digital Signature).
  • The Passport Office does NOT have your house key or secret handshake!
         │
         ▼
[ Nightclub Entrance ]  (Web Connection)
  • You (Visitor Browser) approach the door.
  • The Bouncer (Browser TLS engine) inspects the Driver's License presented by the Web Server.
  • The Bouncer uses a magnifying glass (pre-installed CA Public Key) to verify the Gold State Seal.
         │
         ▼
[ Secret VIP Room ]  (Encrypted Session)
  • Once identity is proven, the Bouncer locks a secret session code in a steel box using the Server's Public Key.
  • ONLY the Web Server can open this box using its secret VIP Handshake (Server Private Key).
  • The Government Passport Office (CA) cannot open the box, cannot read the data, and is not in the room!
```

---

## 2 · The Separation of Duties: All Four Keys Explained

There are **two completely separate keypairs** working during any secure connection. They never mix:

| Key | Who Holds It | Location on Disk | Exact Purpose |
|---|---|---|---|
| **CA Private Key** | Kept strictly secret by the CA | `root-ca/private/root-ca.key`<br>`intermediate-ca/private/intermediate-ca.key` | **Identity Verification**: Signs child certificates to create the tamper-proof cryptographic stamp. Never decrypts web traffic. |
| **CA Public Key** | Pre-installed globally in all OSs and browsers | `/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem`<br>Browser Root Stores | **Trust Anchor**: Used locally and offline by browsers to verify the authenticity of the CA's digital stamp. |
| **Server Public Key** | Distributed freely inside the server's certificate | In `labapp.crt` and sent over the wire to all visitors | **Session Encryption**: Allows connecting browsers to encrypt secret session keys specifically for this server. |
| **Server Private Key** | Kept strictly secret on the web server | `/etc/nginx/ssl/labapp.key` (`chmod 600`) | **Proof of Ownership & Decryption**: Unlocks the encrypted session key sent by the browser. Never signs certificates. |

---

## 3 · Two Major PKI Misconceptions Cleared

> [!tip] Misconception 1: "Why generate keys first on the server? How does an unrelated key get tied to a website?"
> When you run `openssl genrsa`, the keypair is completely random and has zero mathematical connection to `labapp.com`. That is the exact reason you go to a Certificate Authority!
> 1. You generate the random keypair locally.
> 2. You create a **CSR (Certificate Signing Request)**: *"Hi CA, my name is `labapp.com`, and here is my new random Public Key."*
> 3. The CA tests that you actually control `labapp.com` (via DNS challenge, HTTP file placement, or organizational validation).
> 4. Once validated, the CA creates the **X.509 Certificate**—the official cryptographic glue permanently binding your domain name to that random public key.

> [!tip] Misconception 2: "Does the browser contact the CA every time a user visits a website?"
> **The browser NEVER contacts the CA during the normal TLS handshake.**
> If browsers had to query DigiCert or Let's Encrypt every time a user clicked a link, the entire internet would grind to a halt, and CAs could track every website every human visits (a catastrophic privacy violation).
> 
> Instead, verification happens **100% locally and offline**:
> - The CA's public key was pre-installed onto your hard drive when you installed your operating system.
> - The browser performs a purely local mathematical verification against its local **Root Trust Store**.

---

## 4 · PKI Architecture: 1-Tier vs. 2-Tier vs. 3-Tier

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

### Why the 2-Tier Architecture is the Production Standard
1. **The Root CA Remains OFFLINE**:
   - Kept air-gapped, powered down, or in cold storage.
   - Its private key is encrypted with AES-256 and a strong passphrase.
   - Booted only once every few years for 15 minutes to issue an Intermediate CA or update a Root CRL.
   - Validity: **10 to 20 years**.
2. **The Intermediate CA Handles DAILY OPERATIONS**:
   - Network-accessible server handling day-to-day certificate issuance.
   - Validity: **2 to 5 years**.
3. **Failure Isolation (Blast Radius Containment)**:
   - If an Intermediate CA server is breached, the administrator boots the Offline Root CA, revokes the compromised intermediate certificate, and issues a new Intermediate CA.
   - **Crucially: Zero client endpoints need their Trust Stores modified.** All clients still trust the Root CA anchor; they simply reject the revoked intermediate and seamlessly accept the newly issued one.

---

## 5 · The Chain of Trust & Path Validation (RFC 5280 §6)

When a web browser connects to `https://labapp.com`, the server presents its certificate chain. The browser's TLS engine executes the [RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280) Path Validation Algorithm:

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
│   Issuer: CN = AirNav DAS Root CA                      │
│   Subject: CN = AirNav DAS Intermediate CA             │
│   basicConstraints: CA:TRUE, pathlen:0                 │
│                                                        │
│ [ Server Certificate (Leaf / End-Entity) ]             │
│   Issuer: CN = AirNav DAS Intermediate CA              │
│   Subject: CN = labapp.com                             │
│   SAN: DNS:labapp.com, IP:192.168.100.20               │
│   basicConstraints: CA:FALSE                           │
└────────────────────────────────────────────────────────┘
```

### The 6 Verification Checks:
1. **Name Matching**: Does `labapp.com` in the browser address bar match an entry in the Leaf certificate's `subjectAltName`?
2. **Date Validity**: For *every* certificate in the chain, is current time between `Not Before` and `Not After`?
3. **Chain Assembly**: Does the Leaf's `AuthorityKeyIdentifier` (AKI) match the Intermediate's `SubjectKeyIdentifier` (SKI)? Does the Intermediate's AKI match the Root's SKI?
4. **Signature Verification**:
   - Decrypt Leaf's signature using Intermediate CA's public key; verify Leaf's SHA-256 digest.
   - Decrypt Intermediate's signature using Root CA's public key; verify Intermediate's SHA-256 digest.
5. **Extension Constraints**:
   - Ensure Intermediate has `basicConstraints: CA:TRUE`.
   - Ensure Leaf has `basicConstraints: CA:FALSE`.
   - Ensure path length limits (`pathlen:0`) are not exceeded.
6. **Trust Anchor Termination**: Is the Root CA found inside the client's local, trusted Root Certificate Store?

---

## 6 · Why You NEVER Include the Root CA in `fullchain.pem`

When configuring Nginx (`ssl_certificate /etc/nginx/ssl/fullchain.pem;`), the file must contain:
```text
-----BEGIN CERTIFICATE-----
(Server / Leaf Certificate)
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
(Intermediate CA Certificate)
-----END CERTIFICATE-----
```

> [!danger] Do NOT Append the Root CA!
> 1. **It is Cryptographically Useless**: Sending the Root Certificate over the network does not make the client trust it. A client only trusts a Root CA if it was already sitting in its local Root Trust Store *before* the connection began.
> 2. **Wasted Network Bandwidth**: Handshake packets are transmitted before data flows. Appending an unnecessary 1–2 KB Root certificate wastes round-trip packets and slows down initial connection establishment (Time-To-First-Byte).

---

## 7 · Operating System & Browser Trust Stores

| System / Application | Trust Store Location & Mechanism | Update Command |
|---|---|---|
| **RHEL / AlmaLinux 9** | `/etc/pki/ca-trust/source/anchors/` | `sudo update-ca-trust extract` |
| **Ubuntu / Debian** | `/usr/local/share/ca-certificates/` | `sudo update-ca-certificates` |
| **Chrome / Edge (Linux)** | Direct integration with OS shared NSS DB (`/etc/pki/ca-trust`) | Controlled by OS update commands |
| **Mozilla Firefox** | Dedicated internal SQLite trust database (`cert9.db`) | Managed in `Settings` $\to$ `Privacy & Security` $\to$ `View Certificates...` |
| **Python Applications** | System bundle or `certifi` package | Set `REQUESTS_CA_BUNDLE` or `SSL_CERT_FILE` |
| **OpenSSL CLI / curl** | Reads `/etc/pki/tls/certs/ca-bundle.crt` | Synchronized automatically by `update-ca-trust` |
