// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IIRLCustodyNFT} from "@interfaces/IIRLCustodyNFT.sol";

/// @title IRLCustodyNFT
/// @notice ERC-721 representing exclusive ownership of a media asset captured with Capture Protocol.
/// @dev One NFT per asset. Token ID = uint256(keccak256(nid)). URI is immutable after mint.
contract IRLCustodyNFT is ERC721, ERC721URIStorage, ERC2981, AccessControl, IIRLCustodyNFT {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(uint256 tokenId => string nid) private _tokenNids;
    mapping(bytes32 nidHash => bool registered) private _registeredNids;

    constructor(address admin) ERC721("IRL Custody", "IRL") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Mint a Custody NFT for a newly registered asset.
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
    ) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        if (to == address(0)) revert InvalidRecipient();
        if (bytes(nid).length == 0) revert InvalidNid();
        if (royaltyFee > 10_000) revert RoyaltyFeeTooHigh(royaltyFee);

        bytes32 nidHash = keccak256(abi.encodePacked(nid));
        tokenId = uint256(nidHash);

        if (_registeredNids[nidHash]) revert AssetAlreadyRegistered(nid);
        _registeredNids[nidHash] = true;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, string.concat("ipfs://", assetTreeCid));
        _setTokenRoyalty(tokenId, royaltyReceiver, royaltyFee);

        _tokenNids[tokenId] = nid;

        emit AssetMinted(tokenId, nid, assetTreeCid, to);
    }

    /// @notice Update royalty info for a token. Only callable by current holder.
    function updateRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTokenHolder(tokenId);
        if (receiver == address(0)) revert InvalidRoyaltyReceiver();
        if (feeNumerator > 10_000) revert RoyaltyFeeTooHigh(feeNumerator);
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit RoyaltyUpdated(tokenId, receiver, feeNumerator);
    }

    /// @notice Get the Nid (IPFS CID) for a token ID.
    function nidOf(uint256 tokenId) external view returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenNotFound(tokenId);
        return _tokenNids[tokenId];
    }

    /// @notice Get the token ID for a Nid.
    function tokenIdOf(string calldata nid) external view returns (uint256) {
        bytes32 nidHash = keccak256(abi.encodePacked(nid));
        if (!_registeredNids[nidHash]) revert NidNotRegistered(nid);
        return uint256(nidHash);
    }

    // --- Required overrides for multiple inheritance ---

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage, ERC2981, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
