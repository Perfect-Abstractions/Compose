// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC721EnumerableFacet} from "../../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableFacet.sol";

/**
 * @title ERC721EnumerableFacetHarness
 * @notice Test harness for ERC721EnumerableFacet that adds initialization and minting helpers
 */
contract ERC721EnumerableFacetHarness is ERC721EnumerableFacet {
    /**
     * @notice Initialize the ERC721 enumerable token storage
     * @dev Only used for testing - production diamonds should initialize in constructor
     */
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        ERC721EnumerableStorage storage s = getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    /**
     * @notice Mints a new ERC-721 token to the specified address.
     * @dev Reverts if the receiver address is zero or if the token already exists.
     * @param _to The address that will own the newly minted token.
     * @param _tokenId The ID of the token to mint.
     */
    function mint(address _to, uint256 _tokenId) external {
        ERC721EnumerableStorage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        if (s.ownerOf[_tokenId] != address(0)) {
            revert ERC721InvalidSender(address(0));
        }

        s.ownerOf[_tokenId] = _to;
        s.ownerTokensIndex[_tokenId] = s.ownerTokens[_to].length;
        s.ownerTokens[_to].push(_tokenId);
        s.allTokensIndex[_tokenId] = s.allTokens.length;
        s.allTokens.push(_tokenId);
        emit Transfer(address(0), _to, _tokenId);
    }
}
