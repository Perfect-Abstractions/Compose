// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-721 Approve Module
 */

/**
 * @notice Error indicating that the queried token does not exist.
 */
error ERC721NonexistentToken(uint256 _tokenId);
/**
 * @notice Error indicating the operator address is invalid.
 */
error ERC721InvalidOperator(address _operator);

/**
 * @notice Emitted when the approved address for an NFT is changed or reaffirmed.
 */
event Approval(address indexed _owner, address indexed _to, uint256 indexed _tokenId);

/**
 * @notice Emitted when an operator is enabled or disabled for an owner.
 */
event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

bytes32 constant STORAGE_POSITION = keccak256("erc721");

/**
 * @custom:storage-location erc8042:erc721
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
function getStorage() pure returns (ERC721Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Approves another address to transfer the given token ID.
 * @param _to The address to be approved.
 * @param _tokenId The token ID to approve.
 */
function approve(address _to, uint256 _tokenId) {
    ERC721Storage storage s = getStorage();
    address owner = s.ownerOf[_tokenId];
    if (owner == address(0)) {
        revert ERC721NonexistentToken(_tokenId);
    }
    s.approved[_tokenId] = _to;
    emit Approval(owner, _to, _tokenId);
}

/**
 * @notice Approves or revokes permission for an operator to manage all users's assets.
 * @param _operator The operator address to set approval for.
 * @param _approved True to approve, false to revoke.
 */
function setApprovalForAll(address user, address _operator, bool _approved) {
    if (_operator == address(0)) {
        revert ERC721InvalidOperator(_operator);
    }
    getStorage().isApprovedForAll[user][_operator] = _approved;
    emit ApprovalForAll(user, _operator, _approved);
}

