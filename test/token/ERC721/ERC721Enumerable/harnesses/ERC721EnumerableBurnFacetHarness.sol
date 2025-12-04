// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {
    ERC721EnumerableBurnFacet
} from "../../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableBurnFacet.sol";
import "../../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableMod.sol" as ERC721EnumerableMod;

/**
 * @title ERC721EnumerableBurnFacetHarness
 * @notice Lightweight harness combining read/transfer functionality with burn entrypoint for testing.
 */
contract ERC721EnumerableBurnFacetHarness is ERC721EnumerableBurnFacet {
    /**
     * @notice Initialize collection metadata for tests.
     */
    /**
     * function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
     * ERC721EnumerableStorage storage s = getStorage();
     * s.name = _name;
     * s.symbol = _symbol;
     * s.baseURI = _baseURI;
     * }
     */
    /**
     * @notice Mint helper for tests (not part of production facet surface).
     */
    function mint(address _to, uint256 _tokenId) external {
        ERC721EnumerableMod.mint(_to, _tokenId);
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return getStorage().ownerTokens[_owner].length;
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        address owner = getStorage().ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        return owner;
    }

    function totalSupply() external view returns (uint256) {
        return getStorage().allTokens.length;
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        ERC721EnumerableStorage storage s = getStorage();
        if (_index >= s.ownerTokens[_owner].length) {
            /**
             * We don't have the error defined in this facet, so we revert with generic or define it?
             * The test expects ERC721OutOfBoundsIndex?
             * Wait, the test `test_Burn_UpdatesEnumerationOrdering` calls `tokenOfOwnerByIndex`.
             * If I don't implement it correctly, it fails.
             * The test doesn't check for revert on this function, it checks return value.
             */
            revert("Index out of bounds");
        }
        return s.ownerTokens[_owner][_index];
    }

    function approve(address _to, uint256 _tokenId) external {
        ERC721EnumerableStorage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        /**
         * Simplified approve for testing burn
         */
        s.approved[_tokenId] = _to;
    }
}
