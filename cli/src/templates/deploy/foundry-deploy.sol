// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {{{DIAMOND_NAME}}} from "{{DIAMOND_IMPORT}}";
{{IMPORTS}}

contract DeployScript is Script {
    function setUp() public {}

    function run() public returns ({{DIAMOND_NAME}} diamond) {
        vm.startBroadcast();

        address[] memory facets = new address[]({{FACET_COUNT}});

        /* Base facet generation. */
{{BASE_LINES}}{{LIBRARY_SECTION}}

        /* Define diamond proxy. */
        diamond = new {{DIAMOND_NAME}}(facets);
        console.log("Diamond:", address(diamond));

        vm.stopBroadcast();
    }
}
