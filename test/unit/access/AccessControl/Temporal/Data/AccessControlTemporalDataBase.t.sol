// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import {Base_Test} from "test/Base.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";

abstract contract AccessControlTemporalData_Base_Test is Base_Test {
    using AccessControlStorageUtils for address;

    function setUp() public virtual override {
        Base_Test.setUp();
        vm.stopPrank();
    }

    function seedRole(address target, bytes32 role, address account) internal {
        target.setHasRole(account, role, true);
    }

    function seedRoleExpiry(address target, bytes32 role, address account, uint256 expiry) internal {
        target.setRoleExpiry(account, role, expiry);
    }
}
