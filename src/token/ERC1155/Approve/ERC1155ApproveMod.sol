// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-1155 Approve Module
 * @notice Provides internal approval functionality for ERC-1155 tokens.
 */

/**
 * @notice Error indicating the operator address is invalid.
 * @param _operator Invalid operator address.
 */
error ERC1155InvalidOperator(address _operator);

/**
 * @notice Emitted when `account` grants or revokes permission to `operator` to transfer their tokens.
 * @param _account The token owner granting/revoking approval.
 * @param _operator The address being approved/revoked.
 * @param _approved True if approval is granted, false if revoked.
 */
event ApprovalForAll(address indexed _account, address indexed _operator, bool _approved);

/**
 * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("erc1155");

/**
 * @dev ERC-8042 compliant storage struct for ERC-1155 token data.
 * @custom:storage-location erc8042:erc1155
 */
struct ERC1155Storage {
    mapping(uint256 id => mapping(address account => uint256 balance)) balanceOf;
    mapping(address account => mapping(address operator => bool)) isApprovedForAll;
}

/**
 * @notice Returns the ERC-1155 storage struct from the predefined diamond storage slot.
 * @dev Uses inline assembly to set the storage slot reference.
 * @return s The ERC-1155 storage struct reference.
 */
function getStorage() pure returns (ERC1155Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Grants or revokes permission to `operator` to transfer the user's tokens.
 * @dev Emits an {ApprovalForAll} event.
 * @param _user The address of the token owner.
 * @param _operator The address to grant/revoke approval to.
 * @param _approved True to approve, false to revoke.
 */
function setApprovalForAll(address _user, address _operator, bool _approved) {
    if (_operator == address(0)) {
        revert ERC1155InvalidOperator(address(0));
    }
    getStorage().isApprovedForAll[_user][_operator] = _approved;
    emit ApprovalForAll(_user, _operator, _approved);
}
