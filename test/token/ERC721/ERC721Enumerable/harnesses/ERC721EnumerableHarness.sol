// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableMod.sol" as ERC721Enumerable;

/**
 * @title ERC721EnumerableHarness
 * @notice Test harness that exposes LibERC721Enumerable library functions as external functions
 */
contract ERC721EnumerableHarness {
    /**
     * @notice Initialize the ERC721 enumerable token storage
     * @dev Only used for testing
     */
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        ERC721Enumerable.ERC721EnumerableStorage storage s = ERC721Enumerable.getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    /**
     * @notice Exposes ERC721Enumerable.mint as an external function
     */
    function mint(address _to, uint256 _tokenId) external {
        ERC721Enumerable.mint(_to, _tokenId);
    }

    /**
     * @notice Exposes ERC721Enumerable.burn as an external function
     */
    function burn(uint256 _tokenId) external {
        ERC721Enumerable.burn(_tokenId, msg.sender);
    }

    /**
     * @notice Exposes ERC721Enumerable.transferFrom as an external function
     */
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        ERC721Enumerable.transferFrom(_from, _to, _tokenId, msg.sender);
    }

    /**
     * @notice Expose owner lookup for a given token id
     */
    function ownerOf(uint256 _tokenId) external view returns (address) {
        return ERC721Enumerable.getStorage().ownerOf[_tokenId];
    }

    /**
     * @notice Get balance of an address
     */
    function balanceOf(address _owner) external view returns (uint256) {
        return ERC721Enumerable.getStorage().ownerTokens[_owner].length;
    }

    /**
     * @notice Get total supply
     */
    function totalSupply() external view returns (uint256) {
        return ERC721Enumerable.getStorage().allTokens.length;
    }

    /**
     * @notice Get token by index in owner's list
     */
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        return ERC721Enumerable.getStorage().ownerTokens[_owner][_index];
    }

    /**
     * @notice Get token by global index
     */
    function tokenByIndex(uint256 _index) external view returns (uint256) {
        return ERC721Enumerable.getStorage().allTokens[_index];
    }

    /**
     * @notice Get storage values for testing
     */
    function name() external view returns (string memory) {
        return ERC721Enumerable.getStorage().name;
    }

    function symbol() external view returns (string memory) {
        return ERC721Enumerable.getStorage().symbol;
    }

    function baseURI() external view returns (string memory) {
        return ERC721Enumerable.getStorage().baseURI;
    }

    /**
     * @notice Set approval for a token
     */
    function approve(address _approved, uint256 _tokenId) external {
        ERC721Enumerable.ERC721EnumerableStorage storage s = ERC721Enumerable.getStorage();
        s.approved[_tokenId] = _approved;
    }

    /**
     * @notice Get approved address for a token
     */
    function getApproved(uint256 _tokenId) external view returns (address) {
        return ERC721Enumerable.getStorage().approved[_tokenId];
    }

    /**
     * @notice Set approval for all tokens
     */
    function setApprovalForAll(address _operator, bool _approved) external {
        ERC721Enumerable.getStorage().isApprovedForAll[msg.sender][_operator] = _approved;
    }

    /**
     * @notice Check if operator is approved for all
     */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return ERC721Enumerable.getStorage().isApprovedForAll[_owner][_operator];
    }
}
