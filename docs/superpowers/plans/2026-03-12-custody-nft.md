# IRL Custody NFT Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the IRLCustodyNFT ERC-721 contract with deterministic token IDs, immutable URI, EIP-2981 royalties, and role-based minting.

**Architecture:** Single Solidity contract inheriting OpenZeppelin ERC721URIStorage, ERC2981, and AccessControl. Token IDs derived from keccak256 of IPFS CID. Minting gated by MINTER_ROLE. Foundry for build/test/deploy.

**Tech Stack:** Solidity 0.8.28, OpenZeppelin Contracts v5.6.1, Foundry

---

## File Structure

```
contracts/
  src/
    IRLCustodyNFT.sol          # Main contract
  test/
    IRLCustodyNFT.t.sol        # Foundry tests
  script/
    DeployIRLCustodyNFT.s.sol  # Deployment script
  foundry.toml               # Foundry config
```

---

## Chunk 1: Project Scaffolding

### Task 1: Initialize Foundry project

**Files:**
- Create: `contracts/foundry.toml`
- Create: `contracts/src/.gitkeep` (removed after first real file)
- Create: `contracts/test/.gitkeep` (removed after first real file)
- Create: `contracts/script/.gitkeep` (removed after first real file)

- [ ] **Step 1: Initialize Foundry in contracts/**

```bash
cd /Users/allup/dev/w/w/contracts
forge init --no-git --no-commit
```

This creates `foundry.toml`, `src/Counter.sol`, `test/Counter.t.sol`, `script/Counter.s.sol`.

- [ ] **Step 2: Remove boilerplate files**

```bash
rm contracts/src/Counter.sol contracts/test/Counter.t.sol contracts/script/Counter.s.sol
```

- [ ] **Step 3: Install OpenZeppelin Contracts**

```bash
cd /Users/allup/dev/w/w/contracts
forge install OpenZeppelin/openzeppelin-contracts@v5.6.1 --no-git --no-commit
```

- [ ] **Step 4: Configure remappings**

Add to `contracts/foundry.toml`:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.28"

remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
]
```

- [ ] **Step 5: Verify build works**

```bash
cd /Users/allup/dev/w/w/contracts
forge build
```

Expected: builds successfully (no source files yet, but no errors).

- [ ] **Step 6: Commit**

```bash
git add contracts/
git commit -m "Initialize Foundry project with OpenZeppelin v5.6.1"
```

---

## Chunk 2: Contract Implementation (TDD)

### Task 2: Write failing test — mint and token ID derivation

**Files:**
- Create: `contracts/test/IRLCustodyNFT.t.sol`

- [ ] **Step 1: Write the failing test file**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IRLCustodyNFT} from "../src/IRLCustodyNFT.sol";

contract IRLCustodyNFTTest is Test {
    IRLCustodyNFT public nft;
    address public admin = address(1);
    address public minter = address(2);
    address public creator = address(3);
    address public other = address(4);

    string constant NID = "bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq";
    string constant ASSET_TREE_CID = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";

    function setUp() public {
        vm.prank(admin);
        nft = new IRLCustodyNFT(admin);
        vm.prank(admin);
        nft.grantRole(nft.MINTER_ROLE(), minter);
    }

    function test_mint_sets_owner() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        assertEq(nft.ownerOf(tokenId), creator);
    }

    function test_mint_returns_deterministic_token_id() public {
        uint256 expected = uint256(keccak256(abi.encodePacked(NID)));
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        assertEq(tokenId, expected);
    }

    function test_mint_sets_token_uri() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        assertEq(nft.tokenURI(tokenId), string.concat("ipfs://", ASSET_TREE_CID));
    }

    function test_mint_emits_AssetMinted() public {
        uint256 expected = uint256(keccak256(abi.encodePacked(NID)));
        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit IRLCustodyNFT.AssetMinted(expected, NID, ASSET_TREE_CID, creator);
        nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/allup/dev/w/w/contracts
forge test -vv
```

Expected: compilation error — `IRLCustodyNFT` does not exist yet.

### Task 3: Implement IRLCustodyNFT — mint and core storage

**Files:**
- Create: `contracts/src/IRLCustodyNFT.sol`

- [ ] **Step 3: Write the contract**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract IRLCustodyNFT is ERC721, ERC721URIStorage, ERC2981, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(uint256 tokenId => string nid) private _tokenNids;
    mapping(bytes32 nidHash => bool registered) private _registeredNids;

    event AssetMinted(uint256 indexed tokenId, string nid, string assetTreeCid, address indexed to);
    event RoyaltyUpdated(uint256 indexed tokenId, address receiver, uint96 feeNumerator);

    error AssetAlreadyRegistered(string nid);
    error NotTokenHolder(uint256 tokenId);
    error InvalidRecipient();
    error InvalidNid();
    error RoyaltyFeeTooHigh(uint96 feeNumerator);
    error AssetNotFound();

    constructor(address admin) ERC721("IRL Custody", "IRL") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(
        address to,
        string calldata nid,
        string calldata assetTreeCid,
        address royaltyReceiver,
        uint96 royaltyFee
    ) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        if (to == address(0)) revert InvalidRecipient();
        if (bytes(nid).length == 0) revert InvalidNid();
        if (royaltyFee > 10000) revert RoyaltyFeeTooHigh(royaltyFee);

        tokenId = uint256(keccak256(abi.encodePacked(nid)));
        bytes32 nidHash = keccak256(abi.encodePacked(nid));

        if (_registeredNids[nidHash]) revert AssetAlreadyRegistered(nid);
        _registeredNids[nidHash] = true;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, string.concat("ipfs://", assetTreeCid));
        _setTokenRoyalty(tokenId, royaltyReceiver, royaltyFee);

        _tokenNids[tokenId] = nid;

        emit AssetMinted(tokenId, nid, assetTreeCid, to);
    }

    function updateRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTokenHolder(tokenId);
        if (feeNumerator > 10000) revert RoyaltyFeeTooHigh(feeNumerator);
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit RoyaltyUpdated(tokenId, receiver, feeNumerator);
    }

    function nidOf(uint256 tokenId) external view returns (string memory) {
        _requireOwned(tokenId);
        return _tokenNids[tokenId];
    }

    function tokenIdOf(string calldata nid) external view returns (uint256) {
        bytes32 nidHash = keccak256(abi.encodePacked(nid));
        if (!_registeredNids[nidHash]) revert AssetNotFound();
        return uint256(keccak256(abi.encodePacked(nid)));
    }

    // --- Required overrides for multiple inheritance ---

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC2981, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/allup/dev/w/w/contracts
forge test -vv
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add contracts/src/IRLCustodyNFT.sol contracts/test/IRLCustodyNFT.t.sol
git commit -m "Add IRLCustodyNFT contract with mint, token ID derivation, and URI"
```

---

### Task 4: Write failing tests — lookups and royalties

**Files:**
- Modify: `contracts/test/IRLCustodyNFT.t.sol`

- [ ] **Step 1: Add lookup and royalty tests**

Append to the test contract:

```solidity
    function test_nidOf_returns_nid() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        assertEq(nft.nidOf(tokenId), NID);
    }

    function test_tokenIdOf_returns_token_id() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        assertEq(nft.tokenIdOf(NID), tokenId);
    }

    function test_royaltyInfo_returns_correct_values() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        (address receiver, uint256 amount) = nft.royaltyInfo(tokenId, 10000);
        assertEq(receiver, creator);
        assertEq(amount, 1000); // 10% of 10000
    }

    function test_updateRoyalty_by_holder() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(creator);
        nft.updateRoyalty(tokenId, other, 500);
        (address receiver, uint256 amount) = nft.royaltyInfo(tokenId, 10000);
        assertEq(receiver, other);
        assertEq(amount, 500); // 5% of 10000
    }

    function test_updateRoyalty_emits_event() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(creator);
        vm.expectEmit(true, false, false, true);
        emit IRLCustodyNFT.RoyaltyUpdated(tokenId, other, 500);
        nft.updateRoyalty(tokenId, other, 500);
    }
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/allup/dev/w/w/contracts
forge test -vv
```

Expected: all 9 tests PASS (implementation already supports these).

- [ ] **Step 3: Commit**

```bash
git add contracts/test/IRLCustodyNFT.t.sol
git commit -m "Add lookup and royalty tests for IRLCustodyNFT"
```

---

### Task 5: Write failing tests — all revert cases

**Files:**
- Modify: `contracts/test/IRLCustodyNFT.t.sol`

- [ ] **Step 1: Add revert tests**

Append to the test contract:

```solidity
    // --- Revert cases ---

    function test_mint_reverts_without_minter_role() public {
        vm.prank(other);
        vm.expectRevert();
        nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
    }

    function test_mint_reverts_duplicate_nid() public {
        vm.prank(minter);
        nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IRLCustodyNFT.AssetAlreadyRegistered.selector, NID));
        nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
    }

    function test_mint_reverts_zero_address() public {
        vm.prank(minter);
        vm.expectRevert(IRLCustodyNFT.InvalidRecipient.selector);
        nft.mint(address(0), NID, ASSET_TREE_CID, creator, 1000);
    }

    function test_mint_reverts_empty_nid() public {
        vm.prank(minter);
        vm.expectRevert(IRLCustodyNFT.InvalidNid.selector);
        nft.mint(creator, "", ASSET_TREE_CID, creator, 1000);
    }

    function test_mint_reverts_royalty_too_high() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IRLCustodyNFT.RoyaltyFeeTooHigh.selector, uint96(10001)));
        nft.mint(creator, NID, ASSET_TREE_CID, creator, 10001);
    }

    function test_updateRoyalty_reverts_non_holder() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(IRLCustodyNFT.NotTokenHolder.selector, tokenId));
        nft.updateRoyalty(tokenId, other, 500);
    }

    function test_updateRoyalty_reverts_fee_too_high() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(IRLCustodyNFT.RoyaltyFeeTooHigh.selector, uint96(10001)));
        nft.updateRoyalty(tokenId, creator, 10001);
    }

    function test_nidOf_reverts_nonexistent_token() public {
        vm.expectRevert();
        nft.nidOf(999);
    }

    function test_tokenIdOf_reverts_unregistered_nid() public {
        vm.expectRevert(IRLCustodyNFT.AssetNotFound.selector);
        nft.tokenIdOf("bafyunknown");
    }
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/allup/dev/w/w/contracts
forge test -vv
```

Expected: all 18 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add contracts/test/IRLCustodyNFT.t.sol
git commit -m "Add revert case tests for IRLCustodyNFT"
```

---

### Task 6: Write fuzz test — token ID determinism

**Files:**
- Modify: `contracts/test/IRLCustodyNFT.t.sol`

- [ ] **Step 1: Add fuzz test**

Append to the test contract:

```solidity
    // --- Fuzz tests ---

    function testFuzz_mint_token_id_is_deterministic(string calldata randomNid) public {
        vm.assume(bytes(randomNid).length > 0);
        uint256 expected = uint256(keccak256(abi.encodePacked(randomNid)));
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, randomNid, ASSET_TREE_CID, creator, 1000);
        assertEq(tokenId, expected);
    }
```

- [ ] **Step 2: Run fuzz tests**

```bash
cd /Users/allup/dev/w/w/contracts
forge test -vv --match-test testFuzz
```

Expected: PASS (256 runs by default).

- [ ] **Step 3: Commit**

```bash
git add contracts/test/IRLCustodyNFT.t.sol
git commit -m "Add fuzz test for token ID determinism"
```

---

## Chunk 3: ERC-165 and Deployment

### Task 7: Write ERC-165 interface support test

**Files:**
- Modify: `contracts/test/IRLCustodyNFT.t.sol`

- [ ] **Step 1: Add interface support tests**

Append to the test contract:

```solidity
    // --- Interface support ---

    function test_supports_ERC721() public view {
        assertTrue(nft.supportsInterface(0x80ac58cd)); // ERC-721
    }

    function test_supports_ERC2981() public view {
        assertTrue(nft.supportsInterface(0x2a55205a)); // ERC-2981
    }

    function test_supports_AccessControl() public view {
        assertTrue(nft.supportsInterface(0x7965db0b)); // AccessControl
    }
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/allup/dev/w/w/contracts
forge test -vv
```

Expected: all 22 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add contracts/test/IRLCustodyNFT.t.sol
git commit -m "Add ERC-165 interface support tests"
```

---

### Task 8: Write deployment script

**Files:**
- Create: `contracts/script/DeployIRLCustodyNFT.s.sol`

- [ ] **Step 1: Write the deployment script**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IRLCustodyNFT} from "../src/IRLCustodyNFT.sol";

contract DeployIRLCustodyNFT is Script {
    function run() public {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        vm.startBroadcast();
        IRLCustodyNFT nft = new IRLCustodyNFT(admin);
        console.log("IRLCustodyNFT deployed at:", address(nft));
        vm.stopBroadcast();
    }
}
```

- [ ] **Step 2: Verify script compiles**

```bash
cd /Users/allup/dev/w/w/contracts
forge build
```

Expected: compiles without errors.

- [ ] **Step 3: Commit**

```bash
git add contracts/script/DeployIRLCustodyNFT.s.sol
git commit -m "Add IRLCustodyNFT deployment script"
```

---

### Task 9: Final verification

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/allup/dev/w/w/contracts
forge test -vvv
```

Expected: 22 tests PASS, 0 failures.

- [ ] **Step 2: Check gas report**

```bash
cd /Users/allup/dev/w/w/contracts
forge test --gas-report
```

Review gas costs for `mint` and `updateRoyalty`.

- [ ] **Step 3: Run full build**

```bash
cd /Users/allup/dev/w/w/contracts
forge build --sizes
```

Verify contract size is well under the 24KB limit.
