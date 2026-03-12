# W

Verifiable photo provenance on Arbitrum. Camera Flash Signature (CFS) proves a real camera took a real photo, recorded on-chain with IPFS storage and C2PA metadata.

## Status

Early development. First contract implemented, CFS verifier not yet built.

## Architecture

| Layer | Component |
|-------|-----------|
| Smart Contracts | Custody NFT (ERC-721), Commit, Asset, Collection |
| CFS Verifier | On-chain liveness proof verification (Rust/Stylus) |
| Storage | IPFS/Filecoin for content, Arbitrum L3 for integrity records |
| Camera App | Android 10+, captures with CFS proof and C2PA manifest |

## Contracts

### WCustodyNFT

ERC-721 ownership token for registered media assets.

- Token ID derived from IPFS content hash (`keccak256(nid)`)
- Immutable token URI pointing to original AssetTree on IPFS
- EIP-2981 royalties, updatable by holder
- Minting gated by role (CFS Verifier contract, once built)

Built with Solidity 0.8.28, OpenZeppelin v5.6.1, Foundry.

## Development

Requires [Foundry](https://book.getfoundry.sh/).

```bash
cd contracts
forge build
forge test -vv
```

## License

MIT and GPL-3.0
