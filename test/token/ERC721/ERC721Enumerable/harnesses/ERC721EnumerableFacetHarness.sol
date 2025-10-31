// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC721EnumerableFacet} from "../../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableFacet.sol";

/// @title ERC721EnumerableFacetHarness
/// @notice Test harness for ERC721EnumerableFacet that adds helper functions for testing
/// @dev Extends ERC721EnumerableFacet with mint and burn capabilities for testing
contract ERC721EnumerableFacetHarness is ERC721EnumerableFacet {
    /// @notice Initialize the ERC721 enumerable token storage
    /// @dev Only used for testing
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        ERC721EnumerableStorage storage s = getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    /// @notice Mint a token for testing
    function mint(address _to, uint256 _tokenId) external {
        ERC721EnumerableStorage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        if (s.ownerOf[_tokenId] != address(0)) {
            revert ERC721InvalidSender(address(0));
        }

        s.ownedTokensIndexOf[_tokenId] = s.ownedTokensOf[_to].length;
        s.ownedTokensOf[_to].push(_tokenId);
        s.allTokensIndexOf[_tokenId] = s.allTokens.length;
        s.allTokens.push(_tokenId);
        s.ownerOf[_tokenId] = _to;
        emit Transfer(address(0), _to, _tokenId);
    }

    /// @notice Burn a token for testing
    function burn(uint256 _tokenId) external {
        ERC721EnumerableStorage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (msg.sender != owner) {
            if (!s.isApprovedForAll[owner][msg.sender] && msg.sender != s.approved[_tokenId]) {
                revert ERC721InsufficientApproval(msg.sender, _tokenId);
            }
        }

        delete s.ownerOf[_tokenId];
        delete s.approved[_tokenId];

        uint256 tokenIndex = s.ownedTokensIndexOf[_tokenId];
        uint256 lastTokenIndex = s.ownedTokensOf[owner].length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.ownedTokensOf[owner][lastTokenIndex];
            s.ownedTokensOf[owner][tokenIndex] = lastTokenId;
            s.ownedTokensIndexOf[lastTokenId] = tokenIndex;
        }
        s.ownedTokensOf[owner].pop();

        tokenIndex = s.allTokensIndexOf[_tokenId];
        lastTokenIndex = s.allTokens.length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.allTokens[lastTokenIndex];
            s.allTokens[tokenIndex] = lastTokenId;
            s.allTokensIndexOf[lastTokenId] = tokenIndex;
        }
        s.allTokens.pop();
        emit Transfer(owner, address(0), _tokenId);
    }
}

