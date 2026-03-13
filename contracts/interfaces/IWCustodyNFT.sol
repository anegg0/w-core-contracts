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
