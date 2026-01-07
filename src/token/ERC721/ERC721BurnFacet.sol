// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-721 Token Receiver Interface
 * @notice Interface for contracts that want to handle safe transfers of ERC-721 tokens.
 * @dev Contracts implementing this must return the selector to confirm token receipt.
 */
interface IERC721Receiver {
    /**
     * @notice Handles the receipt of an NFT.
     * @param _operator The address which called `safeTransferFrom`.
     * @param _from The previous owner of the token.
     * @param _tokenId The NFT identifier being transferred.
     * @param _data Additional data with no specified format.
     * @return The selector to confirm the token transfer.
     */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}

/**
 * @title ERC-721 Token
 * @notice A complete, dependency-free ERC-721 implementation using the diamond storage pattern.
 * @dev This facet provides metadata, ownership, approvals, safe transfers, minting, burning, and helpers.
 */
contract ERC721BurnFacet {
    /**
     * @notice Error indicating that the queried token does not exist.
     */
    error ERC721NonexistentToken(uint256 _tokenId);

    /**
     * @notice Error indicating the operator lacks approval to transfer the given token.
     */
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

    /**
     * @notice Emitted when ownership of an NFT changes by any mechanism.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /**
     * @notice Emitted when the approved address for an NFT is changed or reaffirmed.
     */
    event Approval(address indexed _owner, address indexed _to, uint256 indexed _tokenId);

    /**
     * @notice Emitted when an operator is enabled or disabled for an owner.
     */
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc721");

    /**
     * @custom:storage-location erc8042:compose.erc721
     */
    struct ERC721Storage {
        mapping(uint256 tokenId => address owner) ownerOf;
        mapping(address owner => uint256 balance) balanceOf;
        mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll;
        mapping(uint256 tokenId => address approved) approved;
    }

    /**
     * @notice Returns a pointer to the ERC-721 storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The ERC721Storage struct in storage.
     */
    function getStorage() internal pure returns (ERC721Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Burns (destroys) a token, removing it from enumeration tracking.
     * @param _tokenId The ID of the token to burn.
     */
    function burn(uint256 _tokenId) external {
        ERC721Storage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (msg.sender != owner) {
            if (!s.isApprovedForAll[owner][msg.sender] && msg.sender != s.approved[_tokenId]) {
                revert ERC721InsufficientApproval(msg.sender, _tokenId);
            }
        }
        unchecked {
            s.balanceOf[owner]--;
        }
        delete s.ownerOf[_tokenId];
        delete s.approved[_tokenId];
        emit Transfer(owner, address(0), _tokenId);
    }
}
