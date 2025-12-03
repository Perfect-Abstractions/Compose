// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../../src/token/ERC721/ERC721/ERC721.sol" as ERC721;

contract ERC721Harness {
    /**
     * @notice Initialize the ERC721 token storage
     * @dev Only used for testing
     */
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        ERC721.ERC721Storage storage s = ERC721.getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    /**
     * @notice Exposes ERC721.mint as an external function
     */
    function mint(address _to, uint256 _tokenId) external {
        ERC721.mint(_to, _tokenId);
    }

    /**
     * @notice Exposes ERC721.burn as an external function
     */
    function burn(uint256 _tokenId) external {
        ERC721.burn(_tokenId);
    }

    /**
     * @notice Exposes ERC721.transferFrom as an external function
     */
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        ERC721.transferFrom(_from, _to, _tokenId);
    }

    /**
     * @notice Expose owner lookup for a given token id
     */
    function ownerOf(uint256 _tokenId) external view returns (address) {
        return ERC721.getStorage().ownerOf[_tokenId];
    }

    /**
     * @notice Get storage values for testing
     */
    function name() external view returns (string memory) {
        return ERC721.getStorage().name;
    }

    function symbol() external view returns (string memory) {
        return ERC721.getStorage().symbol;
    }

    function baseURI() external view returns (string memory) {
        return ERC721.getStorage().baseURI;
    }
}
