// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* Compose
 * https://compose.diamonds
 */

import {Script} from "forge-std/Script.sol";
import {ERC20Facet} from "../src/token/ERC20/ERC20/ERC20Facet.sol";

contract CounterScript is Script {
    ERC20Facet public erc20;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        erc20 = new ERC20Facet();

        vm.stopBroadcast();
    }
}
