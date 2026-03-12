// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Test} from "forge-std/Test.sol";

import {ExampleDiamond} from "src/diamond/example/ExampleDiamond.sol";
import {ERC165Facet, IERC165} from "src/interfaceDetection/ERC165/ERC165Facet.sol";
import "src/interfaceDetection/ERC165/ERC165Mod.sol" as ERC165Mod;
import {IERC20} from "src/interfaces/IERC20.sol";
import {IERC1155} from "src/interfaces/IERC1155.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */

contract ERC165RegisterFacet {
    function registerInterfaces(bytes4[] calldata interfaceIds) external {
        uint256 length = interfaceIds.length;

        for (uint256 i = 0; i < length; i++) {
            ERC165Mod.registerInterface(interfaceIds[i]);
        }
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.registerInterfaces.selector);
    }
}

interface IDiamondERC165 is IERC165 {}

interface IDiamondERC165Register {
    function registerInterfaces(bytes4[] calldata interfaceIds) external;
}

abstract contract ERC165Diamond_Base_Integration_Test is Test {
    ExampleDiamond internal diamond;

    IDiamondERC165 internal diamondERC165;
    IDiamondERC165Register internal diamondRegister;

    bytes4 internal constant IERC165_INTERFACE_ID = type(IERC165).interfaceId;
    bytes4 internal constant IERC20_INTERFACE_ID = type(IERC20).interfaceId;
    bytes4 internal constant IERC1155_INTERFACE_ID = type(IERC1155).interfaceId;

    function setUp() public virtual {
        ERC165Facet erc165Facet = new ERC165Facet();
        ERC165RegisterFacet registerFacet = new ERC165RegisterFacet();

        address[] memory facets = new address[](2);
        facets[0] = address(erc165Facet);
        facets[1] = address(registerFacet);

        diamond = new ExampleDiamond(facets, address(this));

        diamondERC165 = IDiamondERC165(address(diamond));
        diamondRegister = IDiamondERC165Register(address(diamond));
    }
}

