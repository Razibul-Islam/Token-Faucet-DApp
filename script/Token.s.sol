// SPDX-Lisence-Identifier: MIT
pragma solidity ^0.8.28;

import {Token} from "../src/Token.sol";
import {Script} from "forge-std/Script.sol";

contract DeployToken is Script {
    function run() external {
        vm.startBroadcast();
        new Token();
        vm.stopBroadcast();
    }
}
