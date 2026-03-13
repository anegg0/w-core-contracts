# IRL

Verifiable photo provenance on Arbitrum. Capture Protocol (CP) provides strong evidence a real camera took a real photo, recorded on-chain with IPFS storage and C2PA metadata.

## Status

Early development. First contract implemented, CP Verifier not yet built.

## Architecture

| Layer | Component |
|-------|-----------|
| Smart Contracts | Custody NFT (ERC-721), Commit, Asset, Collection |
| CP Verifier | On-chain attestation verification (Rust/Stylus) |
| Storage | IPFS/Filecoin for content, Arbitrum L3 for integrity records |
| Camera App | iOS-first, captures with CP attestation and C2PA manifest |

## Contracts

### IRLCustodyNFT

ERC-721 ownership token for registered media assets.

- Token ID derived from IPFS content hash (`keccak256(nid)`)
- Immutable token URI pointing to original AssetTree on IPFS
- EIP-2981 royalties, updatable by holder
- Minting gated by role (CP Verifier Stylus contract, once built)

Built with Solidity 0.8.28, OpenZeppelin v5.6.1, Foundry.

## Development

Requires [Foundry](https://book.getfoundry.sh/).

```bash
cd contracts/solidity
forge build
forge test -vv
```

## License

MIT and GPL-3.0
