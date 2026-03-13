# Contract File Structure Migration Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize `contracts/` from a flat Foundry project into a monorepo structure supporting both Solidity (Foundry) and Arbitrum Stylus (Rust) contracts with shared interfaces.

**Architecture:** Move existing Solidity files into `contracts/solidity/`, extract a shared `IWCustodyNFT.sol` interface into `contracts/interfaces/`, and create a symlink so Foundry can resolve it. Stylus and integration directories are deferred until CP Verifier development begins.

**Tech Stack:** Foundry (Solidity 0.8.28), OpenZeppelin v5.6.1, forge-std

**Spec:** `docs/superpowers/specs/2026-03-13-contract-file-structure-design.md`

---

## File Map

**Files to move:**
- `contracts/src/WCustodyNFT.sol` → `contracts/solidity/src/WCustodyNFT.sol`
- `contracts/test/WCustodyNFT.t.sol` → `contracts/solidity/test/WCustodyNFT.t.sol`
- `contracts/script/DeployWCustodyNFT.s.sol` → `contracts/solidity/script/DeployWCustodyNFT.s.sol`
- `contracts/lib/` → `contracts/solidity/lib/`
- `contracts/foundry.toml` → `contracts/solidity/foundry.toml`
- `contracts/.gitignore` → `contracts/solidity/.gitignore`
- `contracts/README.md` → `contracts/solidity/README.md`

**Files to delete:**
- `contracts/out/` (build artifacts, regenerated)
- `contracts/cache/` (build cache, regenerated)
- `contracts/rust/` (empty placeholder)

**Files to create:**
- `contracts/interfaces/IWCustodyNFT.sol` (extracted interface)
- `contracts/solidity/interfaces` (symlink → `../interfaces`)

**Files to modify:**
- `contracts/solidity/foundry.toml` (add `@interfaces/` remapping)
- `contracts/solidity/src/WCustodyNFT.sol` (import and implement interface)
- `CLAUDE.md` (update paths and build commands)
- `README.md` (update paths and build commands)

---

## Chunk 1: Clean Up and Move Files

### Task 1: Delete build artifacts and empty directories

**Files:**
- Delete: `contracts/out/`, `contracts/cache/`, `contracts/rust/`

- [ ] **Step 1: Remove tracked build artifacts from git**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git rm -r --cached contracts/out/ 2>/dev/null; true
git rm -r --cached contracts/cache/ 2>/dev/null; true
```

Expected: files removed from index (or "did not match any files" if already untracked)

- [ ] **Step 2: Delete the directories**

```bash
trash contracts/out contracts/cache contracts/rust
```

- [ ] **Step 3: Verify clean state**

```bash
ls contracts/
```

Expected: `lib/  script/  src/  test/  foundry.toml  .gitignore  README.md`

- [ ] **Step 4: Commit**

```bash
git add contracts/out contracts/cache contracts/rust
git commit -m "Remove build artifacts and empty rust/ placeholder"
```

---

### Task 2: Move Foundry project into contracts/solidity/

**Files:**
- Move: `contracts/{src,test,script,lib,foundry.toml,.gitignore,README.md}` → `contracts/solidity/`

- [ ] **Step 1: Create the solidity directory and move files**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
mkdir -p contracts/solidity
git mv contracts/src contracts/solidity/src
git mv contracts/test contracts/solidity/test
git mv contracts/script contracts/solidity/script
git mv contracts/lib contracts/solidity/lib
git mv contracts/foundry.toml contracts/solidity/foundry.toml
git mv contracts/.gitignore contracts/solidity/.gitignore
git mv contracts/README.md contracts/solidity/README.md
```

- [ ] **Step 2: Verify the move**

```bash
ls contracts/solidity/
```

Expected: `lib/  script/  src/  test/  foundry.toml  .gitignore  README.md`

```bash
ls contracts/
```

Expected: `solidity/` (only subdirectory remaining)

- [ ] **Step 3: Verify Foundry still builds from new location**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code/contracts/solidity
forge build
```

Expected: compilation succeeds, `out/` directory created

- [ ] **Step 4: Verify all tests pass**

```bash
forge test -vv
```

Expected: all tests pass (same results as before the move)

- [ ] **Step 5: Commit**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git add contracts/
git commit -m "Move Foundry project into contracts/solidity/"
```

---

## Chunk 2: Extract Interface and Create Symlink

### Task 3: Create the shared IWCustodyNFT interface

**Files:**
- Create: `contracts/interfaces/IWCustodyNFT.sol`

The interface must match the public API of `WCustodyNFT.sol` exactly. It includes all external/public functions, events, and custom errors that external callers need.

- [ ] **Step 1: Create interfaces directory**

```bash
mkdir -p /Users/allup/Nextcloud/orgmode/w/w-code/contracts/interfaces
```

- [ ] **Step 2: Write the interface file**

Create `contracts/interfaces/IWCustodyNFT.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IWCustodyNFT
/// @notice Interface for the W Custody NFT contract.
interface IWCustodyNFT {
    event AssetMinted(uint256 indexed tokenId, string nid, string assetTreeCid, address indexed to);
    event RoyaltyUpdated(uint256 indexed tokenId, address receiver, uint96 feeNumerator);

    error AssetAlreadyRegistered(string nid);
    error NotTokenHolder(uint256 tokenId);
    error TokenNotFound(uint256 tokenId);
    error NidNotRegistered(string nid);
    error InvalidRecipient();
    error InvalidNid();
    error InvalidRoyaltyReceiver();
    error RoyaltyFeeTooHigh(uint96 feeNumerator);

    function mint(
        address to,
        string calldata nid,
        string calldata assetTreeCid,
        address royaltyReceiver,
        uint96 royaltyFee
    ) external returns (uint256 tokenId);

    function updateRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external;

    function nidOf(uint256 tokenId) external view returns (string memory);

    function tokenIdOf(string calldata nid) external view returns (uint256);
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git add contracts/interfaces/IWCustodyNFT.sol
git commit -m "Extract IWCustodyNFT interface into shared interfaces/"
```

---

### Task 4: Create symlink and update Foundry config

**Files:**
- Create: `contracts/solidity/interfaces` (symlink)
- Modify: `contracts/solidity/foundry.toml`

- [ ] **Step 1: Create the symlink**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code/contracts/solidity
ln -s ../interfaces interfaces
```

- [ ] **Step 2: Verify symlink resolves**

```bash
ls -la contracts/solidity/interfaces/
```

Expected: shows `IWCustodyNFT.sol`

- [ ] **Step 3: Update foundry.toml to add the interfaces remapping**

Replace the full contents of `contracts/solidity/foundry.toml` with:

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

- [ ] **Step 4: Verify Foundry resolves the new remapping**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code/contracts/solidity
forge build
```

Expected: compilation succeeds

- [ ] **Step 5: Commit**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git add contracts/solidity/interfaces contracts/solidity/foundry.toml
git commit -m "Add interfaces symlink and @interfaces/ remapping to foundry.toml"
```

---

### Task 5: Update WCustodyNFT to import the interface

**Files:**
- Modify: `contracts/solidity/src/WCustodyNFT.sol`

WCustodyNFT should import and implement the extracted interface. This ensures the contract stays in sync with the canonical interface.

- [ ] **Step 1: Add import and `is IWCustodyNFT` to WCustodyNFT.sol**

Add this import after the existing imports:

```solidity
import {IWCustodyNFT} from "@interfaces/IWCustodyNFT.sol";
```

Add `IWCustodyNFT` to the contract's inheritance list:

```solidity
contract WCustodyNFT is ERC721, ERC721URIStorage, ERC2981, AccessControl, IWCustodyNFT {
```

Note: The contract already implements all the functions declared in the interface. Adding `is IWCustodyNFT` makes this explicit and will cause a compile error if the interface and implementation drift apart.

Since `IWCustodyNFT` declares the same events and errors, remove the duplicate declarations from the contract body (the ones from the interface are inherited). Specifically, remove these lines from `WCustodyNFT.sol`:

```solidity
    event AssetMinted(uint256 indexed tokenId, string nid, string assetTreeCid, address indexed to);
    event RoyaltyUpdated(uint256 indexed tokenId, address receiver, uint96 feeNumerator);

    error AssetAlreadyRegistered(string nid);
    error NotTokenHolder(uint256 tokenId);
    error TokenNotFound(uint256 tokenId);
    error NidNotRegistered(string nid);
    error InvalidRecipient();
    error InvalidNid();
    error InvalidRoyaltyReceiver();
    error RoyaltyFeeTooHigh(uint96 feeNumerator);
```

- [ ] **Step 2: Verify compilation**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code/contracts/solidity
forge build
```

Expected: compilation succeeds with no errors

- [ ] **Step 3: Run full test suite**

```bash
forge test -vv
```

Expected: all tests pass. No test changes needed — `WCustodyNFT.AssetMinted`, `WCustodyNFT.AssetAlreadyRegistered`, etc. resolve to the inherited declarations from `IWCustodyNFT`. Solidity 0.8.28 allows referring to inherited events/errors via the derived contract name.

- [ ] **Step 4: Commit**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git add contracts/solidity/src/WCustodyNFT.sol
git commit -m "Implement IWCustodyNFT interface in WCustodyNFT"
```

---

## Chunk 3: Update Documentation

### Task 6: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update build commands section**

Replace the Build Commands section with:

```markdown
## Build Commands

\```bash
# From contracts/solidity/ directory:
forge build              # Compile all contracts
forge test -vv           # Run all tests (verbose)
forge test --gas-report  # Run tests with gas analysis
forge build --sizes      # Check contract sizes vs 24KB limit

# Run a single test:
forge test --match-test test_mint_sets_owner -vv

# Run fuzz tests only:
forge test --match-test testFuzz -vv
\```
```

- [ ] **Step 2: Update Smart Contracts section**

Update the path reference from:

```
### WCustodyNFT (`contracts/src/WCustodyNFT.sol`)
```

to:

```
### WCustodyNFT (`contracts/solidity/src/WCustodyNFT.sol`)
```

- [ ] **Step 3: Update Design Documents section**

Change:

```
- `contracts/` — Foundry project with Solidity smart contracts
```

to:

```
- `contracts/solidity/` — Foundry project with Solidity smart contracts
- `contracts/interfaces/` — Shared Solidity interfaces (consumed by both Foundry and Stylus)
```

- [ ] **Step 4: Add contract structure note**

Add after the Smart Contracts section heading:

```markdown
### Contract Directory Structure

\```
contracts/
├── solidity/          # Foundry project (Solidity contracts)
│   ├── src/           # Contract sources
│   ├── test/          # Forge tests
│   ├── script/        # Deploy scripts
│   ├── lib/           # Dependencies (OpenZeppelin, forge-std)
│   ├── interfaces/    # Symlink → ../interfaces
│   └── foundry.toml
├── interfaces/        # Shared Solidity interfaces
│   └── IWCustodyNFT.sol
├── stylus/            # (future) Cargo workspace for Rust/Stylus contracts
└── integration/       # (future) Cross-language integration tests
\```
```

- [ ] **Step 5: Commit**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git add CLAUDE.md
git commit -m "Update CLAUDE.md with new contract directory structure"
```

---

### Task 7: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README.md**

The README currently references CFS (outdated) and has `cd contracts`. Update:

1. Replace "Camera Flash Signature (CFS)" references with "Capture Protocol (CP)" in the description
2. Replace "CFS Verifier" with "CP Verifier" in the architecture table
3. Replace "CFS proof" with "CP attestation"
4. Update the build commands from `cd contracts` to `cd contracts/solidity`
5. Update "Minting gated by role (CFS Verifier contract, once built)" to "Minting gated by role (CP Verifier Stylus contract, once built)"

- [ ] **Step 2: Commit**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git add README.md
git commit -m "Update README.md with new paths and CP terminology"
```

---

### Task 8: Update root .gitignore

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Update broadcast path and add Rust patterns**

In `.gitignore`, change `contracts/broadcast/` to `contracts/solidity/broadcast/` and add Rust patterns:

```gitignore
# Foundry (contracts/solidity/ has its own .gitignore for cache/out)
contracts/solidity/broadcast/

# Rust/Stylus (for future contracts/stylus/)
target/
```

- [ ] **Step 2: Commit**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git add .gitignore
git commit -m "Update .gitignore: fix broadcast path, add Rust target/"
```

---

## Chunk 4: Final Verification

### Task 9: End-to-end verification

- [ ] **Step 1: Clean build from scratch**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code/contracts/solidity
trash out cache 2>/dev/null; true
forge build
```

Expected: compilation succeeds, `out/` regenerated

- [ ] **Step 2: Full test suite**

```bash
forge test -vv
```

Expected: all tests pass

- [ ] **Step 3: Gas report**

```bash
forge test --gas-report
```

Expected: gas report prints, no errors

- [ ] **Step 4: Contract size check**

```bash
forge build --sizes
```

Expected: WCustodyNFT under 24KB limit

- [ ] **Step 5: Verify directory structure matches spec**

```bash
find /Users/allup/Nextcloud/orgmode/w/w-code/contracts -maxdepth 2 -not -path '*/lib/*' -not -path '*/out/*' -not -path '*/cache/*' | sort
```

Expected:
```
contracts/
contracts/interfaces
contracts/interfaces/IWCustodyNFT.sol
contracts/solidity
contracts/solidity/.gitignore
contracts/solidity/foundry.toml
contracts/solidity/interfaces       (symlink)
contracts/solidity/lib
contracts/solidity/out
contracts/solidity/README.md
contracts/solidity/script
contracts/solidity/src
contracts/solidity/test
```

- [ ] **Step 6: Verify symlink is intact**

```bash
readlink /Users/allup/Nextcloud/orgmode/w/w-code/contracts/solidity/interfaces
```

Expected: `../interfaces`

- [ ] **Step 7: Final commit if any uncommitted changes remain**

```bash
cd /Users/allup/Nextcloud/orgmode/w/w-code
git status
```

Expected: clean working tree. If not, stage and commit remaining changes.
