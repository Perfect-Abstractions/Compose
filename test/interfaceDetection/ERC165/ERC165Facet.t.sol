// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {ERC165Facet, IERC165} from "../../../src/interfaceDetection/ERC165/ERC165Facet.sol";
import {ERC165FacetHarness} from "./harnesses/ERC165FacetHarness.sol";

contract ERC165FacetTest is Test {
    ERC165FacetHarness public erc165Facet;

    // Test interface IDs
    bytes4 constant IERC165_INTERFACE_ID = type(IERC165).interfaceId;
    bytes4 constant IERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 constant IERC20_INTERFACE_ID = 0x36372b07;
    bytes4 constant INVALID_INTERFACE_ID = 0xffffffff;
    bytes4 constant CUSTOM_INTERFACE_ID = 0x12345678;
    bytes4 constant ZERO_INTERFACE_ID = 0x00000000;

    function setUp() public {
        erc165Facet = new ERC165FacetHarness();
        erc165Facet.initialize();
    }

    // ============================================
    // ERC165 Interface Support Tests
    // ============================================

    function test_SupportsInterface_ERC165() public view {
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_SupportsInterface_ERC165_AlwaysReturnsTrue() public view {
        // Even without registration, ERC165 interface should be supported
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_SupportsInterface_InvalidInterface() public view {
        // 0xffffffff should return false per ERC-165 spec
        assertFalse(erc165Facet.supportsInterface(INVALID_INTERFACE_ID));
    }

    function test_SupportsInterface_UnregisteredInterface() public view {
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertFalse(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));
    }

    function test_SupportsInterface_ZeroInterfaceId() public view {
        assertFalse(erc165Facet.supportsInterface(ZERO_INTERFACE_ID));
    }

    // ============================================
    // Interface Registration Tests
    // ============================================

    function test_RegisterInterface_SingleInterface() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_RegisterInterface_MultipleInterfaces() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.registerInterface(IERC20_INTERFACE_ID);
        erc165Facet.registerInterface(CUSTOM_INTERFACE_ID);

        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));
    }

    function test_RegisterInterface_DoesNotAffectERC165() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        // ERC165 should still be supported
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_RegisterInterface_CanRegisterZeroInterfaceId() public {
        erc165Facet.registerInterface(ZERO_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(ZERO_INTERFACE_ID));
    }

    function test_RegisterInterface_CanRegisterInvalidInterfaceId() public {
        // While 0xffffffff should return false per spec, we can still register it
        erc165Facet.registerInterface(INVALID_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(INVALID_INTERFACE_ID));
    }

    function test_RegisterInterface_Idempotent() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        // Register again
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    // ============================================
    // Interface Unregistration Tests
    // ============================================

    function test_UnregisterInterface_RemovesSupport() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_UnregisterInterface_DoesNotAffectOtherInterfaces() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.registerInterface(IERC20_INTERFACE_ID);

        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);

        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_UnregisterInterface_CannotUnregisterERC165() public {
        // Even if we try to unregister ERC165, it should still return true
        erc165Facet.unregisterInterface(IERC165_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_UnregisterInterface_Idempotent() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        // Unregister again
        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    // ============================================
    // Storage Tests
    // ============================================

    function test_StorageSlot_UsesCorrectPosition() public view {
        bytes32 expectedSlot = keccak256("compose.erc165");
        assertEq(erc165Facet.exposedGetStorage(), expectedSlot);
    }

    function test_StorageSlot_Consistency() public {
        bytes32 expectedSlot = keccak256("compose.erc165");

        erc165Facet.registerInterface(IERC721_INTERFACE_ID);

        // Read directly from storage
        // The mapping slot is calculated as keccak256(abi.encode(key, slot))
        bytes32 mappingSlot = keccak256(abi.encode(IERC721_INTERFACE_ID, expectedSlot));
        bytes32 storedValue = vm.load(address(erc165Facet), mappingSlot);

        // Should be true (1)
        assertEq(uint256(storedValue), 1);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_GetStorageValue_MatchesSupportsInterface() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);

        bool supportsResult = erc165Facet.supportsInterface(IERC721_INTERFACE_ID);
        bool storageResult = erc165Facet.getStorageValue(IERC721_INTERFACE_ID);

        assertEq(supportsResult, storageResult);
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_MultipleRegistrationAndUnregistration() public {
        // Register
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        // Unregister
        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        // Register again
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        // Unregister again
        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_MixedInterfaceOperations() public {
        // Register multiple
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.registerInterface(IERC20_INTERFACE_ID);
        erc165Facet.registerInterface(CUSTOM_INTERFACE_ID);

        // Verify all registered
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));

        // Unregister one
        erc165Facet.unregisterInterface(IERC20_INTERFACE_ID);

        // Verify state
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));

        // Register a new one
        erc165Facet.registerInterface(ZERO_INTERFACE_ID);

        // Verify final state
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(ZERO_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_SupportsInterface_ERC165AlwaysTrue(bytes4) public view {
        // ERC165 should always return true regardless of what else is registered
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function testFuzz_RegisterInterface(bytes4 interfaceId) public {
        erc165Facet.registerInterface(interfaceId);

        if (interfaceId == IERC165_INTERFACE_ID) {
            // ERC165 is always supported
            assertTrue(erc165Facet.supportsInterface(interfaceId));
        } else {
            // Other interfaces should be supported after registration
            assertTrue(erc165Facet.supportsInterface(interfaceId));
        }
    }

    function testFuzz_UnregisterInterface(bytes4 interfaceId) public {
        vm.assume(interfaceId != IERC165_INTERFACE_ID);

        erc165Facet.registerInterface(interfaceId);
        assertTrue(erc165Facet.supportsInterface(interfaceId));

        erc165Facet.unregisterInterface(interfaceId);
        assertFalse(erc165Facet.supportsInterface(interfaceId));
    }

    function testFuzz_RegisterAndUnregisterMultiple(bytes4[] calldata interfaceIds) public {
        vm.assume(interfaceIds.length > 0 && interfaceIds.length <= 20);

        // Register all
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            erc165Facet.registerInterface(interfaceIds[i]);
        }

        // Verify all registered
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            assertTrue(erc165Facet.supportsInterface(interfaceIds[i]));
        }

        // Unregister all (except ERC165)
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (interfaceIds[i] != IERC165_INTERFACE_ID) {
                erc165Facet.unregisterInterface(interfaceIds[i]);
                assertFalse(erc165Facet.supportsInterface(interfaceIds[i]));
            }
        }

        // ERC165 should still be supported
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function testFuzz_StorageConsistency(bytes4 interfaceId, bool shouldSupport) public {
        vm.assume(interfaceId != IERC165_INTERFACE_ID);

        if (shouldSupport) {
            erc165Facet.registerInterface(interfaceId);
        } else {
            erc165Facet.unregisterInterface(interfaceId);
        }

        assertEq(erc165Facet.supportsInterface(interfaceId), erc165Facet.getStorageValue(interfaceId));
    }

    // ============================================
    // Gas Optimization Tests
    // ============================================

    function test_Gas_SupportsInterface_ERC165() public view {
        // Should use less than 30,000 gas per ERC-165 spec
        uint256 gasBefore = gasleft();
        erc165Facet.supportsInterface(IERC165_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 30000, "supportsInterface should use less than 30,000 gas");
    }

    function test_Gas_SupportsInterface_RegisteredInterface() public {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);

        uint256 gasBefore = gasleft();
        erc165Facet.supportsInterface(IERC721_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 30000, "supportsInterface should use less than 30,000 gas");
    }

    function test_Gas_SupportsInterface_UnregisteredInterface() public view {
        uint256 gasBefore = gasleft();
        erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 30000, "supportsInterface should use less than 30,000 gas");
    }
}
