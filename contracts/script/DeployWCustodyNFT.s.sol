// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {WCustodyNFT} from "../src/WCustodyNFT.sol";

contract DeployWCustodyNFT is Script {
    function run() public {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        vm.startBroadcast();
        WCustodyNFT nft = new WCustodyNFT(admin);
        console.log("WCustodyNFT deployed at:", address(nft));
        vm.stopBroadcast();
    }
}
