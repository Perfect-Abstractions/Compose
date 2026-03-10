// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155MetadataMod_Base_Test} from "test/unit/token/ERC1155/Metadata/ERC1155MetadataModBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 *
 * Tests setBaseURI, setTokenURI (and setURI) via the mod harness; asserts via uri() that
 * storage was updated so uri(id) returns the expected value.
 */
contract Metadata_ERC1155MetadataMod_Fuzz_Test is ERC1155MetadataMod_Base_Test {
    function test_ShouldReturnDefaultUri_Uri_WhenNoTokenSpecificUriSet() external {
        string memory defaultUri = "https://example.com/{id}.json";
        harness.setURI(defaultUri);
        assertEq(harness.uri(0), defaultUri, "default uri");
        assertEq(harness.uri(1), defaultUri, "default uri id 1");
    }

    function test_ShouldReturnBaseURIAndTokenURI_Uri_WhenTokenSpecificUriSet() external {
        string memory baseURI = "https://base.uri/";
        string memory tokenURI = "token1.json";
        harness.setBaseURI(baseURI);
        harness.setTokenURI(1, tokenURI);
        assertEq(harness.uri(1), string.concat(baseURI, tokenURI), "uri(1)");
    }

    function testFuzz_ShouldReturnExpectedUri_Uri_WhenSetViaMod(
        uint256 id,
        string memory baseURI,
        string memory tokenURI
    ) external {
        vm.assume(bytes(baseURI).length <= 100);
        vm.assume(bytes(tokenURI).length > 0);
        vm.assume(bytes(tokenURI).length <= 100);
        harness.setBaseURI(baseURI);
        harness.setTokenURI(id, tokenURI);
        assertEq(harness.uri(id), string.concat(baseURI, tokenURI), "uri");
    }

    function test_ShouldUpdateUri_SetURI() external {
        harness.setURI("https://default.com/");
        assertEq(harness.uri(999), "https://default.com/", "default");
    }
}
