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
