// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Diamond} from "../src/Diamond.sol";
import {ERC20DataFacet} from "@perfect-abstractions/compose/token/ERC20/Data/ERC20DataFacet.sol";
import {ERC20ApproveFacet} from "@perfect-abstractions/compose/token/ERC20/Approve/ERC20ApproveFacet.sol";
import {ERC20TransferFacet} from "@perfect-abstractions/compose/token/ERC20/Transfer/ERC20TransferFacet.sol";
import {ERC20BurnFacet} from "@perfect-abstractions/compose/token/ERC20/Burn/ERC20BurnFacet.sol";
import {ERC20MetadataFacet} from "@perfect-abstractions/compose/token/ERC20/Metadata/ERC20MetadataFacet.sol";
import {ERC20PermitFacet} from "@perfect-abstractions/compose/token/ERC20/Permit/ERC20PermitFacet.sol";
import {DiamondInspectFacet} from "@perfect-abstractions/compose/diamond/DiamondInspectFacet.sol";
import {OwnerDataFacet} from "@perfect-abstractions/compose/access/Owner/Data/OwnerDataFacet.sol";
import {OwnerTransferFacet} from "@perfect-abstractions/compose/access/Owner/Transfer/OwnerTransferFacet.sol";
import {AccessControlDataFacet} from "@perfect-abstractions/compose/access/AccessControl/Data/AccessControlDataFacet.sol";
import {AccessControlGrantFacet} from "@perfect-abstractions/compose/access/AccessControl/Grant/AccessControlGrantFacet.sol";
import {AccessControlRevokeFacet} from "@perfect-abstractions/compose/access/AccessControl/Revoke/AccessControlRevokeFacet.sol";
import {DiamondUpgradeFacet} from "@perfect-abstractions/compose/diamond/DiamondUpgradeFacet.sol";
import {OwnerRenounceFacet} from "@perfect-abstractions/compose/access/Owner/Renounce/OwnerRenounceFacet.sol";
import {AccessControlGrantBatchFacet} from "@perfect-abstractions/compose/access/AccessControl/Batch/Grant/AccessControlGrantBatchFacet.sol";
import {AccessControlRevokeBatchFacet} from "@perfect-abstractions/compose/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchFacet.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public returns (Diamond diamond) {
        vm.startBroadcast();

        address[] memory facets = new address[](16);

        /* Base facet generation. */
        facets[0] = address(new ERC20DataFacet());
        console.log("ERC20DataFacet:", facets[0]);
        facets[1] = address(new ERC20ApproveFacet());
        console.log("ERC20ApproveFacet:", facets[1]);
        facets[2] = address(new ERC20TransferFacet());
        console.log("ERC20TransferFacet:", facets[2]);
        facets[3] = address(new ERC20BurnFacet());
        console.log("ERC20BurnFacet:", facets[3]);
        facets[4] = address(new ERC20MetadataFacet());
        console.log("ERC20MetadataFacet:", facets[4]);
        facets[5] = address(new ERC20PermitFacet());
        console.log("ERC20PermitFacet:", facets[5]);

        /* Library facet generation. */
        facets[6] = address(new DiamondInspectFacet());
        console.log("DiamondInspectFacet:", facets[6]);
        facets[7] = address(new OwnerDataFacet());
        console.log("OwnerDataFacet:", facets[7]);
        facets[8] = address(new OwnerTransferFacet());
        console.log("OwnerTransferFacet:", facets[8]);
        facets[9] = address(new AccessControlDataFacet());
        console.log("AccessControlDataFacet:", facets[9]);
        facets[10] = address(new AccessControlGrantFacet());
        console.log("AccessControlGrantFacet:", facets[10]);
        facets[11] = address(new AccessControlRevokeFacet());
        console.log("AccessControlRevokeFacet:", facets[11]);
        facets[12] = address(new DiamondUpgradeFacet());
        console.log("DiamondUpgradeFacet:", facets[12]);
        facets[13] = address(new OwnerRenounceFacet());
        console.log("OwnerRenounceFacet:", facets[13]);
        facets[14] = address(new AccessControlGrantBatchFacet());
        console.log("AccessControlGrantBatchFacet:", facets[14]);
        facets[15] = address(new AccessControlRevokeBatchFacet());
        console.log("AccessControlRevokeBatchFacet:", facets[15]);

        /* Define diamond proxy. */
        diamond = new Diamond(facets);
        console.log("Diamond:", address(diamond));

        vm.stopBroadcast();
    }
}
