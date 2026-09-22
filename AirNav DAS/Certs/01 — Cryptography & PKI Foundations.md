---
tags:
  - cybersecurity
  - cryptography
  - pki
  - tls
reading-order: 1
created: 2026-09-21
aliases:
  - Cryptography Foundations
  - PKI Fundamentals
---

# Cryptography & PKI Foundations

> [!abstract] The 30-Second Summary
> Cryptography provides four security guarantees: **Confidentiality** (encryption), **Integrity** (hashing/MACs), **Authentication** (digital signatures), and **Non-Repudiation**. Asymmetric cryptography uses mathematically linked keypairs: a **Private Key** (kept secret) and a **Public Key** (distributed freely). However, asymmetric math alone fails to solve the **Key Distribution Problem**: if an attacker intercepts your initial connection, they can swap your public key with their own (Man-in-the-Middle). **PKI (Public Key Infrastructure)** solves this by having a mutually trusted third party (a Certificate Authority) cryptographically sign an identity-to-public-key binding ahead of time.

---

## 1 · The Four Pillars of Information Security

Every secure transport protocol ([TLS 1.3](https://datatracker.ietf.org/doc/html/rfc8446), SSH, IPsec) satisfies four core security objectives:

| Security Goal | Definition | Cryptographic Primitive | Real-World Equivalent |
|---|---|---|---|
| **Confidentiality** | Only authorized parties can read the data. | Symmetric Encryption (AES-GCM, ChaCha20-Poly1305) | An opaque, locked briefcase. |
| **Integrity** | Data cannot be altered in transit without detection. | Cryptographic Hash Functions (SHA-256, SHA-384) | An unbroken wax seal on an envelope. |
| **Authentication** | Verifying that the entity is who they claim to be. | Digital Signatures (RSA, ECDSA, Ed25519) + PKI | A government-issued passport. |
| **Non-Repudiation** | The sender cannot deny having sent a transaction. | Digital Signatures | A notarized signature on legal paper. |

---

## 2 · Symmetric vs. Asymmetric Cryptography

```
SYMMETRIC CRYPTOGRAPHY (Single Shared Secret)
Alice ─────[Shared Key K]─────► Ciphertext ─────[Shared Key K]─────► Bob
Fast, hardware-accelerated. Challenge: How do Alice and Bob securely share K over an untrusted network?

ASYMMETRIC CRYPTOGRAPHY (Public / Private Keypair)
Alice ───[Bob's Public Key]───► Ciphertext ───[Bob's Private Key]───► Bob
Solves key distribution. Slower computationally (~100x to 1000x slower than symmetric).
```

### The Engineer's Decision Matrix: Algorithms & Standards

You do not need to memorize prime factorization modulo math or elliptic curve polynomial coordinate proofs ($y^2 = x^3 + ax + b$). In production engineering, your focus is selecting the right algorithm and key size according to [NIST SP 800-57 Part 1 Rev. 5](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final):

| Domain | Standardize On | Key Size / Curve | Why This Choice Matters |
|---|---|---|---|
| **Bulk Data Encryption** | **AES-GCM** or **ChaCha20-Poly1305** | 256-bit | Hardware-accelerated (AES-NI instructions on x86/ARM), provides AEAD (authenticated encryption). |
| **SSH Keys** | **Ed25519** | 256-bit | Immune to cache timing side-channel attacks by design, short public keys (68 chars). |
| **Web Certificates (TLS)** | **ECDSA** (preferred) or **RSA** | P-256 (`prime256v1`) or RSA 3072–4096 | **256-bit ECC matches the security of 3072-bit RSA** with 85% smaller certs, faster handshakes, and lower server CPU load. |

---

## 3 · Cryptographic Hash Functions & Digital Signatures

### What is a Hash Function? (The Digital Blender Analogy)

Think of a cryptographic hash function like a **digital blender**:
- You drop any amount of data into the blender—whether a single word ("cat") or a 1,000-page book.
- The blender runs thousands of mathematical mixing cycles and produces a fixed-length string called a **digest** or **hash** (e.g., 256 bits / 64 hexadecimal characters for SHA-256).

```
[ Your Original File (Any Size) ]
      │
      ▼
 1. Padding & 512-bit Block Chunking
 ┌──────────┬──────────┬──────────┐
 │ Block 1  │ Block 2  │ Block 3  │
 └────┬─────┴────┬─────┴────┬─────┘
      │          │          │
      ▼          ▼          ▼
 2. Compression Engine (Bit Shifts, XOR/AND logic, Modular Addition)
      │
      ▼
 ┌────────────────────────────────┐
 │  Fixed 256-bit Hash Output     │ <-- e.g., "e3b0c44298fc1c149afbf4c8996fb924..." (64 hex chars)
 └────────────────────────────────┘
```

#### The Core Properties:
1. **Deterministic (100% Consistent)**: The input `"cat"` will always produce the exact same 64-character hash. Modifying even one letter (`"Cat"`) completely scrambles the output into unrecognizable randomness (**The Avalanche Effect**).
2. **Pre-image Resistant (One-Way Street)**: Going forward is trivial (`Data -> Hash`). Going backward is impossible (`Hash -/-> Data`). A hash is **not compression** (like `.zip`); you cannot "decompress" a hash to retrieve the original book.
3. **Collision Resistant (No Double Matches)**: It is computationally infeasible to find two different files $m_1 \ne m_2$ that yield $H(m_1) = H(m_2)$.

> [!warning] Why MD5 and SHA-1 Are Broken
> Cryptanalysts found mathematical shortcuts to generate identical hashes for different files (collisions). An attacker can craft a benign document and a virus with the exact same MD5/SHA-1 hash. Consequently, [NIST SP 800-131A](https://csrc.nist.gov/publications/detail/sp/800-131a/rev-2/final) and the [CA/Browser Forum](https://cabforum.org/) strictly ban MD5 and SHA-1 in production PKI. Modern standards mandate **SHA-256**, **SHA-384**, or **SHA-3**.

### Analogy: The King's Physical Wax Seal

Imagine a king sends a 500-page manuscript wrapped in a parcel, stamped with an intricate wax seal:
- The wax seal **does not store** the 500 pages of text. You cannot read the manuscript by looking at the wax.
- However, if the recipient receives the parcel with the wax seal unbroken and matching the royal crest, they know two facts:
  1. This parcel genuinely originated from the king (**Authentication**).
  2. Nobody tampered with or opened the pages in transit (**Integrity**).
- **That wax seal is your hash and digital signature.**

---

### How a Digital Signature Works

A digital signature is **not** raw encryption of an entire file. It is the asymmetric encryption of the file's **hash digest**:

```
SIGNING PROCESS (Sender):
1. Document / Certificate Data ────────► [ SHA-256 Hash ] ────────► Digest (32 bytes)
2. Digest + Signer's PRIVATE Key ──────► [ Asymmetric Sign Algorithm ] ──► Digital Signature

VERIFICATION PROCESS (Recipient):
1. Received Document Data ─────────────► [ SHA-256 Hash ] ────────► Computed Digest
2. Digital Signature + Signer's PUBLIC Key ──► [ Asymmetric Verify ] ──► Decrypted Digest
3. Check: If (Computed Digest == Decrypted Digest) ──► VALID SIGNATURE!
```

---

## 4 · The Key Distribution Problem: Two Tunnels, One Attacker

Why isn't asymmetric encryption alone sufficient for secure web communications?

Suppose Alice wants to connect securely to `labapp.com`. If an attacker (Eve) sits on the local network (via ARP spoofing, rogue Wi-Fi, or DNS cache poisoning), here is how the **Man-in-the-Middle (MitM)** attack unfolds:

```
[ ALICE ]                         [ EVE (Attacker / MitM) ]                    [ LABAPP.COM ]
    │                                         │                                      │
    │ ─── 1. "Send me your Public Key" ─────► │ (Intercepts request)                │
    │                                         │ ─── 2. "Send me your Public Key" ──► │
    │                                         │                                      │
    │                                         │ ◄── 3. Receives Real Server_PubKey ──│
    │ ◄── 4. Sends EVE_PubKey to Alice ────── │ (Drops Server_PubKey, sends own key) │
    │    ("Here is labapp.com's key!")        │                                      │
    ├─────────────────────────────────────────┼──────────────────────────────────────┤
    │                  KEY EXCHANGE & EAVESDROPPING PHASE                            │
    ├─────────────────────────────────────────┼──────────────────────────────────────┤
    │                                         │                                      │
    │ ─── 5. Encrypts "Secret Key X" ───────► │                                      │
    │        using EVE_PubKey                 │ ─── Decrypts "Secret Key X" using     │
    │                                         │     EVE_PrivKey (Eve stole the key!) │
    │                                         │                                      │
    │                                         │ ─── Re-encrypts "Secret Key X" ────► │
    │                                         │     using Real Server_PubKey         │
    ├─────────────────────────────────────────┼──────────────────────────────────────┤
    │                      ACTIVE TRAFFIC INTERCEPTION                               │
    ├─────────────────────────────────────────┼──────────────────────────────────────┤
    │                                         │                                      │
    │ ◄=====================================► │ ◄==================================► │
    │   Tunnel A: Encrypted with Key X        │   Tunnel B: Encrypted with Key X     │
    │          (Alice <---> Eve)              │          (Eve <---> Server)          │
    │                                         │                                      │
    │   Alice sends: "Transfer $100 to Bob"   │   Eve modifies: "Transfer $10,000"   │
```

> [!caution] The Core Lesson of the MitM Attack
> 1. **The Math Worked 100% Perfectly**: Alice's encryption to Eve was mathematically unbreakable. Eve's encryption to the server was mathematically unbreakable.
> 2. **The Identity Failed Completely**: Alice encrypted her data using the wrong entity's public key because she had no built-in mechanism to verify that `EVE_PubKey` genuinely belonged to `labapp.com`.
> 
> **Axiom**: *Encryption without authentication is completely useless.*

---

## 5 · How Trust is Solved: SSH vs. Web PKI

| Approach | Trust Mechanism | How It Works | Vulnerability / Trade-Off |
|---|---|---|---|
| **SSH** | **Trust On First Use (TOFU)** | First connection prompts: *"The authenticity of host can't be established. Key fingerprint is SHA256:abc... Continue?"* If accepted, saved in `~/.ssh/known_hosts`. | Vulnerable if an attacker intercepts the **very first connection**. Impractical for the public web (users cannot manually verify millions of site fingerprints). |
| **Web PKI** | **Certificate Authority (CA) Hierarchy** | A trusted third party (CA) verifies domain ownership ahead of time and cryptographically signs the server's public key into an **X.509 Certificate**. | Requires pre-installed Root CA trust anchors in operating systems and browsers ([RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280)). Solves trust for billions of users with zero manual fingerprint checks. |

---

## Primary Sources & Standards

- **[NIST SP 800-57 Part 1 Rev. 5](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)**: *Recommendation for Key Management* (Defines cryptographic algorithm lifespans and key length equivalence).
- **[IETF RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280)**: *Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile*.
- **[IETF RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446)**: *The Transport Layer Security (TLS) Protocol Version 1.3*.
- **[NIST SP 800-131A Rev. 2](https://csrc.nist.gov/publications/detail/sp/800-131a/rev-2/final)**: *Transitioning the Use of Cryptographic Algorithms and Key Lengths* (Formal deprecation of MD5 and SHA-1).
