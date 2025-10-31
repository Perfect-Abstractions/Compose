// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibERC721} from "../../../../../src/token/ERC721/ERC721Enumerable/LibERC721Enumerable.sol";

/// @title LibERC721EnumerableHarness
/// @notice Test harness that exposes LibERC721 Enumerable's internal functions as external
/// @dev Required for testing since LibERC721 only has internal functions
contract LibERC721EnumerableHarness {
    /// @notice Initialize the ERC721 enumerable token storage
    /// @dev Only used for testing
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        LibERC721.ERC721EnumerableStorage storage s = LibERC721.getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    /// @notice Exposes LibERC721.mint as an external function
    function mint(address _to, uint256 _tokenId) external {
        LibERC721.mint(_to, _tokenId);
    }

    /// @notice Exposes LibERC721.burn as an external function
    function burn(uint256 _tokenId, address _sender) external {
        LibERC721.burn(_tokenId, _sender);
    }

    /// @notice Exposes LibERC721.transferFrom as an external function
    function transferFrom(address _from, address _to, uint256 _tokenId, address _sender) external {
        LibERC721.transferFrom(_from, _to, _tokenId, _sender);
    }

    /// @notice Get storage values for testing
    function name() external view returns (string memory) {
        return LibERC721.getStorage().name;
    }

    function symbol() external view returns (string memory) {
        return LibERC721.getStorage().symbol;
    }

    function baseURI() external view returns (string memory) {
        return LibERC721.getStorage().baseURI;
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        return LibERC721.getStorage().ownerOf[_tokenId];
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return LibERC721.getStorage().ownedTokensOf[_owner].length;
    }

    function totalSupply() external view returns (uint256) {
        return LibERC721.getStorage().allTokens.length;
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        return LibERC721.getStorage().ownedTokensOf[_owner][_index];
    }

    function tokenByIndex(uint256 _index) external view returns (uint256) {
        return LibERC721.getStorage().allTokens[_index];
    }

    function ownedTokensIndexOf(uint256 _tokenId) external view returns (uint256) {
        return LibERC721.getStorage().ownedTokensIndexOf[_tokenId];
    }

    function allTokensIndexOf(uint256 _tokenId) external view returns (uint256) {
        return LibERC721.getStorage().allTokensIndexOf[_tokenId];
    }

    function approved(uint256 _tokenId) external view returns (address) {
        return LibERC721.getStorage().approved[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return LibERC721.getStorage().isApprovedForAll[_owner][_operator];
    }
}

