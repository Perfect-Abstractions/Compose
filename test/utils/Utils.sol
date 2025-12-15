// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {CommonBase as StdBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

abstract contract Utils is StdBase, StdUtils {
    /*//////////////////////////////////////////////////////////////
                                  MISC
    //////////////////////////////////////////////////////////////*/

    /// @dev Retrieves the current block timestamp as an `uint40`.
    function getBlockTimestamp() internal view returns (uint40) {
        return uint40(vm.getBlockTimestamp());
    }

    /// @dev Stops the active prank and sets a new one.
    function setMsgSender(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);

        // Deal some ETH to the new caller.
        vm.deal(msgSender, 1 ether);
    }
}
