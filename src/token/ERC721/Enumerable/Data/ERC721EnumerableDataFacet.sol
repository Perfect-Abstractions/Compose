// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract ERC721EnumerableDataFacet {
    /**
     * @notice Thrown when an index is out of bounds during enumeration.
     */
    error ERC721OutOfBoundsIndex(address _owner, uint256 _index);

    bytes32 constant STORAGE_POSITION = keccak256("erc721.enumerable");

    /**
     * @custom:storage-location erc8042:erc721.enumerable
     */
    struct ERC721EnumerableStorage {
        mapping(address owner => mapping(uint256 index => uint256 tokenId)) ownerTokens;
        mapping(uint256 tokenId => uint256 ownerTokensIndex) ownerTokensIndex;
        uint256[] allTokens;
    }

    /**
     * @notice Returns the storage struct used by this facet.
     * @return s The ERC721Enumerable storage struct.
     */
    function getStorage() internal pure returns (ERC721EnumerableStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    bytes32 constant ERC721_STORAGE_POSITION = keccak256("erc721");

    /**
     * @custom:storage-location erc8042:erc721
     */
    struct ERC721Storage {
        mapping(uint256 tokenId => address owner) ownerOf;
        mapping(address owner => uint256 balance) balanceOf;
    }

    /**
     * @notice Returns a pointer to the ERC-721 storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The ERC721Storage struct in storage.
     */
    function getERC721Storage() internal pure returns (ERC721Storage storage s) {
        bytes32 position = ERC721_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the total number of tokens in existence.
     * @return The total supply of tokens.
     */
    function totalSupply() external view returns (uint256) {
        return getStorage().allTokens.length;
    }

    /**
     * @notice Returns a token ID owned by a given address at a specific index.
     * @param _owner The address to query.
     * @param _index The index of the token.
     * @return The token ID owned by `_owner` at `_index`.
     */
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        ERC721EnumerableStorage storage s = getStorage();
        ERC721Storage storage erc721Storage = getERC721Storage();
        if (_index >= erc721Storage.balanceOf[_owner]) {
            revert ERC721OutOfBoundsIndex(_owner, _index);
        }
        return s.ownerTokens[_owner][_index];
    }

    /**
     * @notice Enumerate valid NFTs
     * @dev Throws if `_index` >= `totalSupply()`.
     * @param _index A counter less than `totalSupply()`
     * @return The token identifier for the `_index`th NFT,
     */
    function tokenByIndex(uint256 _index) external view returns (uint256) {
        ERC721EnumerableStorage storage s = getStorage();
        if (_index >= s.allTokens.length) {
            revert ERC721OutOfBoundsIndex(address(0), _index);
        }
        return s.allTokens[_index];
    }
}
