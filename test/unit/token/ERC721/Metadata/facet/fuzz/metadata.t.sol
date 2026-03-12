// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    ERC721MetadataFacet_Base_Test,
    ERC721MetadataFacetHarness
} from "test/unit/token/ERC721/Metadata/ERC721MetadataFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";
import {ERC721MetadataFacet} from "src/token/ERC721/Metadata/ERC721MetadataFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Metadata_ERC721MetadataFacet_Fuzz_Unit_Test is ERC721MetadataFacet_Base_Test {
    using ERC721StorageUtils for address;

    function test_ShouldReturnNameAndSymbol_WhenSetViaMetadataStorage() external view {
        string memory nameResult = facet.name();
        string memory symbolResult = facet.symbol();

        assertEq(bytes(nameResult).length, 0, "default name");
        assertEq(bytes(symbolResult).length, 0, "default symbol");
    }

    function testFuzz_ShouldRevert_TokenURI_WhenTokenDoesNotExist(uint256 tokenId) external {
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721MetadataFacet.ERC721NonexistentToken.selector, tokenId));
        facet.tokenURI(tokenId);
    }

    function testFuzz_ShouldReturnEmptyString_TokenURI_WhenBaseURIIsEmpty(uint256 tokenId, address owner) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        /* seed ownership without touching metadata baseURI (remains empty) */
        _mint(owner, tokenId);

        string memory uri = facet.tokenURI(tokenId);
        assertEq(bytes(uri).length, 0, "tokenURI when baseURI is empty");
    }

    function test_ShouldReturnTokenURI_ForTokenIdZero_WhenBaseURISet() external {
        uint256 tokenId = 0;
        address owner = users.alice;

        _mint(owner, tokenId);
        string memory baseURI = "https://example.com/metadata/";
        _setBaseURI(baseURI);

        string memory uri = facet.tokenURI(tokenId);
        assertEq(uri, string.concat(baseURI, "0"), "tokenURI for tokenId 0");
    }

    function testFuzz_ShouldReturnTokenURI_WhenBaseURISetAndTokenExists(uint256 tokenId, address owner) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        _mint(owner, tokenId);
        string memory baseURI = "ipfs://base/";
        _setBaseURI(baseURI);

        string memory expected = string.concat(baseURI, _toString(tokenId));
        string memory uri = facet.tokenURI(tokenId);
        assertEq(uri, expected, "tokenURI with baseURI set");
    }

    function test_ShouldReturnConfiguredNameAndSymbol_WhenSetInMetadataStorage() external {
        string memory expectedName = "Test Token";
        string memory expectedSymbol = "TEST";

        ERC721MetadataFacetHarness(address(facet)).setNameAndSymbol(expectedName, expectedSymbol);

        string memory nameResult = facet.name();
        string memory symbolResult = facet.symbol();

        assertEq(nameResult, expectedName, "configured name");
        assertEq(symbolResult, expectedSymbol, "configured symbol");
    }

    function test_ShouldExportSelectors_MetadataFacet() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = bytes.concat(
            ERC721MetadataFacet.name.selector,
            ERC721MetadataFacet.symbol.selector,
            ERC721MetadataFacet.tokenURI.selector
        );
        assertEq(selectors, expected, "exportSelectors metadata facet");
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

