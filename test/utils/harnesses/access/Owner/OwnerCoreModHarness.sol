// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {owner as ownerDataOwner, requireOwner as ownerDataRequireOwner} from "src/access/Owner/Data/OwnerDataMod.sol";
import {transferOwnership as ownerTransferOwnership} from "src/access/Owner/Transfer/OwnerTransferMod.sol";
import {renounceOwnership as ownerRenounceOwnership} from "src/access/Owner/Renounce/OwnerRenounceMod.sol";

contract OwnerCoreModHarness {
    function owner() external view returns (address) {
        return ownerDataOwner();
    }

    function requireOwner() external view {
        ownerDataRequireOwner();
    }

    function transferOwnership(address _newOwner) external {
        ownerTransferOwnership(_newOwner);
    }

    function renounceOwnership() external {
        ownerRenounceOwnership();
    }
}
