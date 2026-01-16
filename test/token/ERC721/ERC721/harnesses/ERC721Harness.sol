// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.30;
//
// /* Compose
//  * https://compose.diamonds
//  */
//
// import "../../../../../src/token/ERC721/ERC721/ERC721Mod.sol" as ERC721Mod;
//
// contract ERC721Harness {
//     /**
//      * @notice Initialize the ERC721 token storage
//      * @dev Only used for testing
//      */
//     function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
//         ERC721Mod.ERC721Storage storage s = ERC721Mod.getStorage();
//         s.name = _name;
//         s.symbol = _symbol;
//         s.baseURI = _baseURI;
//     }
//
//     /**
//      * @notice Exposes ERC721Mod.mint as an external function
//      */
//     function mint(address _to, uint256 _tokenId) external {
//         ERC721Mod.mint(_to, _tokenId);
//     }
//
//     /**
//      * @notice Exposes ERC721Mod.burn as an external function
//      */
//     function burn(uint256 _tokenId) external {
//         ERC721Mod.burn(_tokenId);
//     }
//
//     /**
//      * @notice Exposes ERC721Mod.transferFrom as an external function
//      */
//     function transferFrom(address _from, address _to, uint256 _tokenId) external {
//         ERC721Mod.transferFrom(_from, _to, _tokenId);
//     }
//
//     /**
//      * @notice Expose owner lookup for a given token id
//      */
//     function ownerOf(uint256 _tokenId) external view returns (address) {
//         return ERC721Mod.getStorage().ownerOf[_tokenId];
//     }
//
//     /**
//      * @notice Get storage values for testing
//      */
//     function name() external view returns (string memory) {
//         return ERC721Mod.getStorage().name;
//     }
//
//     function symbol() external view returns (string memory) {
//         return ERC721Mod.getStorage().symbol;
//     }
//
//     function baseURI() external view returns (string memory) {
//         return ERC721Mod.getStorage().baseURI;
//     }
// }
