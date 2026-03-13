// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IRLCustodyNFT} from "../src/IRLCustodyNFT.sol";
import {IIRLCustodyNFT} from "@interfaces/IIRLCustodyNFT.sol";

contract IRLCustodyNFTTest is Test {
    IRLCustodyNFT public nft;
    address public admin = address(1);
    address public minter = address(2);
    address public creator = address(3);
    address public other = address(4);

    string constant NID = "bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq";
    string constant ASSET_TREE_CID = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";

    function setUp() public {
        vm.startPrank(admin);
        nft = new IRLCustodyNFT(admin);
        nft.grantRole(nft.MINTER_ROLE(), minter);
        vm.stopPrank();
    }

    // --- Mint ---

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
        emit IIRLCustodyNFT.AssetMinted(expected, NID, ASSET_TREE_CID, creator);
        nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
    }

    // --- Lookups ---

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

    // --- Royalties ---

    function test_royaltyInfo_returns_correct_values() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        (address receiver, uint256 amount) = nft.royaltyInfo(tokenId, 10_000);
        assertEq(receiver, creator);
        assertEq(amount, 1000);
    }

    function test_updateRoyalty_by_holder() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(creator);
        nft.updateRoyalty(tokenId, other, 500);
        (address receiver, uint256 amount) = nft.royaltyInfo(tokenId, 10_000);
        assertEq(receiver, other);
        assertEq(amount, 500);
    }

    function test_updateRoyalty_emits_event() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(creator);
        vm.expectEmit(true, false, false, true);
        emit IIRLCustodyNFT.RoyaltyUpdated(tokenId, other, 500);
        nft.updateRoyalty(tokenId, other, 500);
    }

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
        vm.expectRevert(abi.encodeWithSelector(IIRLCustodyNFT.AssetAlreadyRegistered.selector, NID));
        nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
    }

    function test_mint_reverts_zero_address() public {
        vm.prank(minter);
        vm.expectRevert(IIRLCustodyNFT.InvalidRecipient.selector);
        nft.mint(address(0), NID, ASSET_TREE_CID, creator, 1000);
    }

    function test_mint_reverts_empty_nid() public {
        vm.prank(minter);
        vm.expectRevert(IIRLCustodyNFT.InvalidNid.selector);
        nft.mint(creator, "", ASSET_TREE_CID, creator, 1000);
    }

    function test_mint_reverts_royalty_too_high() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IIRLCustodyNFT.RoyaltyFeeTooHigh.selector, uint96(10_001)));
        nft.mint(creator, NID, ASSET_TREE_CID, creator, 10_001);
    }

    function test_updateRoyalty_reverts_non_holder() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(IIRLCustodyNFT.NotTokenHolder.selector, tokenId));
        nft.updateRoyalty(tokenId, other, 500);
    }

    function test_updateRoyalty_reverts_fee_too_high() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(IIRLCustodyNFT.RoyaltyFeeTooHigh.selector, uint96(10_001)));
        nft.updateRoyalty(tokenId, creator, 10_001);
    }

    function test_updateRoyalty_reverts_zero_receiver() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, NID, ASSET_TREE_CID, creator, 1000);
        vm.prank(creator);
        vm.expectRevert(IIRLCustodyNFT.InvalidRoyaltyReceiver.selector);
        nft.updateRoyalty(tokenId, address(0), 500);
    }

    function test_nidOf_reverts_nonexistent_token() public {
        vm.expectRevert(abi.encodeWithSelector(IIRLCustodyNFT.TokenNotFound.selector, uint256(999)));
        nft.nidOf(999);
    }

    function test_tokenIdOf_reverts_unregistered_nid() public {
        vm.expectRevert(abi.encodeWithSelector(IIRLCustodyNFT.NidNotRegistered.selector, "bafyunknown"));
        nft.tokenIdOf("bafyunknown");
    }

    // --- ERC-165 interface support ---

    function test_supports_ERC721() public view {
        assertTrue(nft.supportsInterface(0x80ac58cd));
    }

    function test_supports_ERC2981() public view {
        assertTrue(nft.supportsInterface(0x2a55205a));
    }

    function test_supports_AccessControl() public view {
        assertTrue(nft.supportsInterface(0x7965db0b));
    }

    // --- Fuzz ---

    function testFuzz_mint_token_id_is_deterministic(string calldata randomNid) public {
        vm.assume(bytes(randomNid).length > 0);
        uint256 expected = uint256(keccak256(abi.encodePacked(randomNid)));
        vm.prank(minter);
        uint256 tokenId = nft.mint(creator, randomNid, ASSET_TREE_CID, creator, 1000);
        assertEq(tokenId, expected);
    }
}
