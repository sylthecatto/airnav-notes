---
tags:
  - cybersecurity
  - cryptography
  - pki
  - tls
reading-order: 1
created: 2026-09-21
---

# Cryptography & PKI Foundations

> [!abstract] The 30-second version
> Cryptography provides four security guarantees: **Confidentiality** (encryption), **Integrity** (hashing/MACs), **Authentication** (digital signatures), and **Non-Repudiation**. Asymmetric cryptography uses mathematically linked keypairs: a **Private Key** (kept secret) and a **Public Key** (distributed freely). However, asymmetric encryption alone fails to solve the **Key Distribution Problem**: if an attacker intercepts your initial connection, they can swap your public key with their own (Man-in-the-Middle). **PKI (Public Key Infrastructure)** solves this by having a mutually trusted third party (a Certificate Authority) cryptographically sign an identity-to-public-key binding.

---

## 1 · The Four Pillars of Information Security

Every secure transport protocol (TLS, SSH, IPsec) is designed to satisfy four core requirements:

| Security Goal | Definition | Cryptographic Primitive |
|---|---|---|
| **Confidentiality** | Only authorized parties can read the data. | Symmetric Encryption (AES-GCM, ChaCha20) |
| **Integrity** | Data cannot be altered in transit without immediate detection. | Cryptographic Hash Functions (SHA-256, SHA-384) & HMACs |
| **Authentication** | Proof of identity — verifying that the entity you communicate with is who they claim to be. | Digital Signatures (RSA, ECDSA, Ed25519) + PKI |
| **Non-Repudiation** | The sender cannot falsely deny having sent a specific message or initiated a transaction. | Digital Signatures |

---

## 2 · Symmetric vs. Asymmetric Cryptography

```
SYMMETRIC CRYPTOGRAPHY (Shared Secret)
Alice ─────[Shared Key K]─────► Ciphertext ─────[Shared Key K]─────► Bob
Fast, handles bulk data encryption. 
Challenge: How do Alice and Bob securely share K across an untrusted network?

ASYMMETRIC CRYPTOGRAPHY (Public / Private Keypair)
Alice ───[Bob's Public Key]───► Ciphertext ───[Bob's Private Key]───► Bob
Solves key agreement. Slower computationally (~100x to 1000x slower than symmetric).
```

### Symmetric Encryption
- Uses **one identical key** for both encryption and decryption.
- **Algorithms**: AES-128, AES-256 (in authenticated modes like GCM - Galois/Counter Mode), ChaCha20-Poly1305.
- **Strengths**: Extremely high throughput; hardware-accelerated on modern x86/ARM CPUs (AES-NI instruction set).
- **Limitation**: Key distribution. If $N$ parties need pairwise private communication, you need $\frac{N(N-1)}{2}$ shared keys.

### Asymmetric (Public Key) Cryptography
- Uses a **mathematically linked keypair**:
  - **Public Key**: Can be shared with the entire world without compromising security.
  - **Private Key**: Must be kept strictly secret, protected by strict filesystem permissions (`chmod 600` / `chmod 400`), hardware security modules (HSM), or passphrase encryption.
- **Algorithms**:
  - **RSA** (Rivest–Shamir–Adleman): Based on the difficulty of factoring the product of two large prime numbers. Modern standard requires **$\ge 2048$ bits** (NIST recommends **3072** or **4096** bits for longer lifespans).
  - **ECC / ECDSA** (Elliptic Curve Cryptography / Digital Signature Algorithm): Based on the algebraic structure of elliptic curves over finite fields (Discrete Logarithm Problem). A **256-bit ECC key** provides equivalent cryptographic strength to a **3072-bit RSA key**, with dramatically smaller certificate sizes, lower CPU overhead, and faster handshakes. Standard curves: `prime256v1` (NIST P-256), `secp384r1` (NIST P-384).
  - **Ed25519 / Ed448**: Edwards-curve Digital Signature Algorithm. Extremely high performance and collision/timing-attack resilience.

---

## 3 · Cryptographic Hash Functions & Digital Signatures

### What is a Hash Function?
A cryptographic hash function $H(m)$ takes input data of arbitrary size and transforms it into a fixed-length string of bytes (digest) such that:
1. **Deterministic**: The same input always produces the exact same output.
2. **Pre-image resistant (One-way)**: Given digest $h$, it is computationally infeasible to find $m$ such that $H(m) = h$.
3. **Collision resistant**: It is computationally infeasible to find two different messages $m_1 \ne m_2$ such that $H(m_1) = H(m_2)$.
- **Secure algorithms**: SHA-256, SHA-384, SHA-512 (SHA-2 family), SHA-3.
- **Broken / Deprecated algorithms**: MD5, SHA-1 (both suffer from practical collision attacks and are strictly forbidden in modern PKI by CA/B Forum and NIST SP 800-131A).

### How a Digital Signature Works

A digital signature is **not** raw encryption of an entire file. It is the asymmetric encryption of the file's **hash digest**:

```
SIGNING PROCESS (by Sender / Signer):
1. Document / Certificate Data ────────► [ SHA-256 Hash ] ────────► Digest (32 bytes)
2. Digest + Signer's PRIVATE Key ──────► [ Asymmetric Sign Algorithm ] ──► Digital Signature

VERIFICATION PROCESS (by Recipient / Verifier):
1. Received Document Data ─────────────► [ SHA-256 Hash ] ────────► Computed Digest
2. Digital Signature + Signer's PUBLIC Key ──► [ Asymmetric Verify ] ──► Decrypted Digest
3. Check: If (Computed Digest == Decrypted Digest) ──► VALID SIGNATURE!
```

> [!info] Concept: What does a valid signature guarantee?
> 1. **Authentication**: Only the holder of the corresponding private key could have produced the signature.
> 2. **Integrity**: If even a single byte of the original document was modified after signing, the computed hash will completely diverge from the decrypted digest, causing immediate verification failure.

---

## 4 · The Key Distribution Problem & The MITM Attack

Why isn't asymmetric encryption alone sufficient for secure web communications?

Suppose Alice wants to establish an encrypted connection to `labapp.com`:

```
WITHOUT PKI / CERTIFICATES:
Alice                               Eve (Attacker / MITM)                 labapp.com
  │                                           │                                │
  │─── 1. "Send me your public key" ─────────►│ (Intercepts request)           │
  │                                           │─── 2. "Send me your public key"──►
  │                                           │                                │
  │                                           │◄── 3. Returns Server_PubKey ───│
  │◄── 4. Returns Eve_PubKey (Fraudulent) ────│ (Eve drops Server_PubKey)      │
  │                                           │                                │
  │─── 5. Encrypts secret with Eve_PubKey ───►│                                │
  │       (Alice thinks it's the server!)     │ (Eve decrypts secret with      │
  │                                           │  Eve_PrivKey, inspects it,     │
  │                                           │  re-encrypts with Server_PubKey)
  │                                           │─── 6. Forwards to server ─────►│
```

Eve successfully eavesdrops on and modifies all traffic. Even though encryption was used, Alice had **no mechanism to authenticate** that `Eve_PubKey` did not belong to `labapp.com`.

This demonstrates the fundamental security axiom:
> **Confidentiality without authentication is an illusion.**

---

## 5 · Why PKI Exists

**PKI (Public Key Infrastructure)** is the comprehensive architecture designed to defeat this Man-in-the-Middle vulnerability.

Instead of a server simply handing out an arbitrary public key, it hands out an **X.509 Digital Certificate**:
1. The certificate packages the server's **Public Key** together with its **Identity attributes** (Domain name: `labapp.com`, Organization, Validity dates).
2. A mutually trusted authority — a **Certificate Authority (CA)** — inspects the server's claim, verifies ownership of `labapp.com`, and attaches its **own cryptographic digital signature** to that package.
3. When Alice's browser connects to `labapp.com`, it receives the certificate, checks the CA's signature using the CA's public key (which is already pre-installed and trusted in Alice's operating system), and verifies that the signature is mathematically genuine.

Because Eve does not hold the CA's private signing key, she cannot forge a valid signature for her rogue public key under the domain `labapp.com`. If she tries, the browser displays a security warning: **"Certificate Authority Invalid / Untrusted"**.

---

## Primary Sources & Standards

- **NIST Special Publication 800-57 Part 1 Rev. 5**: *Recommendation for Key Management: General* (NIST cryptographic guidelines on key strength and validity periods).
- **RFC 5280**: *Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile* (IETF standard defining X.509 in IP networks).
- **RFC 8446**: *The Transport Layer Security (TLS) Protocol Version 1.3* (The modern standard for encrypted web traffic).

