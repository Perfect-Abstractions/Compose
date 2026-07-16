// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Diamond} from "../src/Diamond.sol";
{{IMPORTS}}

contract DeployScript is Script {
    function setUp() public {}

    function run() public returns (Diamond diamond) {
        vm.startBroadcast();

        address[] memory facets = new address[]({{FACET_COUNT}});

        /* Base facet generation. */
{{BASE_LINES}}

        /* Library facet generation. */
{{LIBRARY_LINES}}

        /* Define diamond proxy. */
        diamond = new Diamond(facets);
        console.log("Diamond:", address(diamond));

        vm.stopBroadcast();
    }
}
