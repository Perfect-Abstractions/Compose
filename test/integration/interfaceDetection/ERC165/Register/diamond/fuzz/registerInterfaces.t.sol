// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Diamond_Base_Integration_Test} from "test/integration/interfaceDetection/ERC165/ERC165DiamondBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract RegisterInterfaces_ERC165Diamond_Fuzz_Integration_Test is ERC165Diamond_Base_Integration_Test {
    function test_ShouldReturnTrue_ForFeatureInterfacesAfterRegistration() external {
        bytes4[] memory interfaceIds = new bytes4[](2);
        interfaceIds[0] = IERC20_INTERFACE_ID;
        interfaceIds[1] = IERC1155_INTERFACE_ID;

        diamondRegister.registerInterfaces(interfaceIds);

        assertTrue(diamondERC165.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(diamondERC165.supportsInterface(IERC1155_INTERFACE_ID));
    }
}

