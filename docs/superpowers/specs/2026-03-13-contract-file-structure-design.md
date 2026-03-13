# Contract File Structure: Solidity + Arbitrum Stylus

**Date:** 2026-03-13
**Status:** Draft
**Scope:** Reorganize the `contracts/` directory to support both Foundry (Solidity) and Arbitrum Stylus (Rust) contracts with tight interop, shared interfaces, and cross-language integration testing.

## Context

W's smart contract layer currently lives in `contracts/` as a single Foundry project containing WCustodyNFT (Solidity). The upcoming VCP Verifier and 1-2 additional contracts will be written in Rust targeting Arbitrum Stylus. These Stylus contracts call Solidity contracts directly (e.g., VCP Verifier holds `MINTER_ROLE` and calls `WCustodyNFT.mint()`), so the two build systems need shared ABI artifacts at build time.

## Design Decision

**Monorepo with shared root** — group all on-chain code under `contracts/` with isolated subdirectories for each build system, a shared `interfaces/` directory, and a dedicated integration test layer.

### Alternatives Considered

**Flat siblings** (`solidity/`, `stylus/` at project root): maximally flat but loses conceptual grouping and has no natural home for shared interfaces.

**Foundry-first with nested Rust** (Cargo workspace inside `contracts/`): minimal migration but Foundry tooling may conflict with Rust files, and build boundaries are unclear.

## Directory Structure

```
w-code/
├── contracts/
│   ├── solidity/                    # Foundry project
│   │   ├── src/
│   │   │   └── WCustodyNFT.sol
│   │   ├── test/
│   │   │   └── WCustodyNFT.t.sol
│   │   ├── script/
│   │   │   └── DeployWCustodyNFT.s.sol
│   │   ├── lib/                     # forge install deps (forge-std, openzeppelin)
│   │   ├── foundry.toml
│   │   └── .gitignore               # cache/, out/
│   │
│   ├── stylus/                      # Cargo workspace
│   │   ├── Cargo.toml               # [workspace] members = ["vcp-verifier", ...]
│   │   ├── vcp-verifier/
│   │   │   ├── Cargo.toml
│   │   │   └── src/
│   │   │       └── lib.rs
│   │   └── <future-crate>/
│   │       ├── Cargo.toml
│   │       └── src/
│   │
│   ├── interfaces/                  # Shared Solidity interfaces
│   │   ├── IWCustodyNFT.sol         # Interface extracted from WCustodyNFT
│   │   └── IVCPVerifier.sol         # Verifier interface (Solidity canonical)
│   │
│   └── integration/                 # Cross-language integration tests
│       ├── Cargo.toml               # Rust test harness
│       └── tests/
│           └── vcp_mint_flow.rs     # Deploy both, test cross-contract calls
│
├── docs/
├── .gitignore
├── CLAUDE.md
└── README.md
```

## Build System & ABI Sharing

### Foundry (contracts/solidity/)

`foundry.toml` adds a remapping so Solidity sources can import shared interfaces:

```toml
remappings = [
    "@interfaces/=../interfaces/",
    "@openzeppelin/=lib/openzeppelin-contracts/"
]
```

WCustodyNFT implements `IWCustodyNFT`. ABI JSON output from `forge build` lands in `out/` as usual.

### Stylus (contracts/stylus/)

Each crate depends on `stylus-sdk` and `alloy-sol-types`. Crates consume interfaces via the `sol!` macro pointed at the shared interface files:

```rust
sol!("../../interfaces/IWCustodyNFT.sol");
```

This generates Rust bindings at compile time from the canonical Solidity interface — no manual ABI copying.

### Interface Flow

```
interfaces/IWCustodyNFT.sol
    ├── imported by solidity/src/WCustodyNFT.sol  (implements it)
    └── consumed by stylus/vcp-verifier/src/lib.rs (calls it via sol! bindings)
```

Single source of truth for cross-contract ABIs.

### Integration Tests (contracts/integration/)

A standalone Rust crate (not part of the Stylus workspace) that:

1. Spins up a local Stylus-compatible devnet (nitro-testnode or anvil)
2. Deploys compiled Solidity artifacts (reads ABI/bytecode from `solidity/out/`)
3. Deploys Stylus WASM contracts
4. Tests the full mint flow: VCP Verifier validates attestation → calls WCustodyNFT.mint()

## Build Commands

```bash
# Solidity
cd contracts/solidity
forge build
forge test -vv
forge test --gas-report

# Stylus
cd contracts/stylus
cargo stylus check          # Validate WASM compatibility
cargo build --release       # Build all workspace crates
cargo test                  # Unit tests

# Integration
cd contracts/integration
cargo test                  # Requires local devnet running

# Single test examples
cd contracts/solidity && forge test --match-test test_mint_sets_owner -vv
cd contracts/integration && cargo test vcp_mint_flow -- --nocapture
```

## Migration Plan

One-time migration from the current flat `contracts/` structure:

1. Move `contracts/{src,test,script,lib,foundry.toml,.gitignore}` → `contracts/solidity/`
2. Create empty `contracts/stylus/Cargo.toml` (workspace scaffold)
3. Create `contracts/interfaces/` and extract `IWCustodyNFT.sol` from `WCustodyNFT.sol`
4. Create empty `contracts/integration/` scaffold
5. Update `foundry.toml` remappings for the new `interfaces/` path
6. Verify `forge build && forge test` pass from `contracts/solidity/`
7. Update `CLAUDE.md` and `README.md` with new paths and commands

No Stylus code exists yet, so the Cargo workspace and integration crate start as minimal scaffolds.

## Constraints

- Solidity version locked at 0.8.28
- OpenZeppelin v5.6.1 (ERC-721, ERC-2981, AccessControl)
- Stylus contracts target Arbitrum L3
- Token ID scheme (`uint256(keccak256(nid))`) and immutable token URIs are unchanged
- VCP Verifier will hold `MINTER_ROLE` on WCustodyNFT
