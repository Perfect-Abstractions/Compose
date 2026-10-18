// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CustomDiamond} from "../../src/proxy/Proxy.sol";
import {LocalFacet} from "../../src/nested/counter/LocalFacet.sol";
import {PackageFacet} from "../../node_modules/sample-facets/PackageFacet.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public returns (CustomDiamond diamond) {
        vm.startBroadcast();

        address[] memory facets = new address[](2);

        /* Base facet generation. */
        facets[0] = address(new LocalFacet());
        console.log("LocalFacet:", facets[0]);
        facets[1] = address(new PackageFacet());
        console.log("PackageFacet:", facets[1]);

        /* Define diamond proxy. */
        diamond = new CustomDiamond(facets);
        console.log("Diamond:", address(diamond));

        vm.stopBroadcast();
    }
}
