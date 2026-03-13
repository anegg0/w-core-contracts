# Verified Capture Protocol (IRL) — Design Document

**Date:** 2026-03-12
**Status:** Approved
**Replaces:** Camera Flash Signature (CFS) concept

## 1. Purpose

IRL is a composite attestation protocol that provides strong evidence that a photo was captured directly from a physical camera on a verified, uncompromised device with no software tampering. It replaces the earlier CFS concept, which implied a single cryptographic trick. IRL is honest about what it is: layered evidence, not mathematical proof.

## 2. Threat Model

### Target adversary: Motivated fraud (B-level)

Modified apps, virtual cameras, Xposed/Frida hooks, basic jailbreaks. Willing to invest moderate effort and technical skill.

### What IRL guarantees

- The image bytes were produced by a physical camera sensor on an uncompromised, allowlisted device
- The image was not modified between ISP output and signing
- The capture timestamp is hardware-attested
- A recapture risk score is permanently attached (for original-scene mode)

### What IRL does NOT guarantee

- That the scene itself is "real" (someone could photograph a high-quality physical diorama)
- Resistance to sophisticated jailbreaks that bypass App Attest (mitigated by allowlist + attestation layering)
- That the photo was not taken under duress or with misleading framing
- Nation-state or custom-hardware resistance

### Honest marketing language

"IRL provides strong evidence that a photo was captured directly from a physical camera on a verified device, with no software tampering. It dramatically raises the cost and difficulty of forgery, but no software system on consumer hardware can provide absolute guarantees."

### Trust boundaries

```
TRUSTED (Secure Enclave)          UNTRUSTED (Application Processor)
+----------------------+          +-----------------------------+
| Signing key storage  |          | App UI                      |
| Key attestation      |          | Recapture detection ML      |
| Signature generation |          | C2PA manifest assembly      |
| Timestamp            |          | IPFS upload                 |
+----------+-----------+          | On-chain anchoring          |
           |                      +-----------------------------+
           | signs
           v
+----------------------+
| Camera ISP output    |  <-- SEMI-TRUSTED (hardware pipeline,
| Sensor metadata      |      uniform on allowlisted devices)
| IMU readings         |
+----------------------+
```

## 3. Platform Strategy

### iOS-first, Android v1.1

iOS ships first because:

- Apple's Secure Enclave has a strong track record
- No user-unlockable bootloader (jailbreaking is harder than rooting Android)
- Uniform camera pipeline (one vendor, fewer device variations to audit)
- Many professional photographers already use iPhones

### Device allowlist

| Tier | Devices | Capabilities |
|---|---|---|
| **Full IRL** | iPhone 12 Pro, 13 Pro, 14 Pro, 15 Pro, 16 Pro (+ Pro Max) | LiDAR + Secure Enclave + modern ISP. Strongest depth analysis |
| **IRL without depth** | iPhone 12, 13, 14, 15, 16 (non-Pro) | No LiDAR. Recapture detection relies on moire, flicker, IMU parallax, texture |
| **Not supported** | iPhone 11 and older | App Attest inconsistent, camera hardware too varied |

Minimum requirements: Secure Enclave with App Attest, iOS 16+, A12 chip or later.

### Allowlist enforcement at runtime

Attestation is verified at every capture, not just app launch. Each shutter press triggers a fresh App Attest assertion signed by the Secure Enclave. This prevents "pass attestation, then jailbreak" attacks.

```
App launch
    |
    v
Request App Attest key + attestation object
    |
    v
Send attestation to W backend for verification
    |
    +-- Apple CA chain valid?
    +-- Device model in allowlist?
    +-- App binary hash matches App Store build?
    +-- OS version >= minimum?
    |
    v
Backend returns: { allowed: true, tier: "full" | "no-lidar" }
```

### Android (v1.1, defined not implemented)

| iOS | Android equivalent |
|---|---|
| App Attest | Play Integrity API (MEETS_STRONG_INTEGRITY) |
| Secure Enclave | StrongBox Keymaster (Titan M2 on Pixel) |
| Core ML | TensorFlow Lite / NNAPI |
| LiDAR | ToF sensor (Pixel, Samsung flagships) |

Android allowlist will be narrower: only devices with StrongBox (not just TEE), verified boot, and audited camera pipelines. Likely: Pixel 6+, Samsung S22+.

## 4. Capture Flow

### What happens when the user presses the shutter

```
User taps shutter
       |
       v
+-- AVCaptureSession ------------------------------------+
|  Physical sensor -> ISP -> processed image bytes       |
|  + IMU readings (accelerometer, gyroscope)             |
|  + ambient light sensor                                |
+--------------------+-----------------------------------+
                     | raw ISP output + sensor data
                     v
+-- Capture Mode Gate -----------------------------------+
|  if mode == "original-scene":                          |
|    run recapture detection -> score [0,1]              |
|  if mode == "document":                                |
|    skip detection, tag as document                     |
+--------------------+-----------------------------------+
                     |
                     v
+-- IRL Bundle Assembly ---------------------------------+
|  image_hash:       SHA-256 of image bytes              |
|  timestamp:        Secure Enclave attested time        |
|  device_model:     from attestation cert chain         |
|  imu_snapshot:     500ms window around capture         |
|  capture_mode:     "original-scene" | "document"       |
|  recapture_score:  float or null                       |
|  app_version:      build hash                          |
+--------------------+-----------------------------------+
                     |
                     v
+-- Secure Enclave --------------------------------------+
|  Sign IRL bundle with App Attest key                   |
|  Certificate chain -> Apple CA root                    |
+--------------------+-----------------------------------+
                     | signed IRL bundle + image
                     v
+-- Local Storage (encrypted) ---------------------------+
|  C2PA manifest assembled with IRL as assertion         |
|  Image + manifest saved to app sandbox                 |
+--------------------+-----------------------------------+
                     | when connectivity available
                     v
+-- Deferred Anchor -------------------------------------+
|  1. Pin image + AssetTree to IPFS -> get CID           |
|  2. Submit on-chain commit (Arbitrum L3)               |
|  3. Mint IRLCustodyNFT with trust tier                   |
+--------------------------------------------------------+
```

### Image processing policy

Minimal ISP processing only. The hardware ISP performs standard demosaic, white balance, and noise reduction. No filters, no AI enhancement, no user edits. What the camera hardware produces is what gets signed.

Rationale: W's value proposition is "this is what the camera saw." Allowing edits muddies that claim. Controlled user edits (crop, exposure) may be added later as a chained C2PA action in a future version.

### Offline behavior

- Capture, sign, and store all work offline
- C2PA manifest is complete with IRL signature
- Upload queue persists until connectivity returns
- On-chain anchor timestamp reflects "anchored at" not "captured at" (capture time is in the IRL bundle)

## 5. Capture Modes & Trust Tiers

### Two capture modes

The user declares intent before capture:

| Mode | Behavior | Use case |
|---|---|---|
| **Original scene** | Recapture detection runs, score attached | Photojournalism, street photography, evidence |
| **Document** | Detection skipped, tagged as document | Photographing documents, billboards, paintings |

### Trust tiers in AssetTree

| Tier | Meaning | When assigned |
|---|---|---|
| `verified-original` | All attestation checks pass, recapture score < threshold | Original-scene mode, no flags |
| `flagged-recapture` | Attestation passes, but recapture score >= threshold | Original-scene mode, detection triggered |
| `declared-document` | Attestation passes, user declared document/billboard | Document mode |
| `attestation-partial` | Some attestation checks unavailable (older device on allowlist) | Degraded but still allowed |

The recapture score threshold (initially 0.3) is server-side configuration, tunable without an app update. Needs calibration with real-world testing data.

A flagged photo still gets signed, minted, and anchored. The flag is permanent and immutable once minted. Users cannot remove it.

## 6. Recapture Detection

### Screen recapture signals

| Signal | Technique | Robustness |
|---|---|---|
| Moire patterns | CNN detecting interference between camera and display pixel grids | Strong |
| Display refresh flicker | Rolling shutter captures banding at 60-120Hz refresh rate | Strong |
| Color subpixel structure | PenTile/stripe RGB layout detection in macro detail | Moderate |
| Light uniformity | Backlight bleed and vignetting patterns distinct from natural light | Moderate |
| Reflection/glare | Specular reflections from screen glass | Moderate |

### Print recapture signals

| Signal | Technique | Robustness |
|---|---|---|
| Paper texture / halftone | Macro-level texture detection | Moderate |
| Depth-of-field inconsistency | Flat print has uniform focus; real 3D scenes don't | Moderate |
| Edge artifacts | Photo edges, curling, frames | Weak |
| IMU vs parallax mismatch | Phone movement (IMU) should produce parallax in 3D scenes; flat prints don't | Strong |

### Scoring ensemble

Not a single model. A weighted ensemble of independent detectors:

```
recapture_score = weighted_average(
    moire_detector(image),
    flicker_detector(image),
    subpixel_detector(image),
    texture_detector(image),
    depth_consistency(image),
    imu_parallax_check(imu, image)
)
```

Each detector returns [0,1]. Weights are tuned per device model (different cameras have different noise profiles).

### Design decisions

- **On-device inference only.** Raw images never leave the device unsigned. ML models must be lightweight enough for Core ML on iOS.
- **IMU parallax is the strongest signal.** Correlating two independent hardware systems (motion sensor + camera) in real time is significantly harder to fake than any single visual signal.
- **Continuous score, not binary.** Avoids false-positive blocking. Threshold is server-configurable.

## 7. C2PA Integration

IRL embeds as a custom C2PA assertion. Any C2PA-aware tool (Adobe Content Credentials, Truepic, newsroom verification tools) can read the provenance.

### C2PA manifest structure

```json
{
  "claim_generator": "IRL Camera/1.0",
  "assertions": [
    {
      "label": "c2pa.actions",
      "data": {
        "actions": [{
          "action": "c2pa.created",
          "digitalSourceType": "http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture"
        }]
      }
    },
    {
      "label": "w.vcp.v1",
      "data": {
        "image_hash": "sha256:...",
        "capture_timestamp": "2026-03-12T14:32:01Z",
        "device_attestation": {
          "platform": "ios",
          "method": "app-attest",
          "cert_chain": ["..."],
          "device_tier": "full"
        },
        "imu_snapshot": {
          "duration_ms": 500,
          "accel_samples": 50,
          "gyro_samples": 50,
          "hash": "sha256:..."
        },
        "capture_mode": "original-scene",
        "recapture_score": 0.12,
        "app_build_hash": "sha256:..."
      }
    }
  ],
  "signature": {
    "algorithm": "ES256",
    "cert_chain": ["... Secure Enclave attested key ..."]
  }
}
```

### AssetTree schema additions

| New field | Type | Description |
|---|---|---|
| `captureIntegrity` | string enum | `verified-original` / `flagged-recapture` / `declared-document` / `attestation-partial` |
| `vcpVersion` | string | Protocol version, e.g., `"1.0"` |
| `captureMode` | string enum | `original-scene` / `document` |
| `recaptureScore` | float or null | [0,1] for original-scene, null for document |
| `attestationPlatform` | string | `ios` / `android` |
| `deviceTier` | string | `full` / `no-lidar` / `strongbox` |

## 8. Smart Contract Impact

### IRLCustodyNFT — no changes needed

The contract is agnostic to AssetTree content. It stores the IPFS CID of the AssetTree. Trust tier lives in the AssetTree JSON, not on-chain.

### IRL Verifier (replaces CFS Verifier)

Rust/Stylus contract that holds MINTER_ROLE on IRLCustodyNFT. Verifies IRL attestation on-chain before authorizing mint.

On-chain verification scope:

| Check | Feasible on-chain? |
|---|---|
| Apple/Google CA certificate chain | Yes — elliptic curve signature verification in Stylus |
| Image hash matches CID | Yes — hash comparison |
| Recapture score vs threshold | Yes — simple comparison |
| IMU data validity | No — trust the signed bundle |
| ML model output | No — not reproducible on-chain |

The on-chain verifier confirms: "a valid attested device signed this bundle, and the recapture score is below threshold." ML detection is trusted as part of the signed bundle.

## 9. Scope

### v1 (iOS, photos only)

| Component | Description |
|---|---|
| IRL Camera app (iOS) | AVCaptureSession-based, minimal ISP processing, two capture modes |
| IRL bundle assembly | Composite attestation: image hash, timestamp, device attestation, IMU, recapture score |
| Secure Enclave signing | App Attest key, per-capture assertion, Apple CA chain |
| Recapture detection | On-device ML ensemble (moire, flicker, subpixel, texture, depth, IMU parallax) |
| Device allowlist | Server-side, iPhone 12+ (two tiers: full / no-lidar) |
| C2PA manifest | IRL as custom assertion, standard c2pa.created action |
| Local storage | Encrypted app sandbox, offline capture queue |
| Deferred anchor | IPFS pin + Arbitrum L3 commit + IRLCustodyNFT mint when online |
| Trust tiers | Four tiers in AssetTree, immutable once minted |
| IRL Verifier (Stylus) | On-chain certificate chain + hash + threshold verification, holds MINTER_ROLE |

### v1.1 (defined, not implemented)

| Component | Description |
|---|---|
| Video support | Segment-based hashing, keyframe recapture detection, continuous IMU correlation |
| Android support | Play Integrity + StrongBox, Pixel 6+ / Samsung S22+ allowlist |
| Device revocation | FIDO-style device binding, backend key registry, retroactive flagging |

### Explicitly out of scope

| Item | Reason |
|---|---|
| AI-generated content detection | Different problem domain |
| User-facing image editing | Contradicts "what the camera saw" promise |
| Social features | Separate layer, not the camera app |
| Custom hardware / dedicated camera | B-level threat model doesn't require it |
| Nation-state resistance | Beyond consumer device capability |
| User appeals for flagged photos | Needs policy design, not a v1 technical problem |

## 10. Risks

1. **Apple could change App Attest behavior.** Mitigation: abstract the attestation interface so implementations are swappable.
2. **Recapture ML models need training data.** A dataset of screen-captures and print-captures alongside genuine photos must be collected before detection is reliable.
3. **Stylus/Rust on Arbitrum is maturing.** Mitigation: can deploy a temporary Solidity verifier that checks fewer fields.
4. **C2PA tooling on iOS is early.** The c2pa-rs Rust library exists but iOS bindings need work. Mitigation: embed IRL data in EXIF as a fallback, migrate to proper C2PA when tooling matures.
