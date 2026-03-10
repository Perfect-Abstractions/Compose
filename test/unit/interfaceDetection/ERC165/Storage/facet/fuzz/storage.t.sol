// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Facet_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165FacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract Storage_ERC165Facet_Fuzz_Unit_Test is ERC165Facet_Base_Test {
    function test_ShouldUseExpectedSlot_WhenReadingStorageSlot() external view {
        assertEq(erc165Facet.exposedGetStorage(), keccak256("erc165"));
    }

    function test_ShouldWriteMappingValue_WhenRegisteringInterface() external {
        bytes32 storageSlot = keccak256("erc165");
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);

        bytes32 mappingSlot = keccak256(abi.encode(IERC721_INTERFACE_ID, storageSlot));
        bytes32 storedValue = vm.load(address(erc165Facet), mappingSlot);

        assertEq(uint256(storedValue), 1);
    }

    function test_ShouldMatchRawStorage_WhenReadingSupportStatus() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);

        bool supportsResult = erc165Facet.supportsInterface(IERC721_INTERFACE_ID);
        bool storageResult = erc165Facet.getStorageValue(IERC721_INTERFACE_ID);

        assertEq(supportsResult, storageResult);
    }

    function testFuzz_ShouldMatchRawStorage_AfterFuzzedState(bytes4 interfaceId, bool shouldSupport) external {
        vm.assume(interfaceId != IERC165_INTERFACE_ID);

        if (shouldSupport) {
            erc165Facet.registerInterface(interfaceId);
        } else {
            erc165Facet.unregisterInterface(interfaceId);
        }

        assertEq(erc165Facet.supportsInterface(interfaceId), erc165Facet.getStorageValue(interfaceId));
    }
}

