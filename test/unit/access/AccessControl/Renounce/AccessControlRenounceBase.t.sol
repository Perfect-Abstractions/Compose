// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import {Base_Test} from "test/Base.t.sol";

abstract contract AccessControlRenounce_Base_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.stopPrank();
    }
}
