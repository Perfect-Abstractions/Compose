// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {CommonBase as StdBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

abstract contract Utils is StdBase, StdUtils {
    /*//////////////////////////////////////////////////////////////
                                  MISC
    //////////////////////////////////////////////////////////////*/

    function getBlockTimestamp() internal view returns (uint40) {
        return uint40(vm.getBlockTimestamp());
    }

    function setMsgSender(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);

        vm.deal(msgSender, 1 ether); // Deal ETH to new caller.
    }
}
