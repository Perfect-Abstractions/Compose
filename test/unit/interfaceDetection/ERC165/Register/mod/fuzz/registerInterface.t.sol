// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Mod_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165ModBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract RegisterInterface_ERC165Mod_Fuzz_Unit_Test is ERC165Mod_Base_Test {
    function test_ShouldMarkSupported_WhenRegisteringSingleInterface() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldMarkSupported_WhenRegisteringMultipleInterfaces() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.registerInterface(IERC20_INTERFACE_ID);
        harness.registerInterface(IERC1155_INTERFACE_ID);

        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC1155_INTERFACE_ID));
    }

    function test_ShouldBeIdempotent_WhenRegisteringSameInterfaceTwice() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.registerInterface(IERC721_INTERFACE_ID);

        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldSupportAll_WhenRegisteringArrayWithDuplicates() external {
        bytes4[] memory interfaceIds = new bytes4[](5);
        interfaceIds[0] = IERC721_INTERFACE_ID;
        interfaceIds[1] = IERC20_INTERFACE_ID;
        interfaceIds[2] = IERC721_INTERFACE_ID;
        interfaceIds[3] = IERC1155_INTERFACE_ID;
        interfaceIds[4] = IERC20_INTERFACE_ID;

        harness.registerMultipleInterfaces(interfaceIds);

        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC1155_INTERFACE_ID));
    }

    function test_ShouldNotRevert_WhenRegisteringEmptyArray() external {
        bytes4[] memory interfaceIds = new bytes4[](0);
        harness.registerMultipleInterfaces(interfaceIds);
    }

    function test_ShouldRegister_WhenArrayHasSingleElement() external {
        bytes4[] memory interfaceIds = new bytes4[](1);
        interfaceIds[0] = IERC721_INTERFACE_ID;

        harness.registerMultipleInterfaces(interfaceIds);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldNotDependOnCaller_WhenRegistering() external {
        address caller = makeAddr("caller");

        vm.prank(caller);
        harness.registerInterface(IERC721_INTERFACE_ID);

        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function testFuzz_ShouldMarkSupported_WhenRegistering(bytes4 interfaceId) external {
        harness.registerInterface(interfaceId);
        assertTrue(harness.supportsInterface(interfaceId));
    }

    function testFuzz_ShouldSupportAll_WhenRegisteringMany(bytes4[] calldata interfaceIds) external {
        vm.assume(interfaceIds.length > 0 && interfaceIds.length <= 50);

        harness.registerMultipleInterfaces(interfaceIds);

        for (uint256 i = 0; i < interfaceIds.length; i++) {
            assertTrue(harness.supportsInterface(interfaceIds[i]));
        }
    }

    function testFuzz_ShouldRemainSupported_WhenRegisteredManyTimes(bytes4 interfaceId, uint8 registrationCount)
        external
    {
        vm.assume(registrationCount > 0 && registrationCount <= 10);

        for (uint256 i = 0; i < registrationCount; i++) {
            harness.registerInterface(interfaceId);
        }

        assertTrue(harness.supportsInterface(interfaceId));
    }

    function testFuzz_ShouldSupportIndependentCallers(address caller, bytes4 interfaceId) external {
        vm.prank(caller);
        harness.registerInterface(interfaceId);

        assertTrue(harness.supportsInterface(interfaceId));
    }
}

