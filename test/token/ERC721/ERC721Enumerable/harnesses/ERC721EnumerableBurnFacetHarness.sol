// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC721EnumerableFacet} from "../../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableFacet.sol";
import {ERC721EnumerableBurnFacet} from "../../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableBurnFacet.sol";
import {LibERC721 as LibERC721Enumerable} from "../../../../../src/token/ERC721/ERC721Enumerable/LibERC721Enumerable.sol";

/// @title ERC721EnumerableBurnFacetHarness
/// @notice Lightweight harness combining read/transfer functionality with burn entrypoint for testing.
contract ERC721EnumerableBurnFacetHarness is ERC721EnumerableFacet, ERC721EnumerableBurnFacet {
    /// @notice Initialize collection metadata for tests.
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        ERC721EnumerableStorage storage s = getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    /// @notice Mint helper for tests (not part of production facet surface).
    function mint(address _to, uint256 _tokenId) external {
        LibERC721Enumerable.mint(_to, _tokenId);
    }
}
