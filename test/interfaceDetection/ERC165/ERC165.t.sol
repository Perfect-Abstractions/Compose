// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import "../../../src/interfaceDetection/ERC165/ERC165.sol" as ERC165;
import {ERC165Harness} from "./harnesses/ERC165Harness.sol";

contract LibERC165Test is Test {
    ERC165Harness public harness;

    /**
     * Test interface IDs
     */
    bytes4 constant IERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 constant IERC20_INTERFACE_ID = 0x36372b07;
    bytes4 constant IERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 constant IERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 constant INVALID_INTERFACE_ID = 0xffffffff;
    bytes4 constant CUSTOM_INTERFACE_ID = 0x12345678;
    bytes4 constant ZERO_INTERFACE_ID = 0x00000000;

    function setUp() public {
        harness = new ERC165Harness();
        harness.initialize();
    }

    /**
     * Storage Tests
     */

    function test_GetStorage_ReturnsCorrectStoragePosition() public view {
        bytes32 expectedSlot = keccak256("compose.erc165");
        assertEq(harness.getStoragePosition(), expectedSlot);
    }

    function test_StorageSlot_UsesCorrectPosition() public {
        bytes32 expectedSlot = keccak256("compose.erc165");

        harness.registerInterface(IERC721_INTERFACE_ID);

        /**
         * Read directly from storage
         */
        /**
         * The mapping slot is calculated as keccak256(abi.encode(key, slot))
         */
        bytes32 mappingSlot = keccak256(abi.encode(IERC721_INTERFACE_ID, expectedSlot));
        bytes32 storedValue = vm.load(address(harness), mappingSlot);

        /**
         * Should be true (1)
         */
        assertEq(uint256(storedValue), 1);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_GetStorageValue_MatchesSupportsInterface() public {
        harness.registerInterface(IERC721_INTERFACE_ID);

        bool supportsResult = harness.supportsInterface(IERC721_INTERFACE_ID);
        bool storageResult = harness.getStorageValue(IERC721_INTERFACE_ID);

        assertEq(supportsResult, storageResult);
    }

    /**
     * Register Interface Tests
     */

    function test_RegisterInterface_SingleInterface() public {
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_RegisterInterface_MultipleInterfaces() public {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.registerInterface(IERC20_INTERFACE_ID);
        harness.registerInterface(IERC1155_INTERFACE_ID);

        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC1155_INTERFACE_ID));
    }

    function test_RegisterInterface_Idempotent() public {
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        /**
         * Register again
         */
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_RegisterInterface_ZeroInterfaceId() public {
        harness.registerInterface(ZERO_INTERFACE_ID);
        assertTrue(harness.supportsInterface(ZERO_INTERFACE_ID));
    }

    function test_RegisterInterface_InvalidInterfaceId() public {
        harness.registerInterface(INVALID_INTERFACE_ID);
        assertTrue(harness.supportsInterface(INVALID_INTERFACE_ID));
    }

    function test_RegisterInterface_ERC165InterfaceId() public {
        harness.registerInterface(IERC165_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_RegisterInterface_CustomInterfaceId() public {
        harness.registerInterface(CUSTOM_INTERFACE_ID);
        assertTrue(harness.supportsInterface(CUSTOM_INTERFACE_ID));
    }

    /**
     * Multiple Interface Registration Tests
     */

    function test_RegisterMultipleInterfaces_Array() public {
        bytes4[] memory interfaceIds = new bytes4[](3);
        interfaceIds[0] = IERC721_INTERFACE_ID;
        interfaceIds[1] = IERC20_INTERFACE_ID;
        interfaceIds[2] = IERC1155_INTERFACE_ID;

        harness.registerMultipleInterfaces(interfaceIds);

        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC1155_INTERFACE_ID));
    }

    function test_RegisterMultipleInterfaces_EmptyArray() public {
        bytes4[] memory interfaceIds = new bytes4[](0);
        harness.registerMultipleInterfaces(interfaceIds);
        /**
         * Should not revert
         */
    }

    function test_RegisterMultipleInterfaces_SingleElement() public {
        bytes4[] memory interfaceIds = new bytes4[](1);
        interfaceIds[0] = IERC721_INTERFACE_ID;

        harness.registerMultipleInterfaces(interfaceIds);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_RegisterMultipleInterfaces_WithDuplicates() public {
        bytes4[] memory interfaceIds = new bytes4[](5);
        interfaceIds[0] = IERC721_INTERFACE_ID;
        interfaceIds[1] = IERC20_INTERFACE_ID;
        interfaceIds[2] = IERC721_INTERFACE_ID; /**
                                                 * Duplicate
                                                 */
        interfaceIds[3] = IERC1155_INTERFACE_ID;
        interfaceIds[4] = IERC20_INTERFACE_ID; /**
                                                * Duplicate
                                                */

        harness.registerMultipleInterfaces(interfaceIds);

        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC1155_INTERFACE_ID));
    }

    /**
     * Unregistered Interface Tests
     */

    function test_SupportsInterface_UnregisteredInterface() public view {
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertFalse(harness.supportsInterface(CUSTOM_INTERFACE_ID));
    }

    function test_SupportsInterface_AfterUnregistration() public {
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        /**
         * Unregister using forceSetInterface
         */
        harness.forceSetInterface(IERC721_INTERFACE_ID, false);
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    /**
     * Edge Cases
     */

    function test_RegisterAndUnregisterCycle() public {
        /**
         * Register
         */
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        /**
         * Unregister
         */
        harness.forceSetInterface(IERC721_INTERFACE_ID, false);
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));

        /**
         * Register again
         */
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        /**
         * Unregister again
         */
        harness.forceSetInterface(IERC721_INTERFACE_ID, false);
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_MixedOperations() public {
        /**
         * Register multiple
         */
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.registerInterface(IERC20_INTERFACE_ID);
        harness.registerInterface(CUSTOM_INTERFACE_ID);

        /**
         * Verify all registered
         */
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(harness.supportsInterface(CUSTOM_INTERFACE_ID));

        /**
         * Unregister one
         */
        harness.forceSetInterface(IERC20_INTERFACE_ID, false);

        /**
         * Verify state
         */
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(harness.supportsInterface(CUSTOM_INTERFACE_ID));

        /**
         * Register a new one
         */
        harness.registerInterface(IERC1155_INTERFACE_ID);

        /**
         * Verify final state
         */
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(harness.supportsInterface(CUSTOM_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC1155_INTERFACE_ID));
    }

    function test_ForceSetInterface_CanSetToTrue() public {
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));

        harness.forceSetInterface(IERC721_INTERFACE_ID, true);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ForceSetInterface_CanSetToFalse() public {
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        harness.forceSetInterface(IERC721_INTERFACE_ID, false);
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ForceSetInterface_DoesNotAffectOtherInterfaces() public {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.registerInterface(IERC20_INTERFACE_ID);

        harness.forceSetInterface(IERC721_INTERFACE_ID, false);

        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC20_INTERFACE_ID));
    }

    /**
     * Storage Consistency Tests
     */

    function test_StorageConsistency_AfterRegistration() public {
        harness.registerInterface(IERC721_INTERFACE_ID);

        assertEq(harness.supportsInterface(IERC721_INTERFACE_ID), harness.getStorageValue(IERC721_INTERFACE_ID));
    }

    function test_StorageConsistency_AfterMultipleRegistrations() public {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.registerInterface(IERC20_INTERFACE_ID);
        harness.registerInterface(IERC1155_INTERFACE_ID);

        assertEq(harness.supportsInterface(IERC721_INTERFACE_ID), harness.getStorageValue(IERC721_INTERFACE_ID));
        assertEq(harness.supportsInterface(IERC20_INTERFACE_ID), harness.getStorageValue(IERC20_INTERFACE_ID));
        assertEq(harness.supportsInterface(IERC1155_INTERFACE_ID), harness.getStorageValue(IERC1155_INTERFACE_ID));
    }

    function test_StorageConsistency_AfterUnregistration() public {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.forceSetInterface(IERC721_INTERFACE_ID, false);

        assertEq(harness.supportsInterface(IERC721_INTERFACE_ID), harness.getStorageValue(IERC721_INTERFACE_ID));
    }

    /**
     * Library Does Not Check Caller Tests
     */

    function test_LibraryDoesNotCheckMsgSender() public {
        /**
         * The library doesn't check msg.sender - that's the facet's responsibility
         */
        /**
         * This test verifies the library works regardless of caller
         */
        /**
         * (In production, the facet should check permissions before calling the library)
         */

        address alice = makeAddr("alice");

        vm.prank(alice); /**
                          * Not any special address
                          */
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        /**
         * This shows the library itself doesn't enforce access control
         */
        /**
         * Access control should be implemented in the facet that uses the library
         */
    }

    /**
     * Fuzz Tests
     */

    function testFuzz_RegisterInterface(bytes4 interfaceId) public {
        harness.registerInterface(interfaceId);
        assertTrue(harness.supportsInterface(interfaceId));
    }

    function testFuzz_RegisterAndUnregister(bytes4 interfaceId) public {
        harness.registerInterface(interfaceId);
        assertTrue(harness.supportsInterface(interfaceId));

        harness.forceSetInterface(interfaceId, false);
        assertFalse(harness.supportsInterface(interfaceId));
    }

    function testFuzz_MultipleRegistrations(bytes4[] calldata interfaceIds) public {
        vm.assume(interfaceIds.length > 0 && interfaceIds.length <= 20);

        /**
         * Register all
         */
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            harness.registerInterface(interfaceIds[i]);
        }

        /**
         * Verify all registered
         */
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            assertTrue(harness.supportsInterface(interfaceIds[i]));
        }
    }

    function testFuzz_StorageConsistency(bytes4 interfaceId, bool shouldSupport) public {
        harness.forceSetInterface(interfaceId, shouldSupport);

        assertEq(harness.supportsInterface(interfaceId), harness.getStorageValue(interfaceId));
        assertEq(harness.supportsInterface(interfaceId), shouldSupport);
    }

    function testFuzz_RegisterMultipleInterfaces(bytes4[] calldata interfaceIds) public {
        vm.assume(interfaceIds.length > 0 && interfaceIds.length <= 50);

        harness.registerMultipleInterfaces(interfaceIds);

        /**
         * Verify all registered
         */
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            assertTrue(harness.supportsInterface(interfaceIds[i]));
        }
    }

    function testFuzz_MixedOperations(bytes4 interfaceId1, bytes4 interfaceId2, bytes4 interfaceId3) public {
        /**
         * Ensure unique interface IDs for this test
         */
        vm.assume(interfaceId1 != interfaceId2);
        vm.assume(interfaceId1 != interfaceId3);
        vm.assume(interfaceId2 != interfaceId3);

        /**
         * Register first two
         */
        harness.registerInterface(interfaceId1);
        harness.registerInterface(interfaceId2);

        assertTrue(harness.supportsInterface(interfaceId1));
        assertTrue(harness.supportsInterface(interfaceId2));

        /**
         * Unregister first
         */
        harness.forceSetInterface(interfaceId1, false);

        assertFalse(harness.supportsInterface(interfaceId1));
        assertTrue(harness.supportsInterface(interfaceId2));

        /**
         * Register third
         */
        harness.registerInterface(interfaceId3);

        assertFalse(harness.supportsInterface(interfaceId1));
        assertTrue(harness.supportsInterface(interfaceId2));
        assertTrue(harness.supportsInterface(interfaceId3));
    }

    function testFuzz_IdempotentRegistration(bytes4 interfaceId, uint8 registrationCount) public {
        vm.assume(registrationCount > 0 && registrationCount <= 10);

        /**
         * Register multiple times
         */
        for (uint256 i = 0; i < registrationCount; i++) {
            harness.registerInterface(interfaceId);
        }

        /**
         * Should still be supported
         */
        assertTrue(harness.supportsInterface(interfaceId));
    }

    function testFuzz_CallerIndependence(address caller, bytes4 interfaceId) public {
        vm.prank(caller);
        harness.registerInterface(interfaceId);
        assertTrue(harness.supportsInterface(interfaceId));
    }

    /**
     * Gas Optimization Tests
     */

    function test_Gas_RegisterInterface() public {
        uint256 gasBefore = gasleft();
        harness.registerInterface(IERC721_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        /**
         * Log gas usage for reference
         */
        console2.log("Gas used for registerInterface:", gasUsed);
    }

    function test_Gas_SupportsInterface() public {
        harness.registerInterface(IERC721_INTERFACE_ID);

        uint256 gasBefore = gasleft();
        harness.supportsInterface(IERC721_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        /**
         * Log gas usage for reference
         */
        console2.log("Gas used for supportsInterface:", gasUsed);
    }

    function test_Gas_RegisterMultipleInterfaces() public {
        bytes4[] memory interfaceIds = new bytes4[](10);
        for (uint256 i = 0; i < 10; i++) {
            interfaceIds[i] = bytes4(uint32(i + 1));
        }

        uint256 gasBefore = gasleft();
        harness.registerMultipleInterfaces(interfaceIds);
        uint256 gasUsed = gasBefore - gasleft();

        /**
         * Log gas usage for reference
         */
        console2.log("Gas used for registerMultipleInterfaces (10 interfaces):", gasUsed);
    }
}
