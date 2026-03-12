# W Custody NFT Contract — Design Spec

## Summary

ERC-721 smart contract representing exclusive ownership of a media asset captured with W's Camera Flash Signature (CFS). One NFT per asset, minted only when a valid CFS proof is verified on-chain. The holder controls licensing terms and receives royalties.

## Architecture

### Two-Contract Split

| Contract | Language | Purpose |
|----------|----------|---------|
| **Custody NFT** | Solidity | ERC-721 ownership token (this spec) |
| CFS Verifier | Rust/Stylus | On-chain CFS proof verification (future spec) |

The Custody NFT contract calls the CFS Verifier as a prerequisite to minting. For initial development, a mock minter holds the `MINTER_ROLE` until the Stylus contract is built.

### Standards

- ERC-721 (NFT)
- EIP-2981 (royalty info)
- OpenZeppelin AccessControl (role-based permissions)

### Dependencies

- OpenZeppelin Contracts (ERC721, ERC721URIStorage, ERC2981, AccessControl)
- Foundry (build, test, deploy)
- Solidity ^0.8.20

## Token ID Derivation

```
tokenId = uint256(keccak256(abi.encodePacked(nid)))
```

- `nid`: IPFS Content Identifier (CID) string, the canonical asset identity per EIP-7053
- Deterministic: anyone with the file can compute the token ID
- Collision-resistant: keccak256 over unique CIDs

## Minting

- Triggered by an address holding `MINTER_ROLE`
- Inputs: `to` (recipient), `nid` (IPFS CID), `assetTreeCid` (IPFS CID of AssetTree JSON), `royaltyReceiver`, `royaltyFee`
- Reverts if token ID already exists (one mint per Nid)
- Sets token URI to `ipfs://{assetTreeCid}` — permanently immutable after mint
- Sets EIP-2981 royalty for the token

## Token URI

- Format: `ipfs://{assetTreeCid}`
- Set once at mint time
- No update function exists — immutability is enforced by omission
- The URI points to the original AssetTree capturing the moment of creation with CFS proof
- Subsequent asset history (new commits, license changes) lives in the Commit contract

## Royalties

- EIP-2981: returns `(receiver, royaltyAmount)` for a given sale price
- Set at mint time (receiver + fee basis points)
- Updatable by current NFT holder via `updateRoyalty(tokenId, receiver, feeNumerator)`
- Fee numerator is in basis points out of 10000 (e.g., 1000 = 10%)

## Interface

```solidity
// --- Minting (MINTER_ROLE only) ---

/// @notice Mint a Custody NFT for a newly registered asset
/// @param to Recipient address (asset creator)
/// @param nid IPFS Content Identifier of the media file
/// @param assetTreeCid IPFS CID of the AssetTree JSON
/// @param royaltyReceiver Address that receives royalty payments
/// @param royaltyFee Royalty fee in basis points (e.g., 1000 = 10%)
/// @return tokenId The deterministic token ID derived from the nid
function mint(
    address to,
    string calldata nid,
    string calldata assetTreeCid,
    address royaltyReceiver,
    uint96 royaltyFee
) external onlyRole(MINTER_ROLE) returns (uint256 tokenId);

// --- Holder Actions ---

/// @notice Update royalty info for a token (holder only)
function updateRoyalty(
    uint256 tokenId,
    address receiver,
    uint96 feeNumerator
) external;

// --- Lookups ---

/// @notice Get the Nid for a token ID
function nidOf(uint256 tokenId) external view returns (string memory);

/// @notice Get the token ID for a Nid
function tokenIdOf(string calldata nid) external view returns (uint256);
```

## Access Control

| Role | Holder | Permissions |
|------|--------|-------------|
| `DEFAULT_ADMIN_ROLE` | Deployer (W multisig) | Grant/revoke all roles |
| `MINTER_ROLE` | CFS Verifier contract (future); mock minter (testing) | Call `mint` |
| NFT holder | Per-token, checked via `ownerOf` | `updateRoyalty`, `transfer` |

## Constraints

- **One mint per Nid**: `mint` reverts if the derived token ID already exists
- **Non-burnable**: No `burn` function. Custody is permanent; transfer is the only exit
- **No pause**: No admin pause mechanism. Simplicity over admin override
- **Immutable URI**: No `setTokenURI` or equivalent exposed

## Events

```solidity
// Standard ERC-721 events (Transfer, Approval, ApprovalForAll)
// Plus:
event AssetMinted(uint256 indexed tokenId, string nid, string assetTreeCid, address indexed to);
event RoyaltyUpdated(uint256 indexed tokenId, address receiver, uint96 feeNumerator);
```

## Error Cases

| Condition | Revert Reason |
|-----------|--------------|
| Caller lacks `MINTER_ROLE` | `AccessControlUnauthorizedAccount` |
| Token ID already exists | `AssetAlreadyRegistered(nid)` |
| `updateRoyalty` caller is not holder | `NotTokenHolder(tokenId)` |
| `nidOf` for nonexistent token | `TokenNotFound(tokenId)` |
| `tokenIdOf` for unregistered nid | `NidNotRegistered(nid)` |
| `royaltyFee` exceeds 10000 | `RoyaltyFeeTooHigh(feeNumerator)` |
| `to` is zero address | `InvalidRecipient()` |
| `nid` is empty string | `InvalidNid()` |
| `updateRoyalty` receiver is zero address | `InvalidRoyaltyReceiver()` |

## Testing Strategy

- **Unit tests**: Mint, transfer, royalty update, all revert cases
- **Fuzz tests**: Random nid strings produce valid token IDs without collision
- **Integration test**: Mock minter mints, holder updates royalty, marketplace reads EIP-2981
- **Access control tests**: Unauthorized mint reverts, unauthorized royalty update reverts

## File Structure

```
contracts/
  src/
    WCustodyNFT.sol          # Main contract
  test/
    WCustodyNFT.t.sol        # Foundry tests
  script/
    DeployWCustodyNFT.s.sol  # Deployment script
  foundry.toml               # Foundry config
```

## Out of Scope

- CFS Verifier contract (separate spec)
- License NFTs (ERC-1155, separate contract)
- Commit contract
- Royalty splitting to multiple recipients
- Upgradeability (not needed; contract is simple and final)
