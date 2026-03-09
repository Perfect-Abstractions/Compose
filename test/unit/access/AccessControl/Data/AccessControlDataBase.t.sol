// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import {Base_Test} from "test/Base.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";

abstract contract AccessControlData_Base_Test is Base_Test {
    using AccessControlStorageUtils for address;

    function setUp() public virtual override {
        Base_Test.setUp();
        vm.stopPrank();
    }

    function seedDefaultAdmin(address target) internal {
        target.setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
    }

    function seedRole(address target, bytes32 role, address account) internal {
        target.setHasRole(account, role, true);
    }

    function seedAdminRole(address target, bytes32 role, bytes32 adminRole_) internal {
        target.setAdminRole(role, adminRole_);
    }
}
