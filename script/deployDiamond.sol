// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* Compose
 * https://compose.diamonds
 */

import {Script} from "forge-std/Script.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();
    }
}
