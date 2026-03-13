# Contract File Structure: Solidity + Arbitrum Stylus

**Date:** 2026-03-13
**Status:** Draft
**Scope:** Reorganize the `contracts/` directory to support both Foundry (Solidity) and Arbitrum Stylus (Rust) contracts with tight interop, shared interfaces, and cross-language integration testing.

## Context

W's smart contract layer currently lives in `contracts/` as a single Foundry project containing WCustodyNFT (Solidity). The upcoming CP Verifier and 1-2 additional contracts will be written in Rust targeting Arbitrum Stylus. These Stylus contracts call Solidity contracts directly (e.g., CP Verifier holds `MINTER_ROLE` and calls `WCustodyNFT.mint()`), so the two build systems need shared ABI artifacts at build time.

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
│   │   ├── interfaces -> ../interfaces     # symlink to shared interfaces
│   │   ├── foundry.toml
│   │   └── .gitignore               # cache/, out/
│   │
│   ├── stylus/                      # Cargo workspace
│   │   ├── Cargo.toml               # [workspace] members = ["vcp-verifier", ...]
│   │   ├── vcp-verifier/
│   │   │   ├── Cargo.toml
│   │   │   ├── rust-toolchain.toml  # stable + wasm32-unknown-unknown target
│   │   │   └── src/
│   │   │       └── lib.rs           # uses sol_interface! to call Solidity contracts
│   │   └── <future-crate>/
│   │       ├── Cargo.toml
│   │       └── src/
│   │
│   ├── interfaces/                  # Shared Solidity interfaces
│   │   └── IWCustodyNFT.sol         # Interface extracted from WCustodyNFT
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

A symlink `contracts/solidity/interfaces -> ../interfaces` lets Foundry resolve shared interfaces as a local path within the project root, avoiding `../` remapping issues.

Full `foundry.toml`:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.28"

remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "@interfaces/=interfaces/",
]
```

WCustodyNFT imports `@interfaces/IWCustodyNFT.sol` and implements it. ABI JSON output from `forge build` lands in `out/` as usual.

### Stylus (contracts/stylus/)

Each crate depends on `stylus-sdk` (v0.8.4+), `alloy-primitives`, and `alloy-sol-types`. Stylus contracts call Solidity contracts using the `sol_interface!` macro, which declares the target interface inline in Rust using Solidity syntax:

```rust
use stylus_sdk::prelude::*;

sol_interface! {
    interface IWCustodyNFT {
        function mint(address to, string calldata nid, string calldata assetTreeCid,
                      address royaltyReceiver, uint96 royaltyFee) external returns (uint256);
        function ownerOf(uint256 tokenId) external view returns (address);
        function nidOf(uint256 tokenId) external view returns (string);
    }
}
```

This generates type-safe Rust bindings at compile time. No `build.rs`, no ABI JSON files, no dependency on `forge build` output. The `interfaces/IWCustodyNFT.sol` file remains the human-readable canonical reference, and the `sol_interface!` declaration must be kept in sync with it manually (enforced by integration tests).

Cross-contract calls use explicit call constructors:
- `Call::new()` for view/pure calls (`&self`)
- `Call::new_mutating(self)` for state-changing calls (`&mut self`)

Stylus contracts export their own ABI as a Solidity interface via `cargo stylus export-abi`.

### Interface Flow

```
interfaces/IWCustodyNFT.sol  (canonical source of truth for humans)
    │
    ├── symlinked into solidity/interfaces/
    │   └── imported by solidity/src/WCustodyNFT.sol  (implements it)
    │
    └── mirrored as sol_interface! declaration in Rust
        └── used by stylus/vcp-verifier/src/lib.rs (calls it)
```

Integration tests verify that the `sol_interface!` declaration matches the deployed Solidity contract's ABI.

### Integration Tests (contracts/integration/)

A standalone Rust crate (not part of the Stylus workspace) that:

1. Requires a running nitro-testnode (Stylus WASM execution needs a Nitro-compatible devnet; anvil does not support Stylus)
2. Deploys compiled Solidity artifacts (reads ABI/bytecode from `solidity/out/`)
3. Deploys Stylus WASM contracts
4. Tests the full mint flow: CP Verifier validates attestation → calls WCustodyNFT.mint()

Setup requirement: Docker must be running with `nitro-testnode --init`. For Solidity-only tests, `forge test` in `contracts/solidity/` remains the faster path.

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

# Integration (requires nitro-testnode running)
cd contracts/integration
cargo test

# Single test examples
cd contracts/solidity && forge test --match-test test_mint_sets_owner -vv
cd contracts/integration && cargo test vcp_mint_flow -- --nocapture
```

## Migration Plan

One-time migration from the current flat `contracts/` structure:

0. Delete `contracts/out/`, `contracts/cache/`, and `contracts/rust/` (empty placeholder). Remove any tracked build artifacts from git.
1. Move `contracts/{src,test,script,lib,foundry.toml,.gitignore}` → `contracts/solidity/`
2. Move `contracts/README.md` → `contracts/solidity/README.md` (Foundry-specific content)
3. Create `contracts/interfaces/` and extract `IWCustodyNFT.sol` interface from `WCustodyNFT.sol`
4. Create symlink: `contracts/solidity/interfaces -> ../interfaces`
5. Update `foundry.toml` with full config (see Build System section above)
6. Verify `forge build && forge test` pass from `contracts/solidity/`
7. Update `CLAUDE.md` and `README.md` with new paths and commands

The `contracts/stylus/` and `contracts/integration/` directories will be created when CP Verifier development begins. The directory tree above shows the target architecture.

No Stylus code exists yet, so the Cargo workspace and integration crate start as minimal scaffolds.

## Constraints

- Solidity version locked at 0.8.28
- OpenZeppelin v5.6.1 (ERC-721, ERC-2981, AccessControl)
- Stylus contracts target Arbitrum L3
- Token ID scheme (`uint256(keccak256(nid))`) and immutable token URIs are unchanged
- CP Verifier will hold `MINTER_ROLE` on WCustodyNFT
- Dependencies are committed directly (no git submodules), so no `.gitmodules` update needed
