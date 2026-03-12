// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import {Base_Test} from "test/Base.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";

abstract contract OwnerTwoStepRenounce_Base_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        vm.stopPrank();
    }

    function seedOwner(address target, address owner_) internal {
        OwnerStorageUtils.setOwner(target, owner_);
    }

    function seedPendingOwner(address target, address pendingOwner_) internal {
        OwnerStorageUtils.setPendingOwner(target, pendingOwner_);
    }
}
