// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {owner as ownerDataOwner} from "src/access/Owner/Data/OwnerDataMod.sol";
import {pendingOwner as twoStepPendingOwner} from "src/access/Owner/TwoSteps/Data/OwnerTwoStepDataMod.sol";
import {
    transferOwnership as twoStepTransferOwnership,
    acceptOwnership as twoStepAcceptOwnership
} from "src/access/Owner/TwoSteps/Transfer/OwnerTwoStepTransferMod.sol";
import {renounceOwnership as twoStepRenounceOwnership} from "src/access/Owner/TwoSteps/Renounce/OwnerTwoStepRenounceMod.sol";

contract OwnerTwoStepModHarness {
    function owner() external view returns (address) {
        return ownerDataOwner();
    }

    function pendingOwner() external view returns (address) {
        return twoStepPendingOwner();
    }

    function transferOwnership(address _newOwner) external {
        twoStepTransferOwnership(_newOwner);
    }

    function acceptOwnership() external {
        twoStepAcceptOwnership();
    }

    function renounceOwnership() external {
        twoStepRenounceOwnership();
    }
}
