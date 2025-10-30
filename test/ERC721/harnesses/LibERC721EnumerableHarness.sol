// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibERC721 as LibERC721Enumerable} from "../../../src/token/ERC721/ERC721Enumerable/LibERC721Enumerable.sol";

/// @title LibERC721EnumerableHarness
/// @notice Test harness that exposes LibERC721Enumerable's internal functions as external
/// @dev Required for testing since LibERC721Enumerable only has internal functions
contract LibERC721EnumerableHarness {
    /// @notice Initialize the ERC721Enumerable token storage
    /// @dev Only used for testing
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        LibERC721Enumerable.ERC721EnumerableStorage storage s = LibERC721Enumerable.getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    /// @notice Exposes LibERC721Enumerable.mint as an external function
    /// @dev Only used for testing
    function mint(address _to, uint256 _tokenId) external {
        LibERC721Enumerable.mint(_to, _tokenId);
    }

    /// @notice Exposes LibERC721Enumerable.burn as an external function
    function burn(uint256 _tokenId, address _sender) external {
        LibERC721Enumerable.burn(_tokenId, _sender);
    }

    /// @notice Get storage values for testing
    function name() external view returns (string memory) {
        return LibERC721Enumerable.getStorage().name;
    }

    function symbol() external view returns (string memory) {
        return LibERC721Enumerable.getStorage().symbol;
    }

    function baseURI() external view returns (string memory) {
        return LibERC721Enumerable.getStorage().baseURI;
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        return LibERC721Enumerable.getStorage().ownerOf[_tokenId];
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return LibERC721Enumerable.getStorage().ownedTokensOf[_owner].length;
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        return LibERC721Enumerable.getStorage().approved[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return LibERC721Enumerable.getStorage().isApprovedForAll[_owner][_operator];
    }

    function totalSupply() external view returns (uint256) {
        return LibERC721Enumerable.getStorage().allTokens.length;
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        return LibERC721Enumerable.getStorage().ownedTokensOf[_owner][_index];
    }

    function tokenByIndex(uint256 _index) external view returns (uint256) {
        return LibERC721Enumerable.getStorage().allTokens[_index];
    }
}
