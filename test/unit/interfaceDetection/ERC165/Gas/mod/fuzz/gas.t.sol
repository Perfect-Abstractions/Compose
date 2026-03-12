// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Test, console2} from "forge-std/Test.sol";
import {ERC165Harness} from "test/utils/harnesses/interfaceDetection/ERC165/ERC165Harness.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract Gas_ERC165Mod_Fuzz_Unit_Test is Test {
    ERC165Harness internal harness;

    bytes4 internal constant IERC721_INTERFACE_ID = 0x80ac58cd;

    function setUp() public {
        harness = new ERC165Harness();
        harness.initialize();
    }

    function test_Gas_RegisterInterface() public {
        uint256 gasBefore = gasleft();
        harness.registerInterface(IERC721_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for registerInterface:", gasUsed);
    }

    function test_Gas_SupportsInterface() public {
        harness.registerInterface(IERC721_INTERFACE_ID);

        uint256 gasBefore = gasleft();
        harness.supportsInterface(IERC721_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

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

        console2.log("Gas used for registerMultipleInterfaces (10 interfaces):", gasUsed);
    }
}

